//
//  Profiler.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Headless boot benchmark: runs the emulator for a fixed wall-clock budget, samples throughput once a second,
/// checks that the guest made it to userland, and fingerprints CPU state at fixed instruction counts so an
/// optimized build can be checked for bit-exact behaviour against a baseline report.
final class Profiler {
    /// Steps executed between clock reads and PC samples. Divides `checkpointInterval`.
    private static let chunk = 1 << 16

    /// Steps between state fingerprints (~134M).
    static let checkpointInterval = 1 << 27

    /// Chunks without a syscall after which the boot shell counts as idle at its prompt (~4M steps).
    private static let idleChunks = 64

    /// Chunks between keyboard events while typing (~1M steps).
    private static let keystrokeChunks = 16

    /// Guest syscalls between progress milestones. Unlike step counts, syscalls measure userland progress
    /// even when an emulator change alters how many instructions the guest needs (e.g. native LL/SC).
    static let syscallMilestoneInterval = 25000

    private let options: ProfileOptions
    private var cpu = EmulatorState()
    private var uartOutput = [[Byte]](repeating: [], count: 2)
    private var keyboard: KeyboardScript?

    init(options: ProfileOptions) throws {
        self.options = options
        keyboard = try options.typedInput.map { try KeyboardScript(typing: $0) }
    }

    /// Returns the process exit status: 0 when the guest reached userland without panicking or diverging.
    func run() -> Int32 {
        let physical = cpu.bus.physical
        physical.blockDevice.enableSnapshotMode()
        physical.uart0.txReady = { [unowned self] in uartOutput[0].append($0) }
        physical.uart1.txReady = { [unowned self] in uartOutput[1].append($0) }

        let bootStart = Self.now()
        cpu.boot()
        let bootLoad = Self.now() - bootStart

        print("Swips profiler - \(Self.hostDescription)")
        print(String(format: "kernel loaded in %.0f ms; running for %.0f s%@", bootLoad * 1000, options.duration,
                     options.instructionLimit.map { " or \(Self.formatCount($0)) steps" } ?? ""))
        print("   time        steps      MIPS  user%   syscalls  tlb-miss       irq")

        var report = ProfileReport(host: Self.hostDescription, date: ISO8601DateFormatter().string(from: Date()))
        var steps = 0
        var userSamples = 0, totalSamples = 0
        var lastSample = (time: 0.0, steps: 0, user: 0, total: 0)
        var quietChunks = 0, lastSyscalls = 0, chunkIndex = 0, framesSaved = 0
        let start = Self.now()

        while true {
            let batch = min(Self.chunk, (options.instructionLimit ?? .max) - steps)
            cpu.run(steps: batch)
            steps += batch

            totalSamples += 1
            if cpu.pc < 0x8000_0000 { userSamples += 1 }

            let time = Self.now() - start

            chunkIndex += 1

            if report.userland == nil, cpu.stats.userEntries > 0 {
                report.userland = .init(time: time, steps: steps)
                print(String(format: ">> entered userland at %.2f s (%@ steps)", time, Self.formatCount(steps)))
            }

            // Everything here depends only on step counts, never on wall time, so runs stay deterministic.
            let syscalls = cpu.stats.exceptions[Int(ExceptionCode.syscall.rawValue)]
            if report.userland != nil, report.shellReady == nil {
                quietChunks = syscalls == lastSyscalls ? quietChunks + 1 : 0
                if quietChunks == Self.idleChunks {
                    report.shellReady = .init(time: time, steps: steps)
                    print(String(format: ">> shell idle at %.2f s (%@ steps)%@", time, Self.formatCount(steps),
                                 options.typedInput.map { ", typing \($0.debugDescription)" } ?? ""))
                }
            }
            lastSyscalls = syscalls

            if syscalls >= (report.syscallMilestones.count + 1) * Self.syscallMilestoneInterval {
                report.syscallMilestones.append(.init(time: time, steps: steps))
            }

            if report.shellReady != nil, chunkIndex % Self.keystrokeChunks == 0, let event = keyboard?.popFirst() {
                let ps2 = cpu.bus.physical.ps2Keyboard
                if event.pressed { ps2.pressed(event.keyCode) } else { ps2.depressed(event.keyCode) }
            }

            if steps % Self.checkpointInterval == 0 {
                report.checkpoints.append(.init(steps: steps, time: time, fingerprint: fingerprint()))
            }

            let finished = time >= options.duration || steps >= options.instructionLimit ?? .max

            if report.graphicalScreen == nil, chunkIndex % Self.keystrokeChunks == 0,
               FramebufferSnapshot.isMostlyLit(cpu.bus.physical.framebuffer)
            {
                report.graphicalScreen = .init(time: time, steps: steps)
                print(String(format: ">> graphical screen (login greeter) at %.2f s (%@ steps)", time,
                             Self.formatCount(steps)))
            }

            if let directory = options.framesDirectory, time >= Double(framesSaved + 1) * 5 {
                framesSaved += 1
                let path = (directory as NSString).appendingPathComponent(String(format: "%03d.png", framesSaved * 5))
                FramebufferSnapshot.writePNG(cpu.bus.physical.framebuffer, to: path)
            }

            if time - lastSample.time >= 1 || finished {
                let sample = ProfileReport.Sample(
                    time: time,
                    steps: steps,
                    mips: Double(steps - lastSample.steps) / (time - lastSample.time) / 1e6,
                    userPercent: 100 * Double(userSamples - lastSample.user) / Double(max(1, totalSamples - lastSample.total)),
                )
                report.samples.append(sample)
                printSample(sample)
                lastSample = (time, steps, userSamples, totalSamples)
            }

            if finished { break }
        }

        report.duration = Self.now() - start
        report.steps = steps
        report.averageMIPS = Double(steps) / report.duration / 1e6
        report.userPercent = 100 * Double(userSamples) / Double(max(1, totalSamples))
        fillGuestStatistics(into: &report)
        scanGuestMemory(into: &report)

        var failures = [String]()
        if !report.reachedUserland { failures.append("guest never reached userland") }
        if let panic = report.kernelPanic { failures.append("kernel panic: \(panic)") }

        printSummary(report)

        if let baselinePath = options.baselinePath {
            failures += compare(report, againstBaselineAt: baselinePath)
        }

        writeArtifacts(report)

        if failures.isEmpty {
            print("RESULT: PASS - booted to userland")
            return 0
        } else {
            failures.forEach { print("RESULT: FAIL - \($0)") }
            return 1
        }
    }

    // MARK: - Guest state

    /// FNV-1a over architecturally visible CPU state. Stable across processes, unlike `Hasher`.
    private func fingerprint() -> String {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        func mix(_ word: Word) {
            for shift in stride(from: 0, to: 32, by: 8) {
                hash = (hash ^ UInt64((word >> Word(shift)) & 0xFF)) &* 0x100_0000_01B3
            }
        }

        mix(cpu.pc)
        mix(cpu.branchTarget ?? 0xFFFF_FFFF)
        for register in 0 ..< Word(32) {
            mix(cpu.registers[register])
            mix(cpu.fpu[register])
        }
        mix(cpu.registers.hi)
        mix(cpu.registers.lo)
        mix(cpu.fcsr[31])

        let cp0 = cpu.bus.cp0
        for value in [cp0.sr.value, cp0.cause, cp0.epc, cpu.clock.count, cp0.compare, cp0.entryHi, cp0.entryLo,
                      cp0.badVAddr, cp0.index, cpu.clock.random, cp0.context]
        {
            mix(value)
        }

        return String(hash, radix: 16)
    }

    private func fillGuestStatistics(into report: inout ProfileReport) {
        let stats = cpu.stats
        let names: [ExceptionCode: String] = [
            .interrupt: "interrupt", .tlbModification: "tlbModification", .tlbMissOnLoad: "tlbMissOnLoad",
            .tlbMissOnStore: "tlbMissOnStore", .syscall: "syscall", .breakpoint: "breakpoint",
            .reservedInstruction: "reservedInstruction", .coprocessorUnusable: "coprocessorUnusable",
            .arithmeticOverflow: "arithmeticOverflow", .trap: "trap",
        ]
        for (code, name) in names where stats.exceptions[Int(code.rawValue)] > 0 {
            report.exceptions[name] = stats.exceptions[Int(code.rawValue)]
        }
        report.userEntries = stats.userEntries
        report.userExceptions = stats.userExceptions
        report.reachedUserland = stats.userEntries > 0 && stats.exceptions[Int(ExceptionCode.syscall.rawValue)] > 0
    }

    /// Looks for rendered kernel console messages left in RAM (the printk buffer, tty buffers, ...).
    private func scanGuestMemory(into report: inout ProfileReport) {
        let memory = cpu.bus.physical.ram.contents

        report.kernelPanic = GuestMemory.lines(in: memory, containing: "Kernel panic - not syncing: ", limit: 1).first

        for needle in ["as init process", "Welcome to", "Reached target", "Started ", "login:"] {
            report.consoleMarkers += GuestMemory.lines(in: memory, containing: needle, limit: 3)
        }

        for (index, output) in uartOutput.enumerated() where !output.isEmpty {
            let text = String(decoding: output.suffix(2048), as: UTF8.self)
            report.uartTail["uart\(index)"] = text
        }
    }

    // MARK: - Output

    private func printSample(_ sample: ProfileReport.Sample) {
        let stats = cpu.stats
        let tlbMisses = stats.exceptions[1] + stats.exceptions[2] + stats.exceptions[3]
        print(String(format: "%6.1fs %12@ %9.1f %6.1f %10d %9d %9d",
                     sample.time, Self.formatCount(sample.steps), sample.mips, sample.userPercent,
                     stats.exceptions[8], tlbMisses, stats.exceptions[0]))
        fflush(stdout)
    }

    private func printSummary(_ report: ProfileReport) {
        print("")
        print(String(format: "steps executed:    %@ in %.2f s", Self.formatCount(report.steps), report.duration))
        print(String(format: "average speed:     %.1f MIPS (peak %.1f)", report.averageMIPS,
                     report.samples.map(\.mips).max() ?? 0))
        if let userland = report.userland {
            print(String(format: "userland reached:  %.2f s (%@ steps), %d returns to user mode",
                         userland.time, Self.formatCount(userland.steps), report.userEntries))
        } else {
            print("userland reached:  no")
        }
        if let shell = report.shellReady {
            print(String(format: "shell prompt idle: %.2f s (%@ steps)", shell.time, Self.formatCount(shell.steps)))
        }
        if let screen = report.graphicalScreen {
            print(String(format: "login greeter:     %.2f s (%@ steps)", screen.time, Self.formatCount(screen.steps)))
        }
        print(String(format: "time in userland:  %.1f%% of PC samples", report.userPercent))
        print("exceptions:        " + report.exceptions.sorted { $0.value > $1.value }
            .map { "\($0.key)=\($0.value)" }.joined(separator: " "))
        if !report.consoleMarkers.isEmpty {
            print("console markers found in guest RAM:")
            report.consoleMarkers.forEach { print("  | \($0)") }
        }
        for (uart, text) in report.uartTail.sorted(by: { $0.key < $1.key }) {
            print("\(uart) output (tail):")
            text.split(separator: "\n").suffix(8).forEach { print("  | \($0)") }
        }
    }

    private func compare(_ report: ProfileReport, againstBaselineAt path: String) -> [String] {
        guard let data = FileManager.default.contents(atPath: path),
              let baseline = try? JSONDecoder().decode(ProfileReport.self, from: data)
        else {
            return ["could not read baseline report at \(path)"]
        }

        print("")
        print("vs baseline (\(baseline.date)):")

        let common = min(report.checkpoints.count, baseline.checkpoints.count)
        let mismatch = (0 ..< common).first { report.checkpoints[$0].fingerprint != baseline.checkpoints[$0].fingerprint }

        if common > 0 {
            let ours = report.checkpoints[common - 1], theirs = baseline.checkpoints[common - 1]
            print(String(format: "  time to %@ steps:  %.2f s vs %.2f s  (%.2fx)", Self.formatCount(ours.steps),
                         ours.time, theirs.time, theirs.time / ours.time))
        }
        print(String(format: "  average speed:     %.1f vs %.1f MIPS  (%.2fx)",
                     report.averageMIPS, baseline.averageMIPS, report.averageMIPS / baseline.averageMIPS))
        if let ours = report.userland, let theirs = baseline.userland {
            print(String(format: "  time to userland:  %.2f s vs %.2f s  (%.2fx)", ours.time, theirs.time,
                         theirs.time / ours.time))
        }
        if let ours = report.shellReady, let theirs = baseline.shellReady {
            print(String(format: "  time to shell:     %.2f s vs %.2f s  (%.2fx)", ours.time, theirs.time,
                         theirs.time / ours.time))
        }
        if let ours = report.graphicalScreen, let theirs = baseline.graphicalScreen {
            print(String(format: "  time to greeter:   %.2f s vs %.2f s  (%.2fx)", ours.time, theirs.time,
                         theirs.time / ours.time))
        }
        let commonMilestones = min(report.syscallMilestones.count, baseline.syscallMilestones.count)
        if commonMilestones > 0 {
            let ours = report.syscallMilestones[commonMilestones - 1]
            let theirs = baseline.syscallMilestones[commonMilestones - 1]
            print(String(format: "  time to %dK syscalls: %.2f s vs %.2f s  (%.2fx)",
                         commonMilestones * Self.syscallMilestoneInterval / 1000, ours.time, theirs.time,
                         theirs.time / ours.time))
        }

        if let mismatch {
            let steps = report.checkpoints[mismatch].steps
            print("  state fingerprints: DIVERGED at checkpoint \(mismatch + 1) (\(Self.formatCount(steps)) steps)")
            return ["CPU state diverged from baseline after \(Self.formatCount(steps)) steps"]
        }
        print("  state fingerprints: \(common)/\(common) identical")
        return []
    }

    private func writeArtifacts(_ report: ProfileReport) {
        if let path = options.jsonPath {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try! encoder.encode(report).write(to: URL(fileURLWithPath: path))
            print("report written to \(path)")
        }
        if let path = options.screenshotPath {
            FramebufferSnapshot.writePNG(cpu.bus.physical.framebuffer, to: path)
            print("framebuffer saved to \(path)")
        }
        if let path = options.ramDumpPath {
            try! Data(cpu.bus.physical.ram.contents).write(to: URL(fileURLWithPath: path))
            print("RAM dumped to \(path)")
        }
    }

    // MARK: - Helpers

    private static func now() -> Double {
        Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1e9
    }

    static func formatCount(_ count: Int) -> String {
        switch count {
        case 1_000_000_000...: String(format: "%.2fG", Double(count) / 1e9)
        case 1_000_000...: String(format: "%.1fM", Double(count) / 1e6)
        default: "\(count)"
        }
    }

    private static let hostDescription: String = {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }()
}

// MARK: - Report

struct ProfileReport: Codable {
    struct Sample: Codable {
        var time: Double
        var steps: Int
        var mips: Double
        var userPercent: Double
    }

    struct Checkpoint: Codable {
        var steps: Int
        var time: Double
        var fingerprint: String
    }

    struct Milestone: Codable {
        var time: Double
        var steps: Int
    }

    var host: String
    var date: String
    var duration = 0.0
    var steps = 0
    var averageMIPS = 0.0
    var userPercent = 0.0
    var reachedUserland = false
    var userland: Milestone?
    var shellReady: Milestone?
    /// First time most of the framebuffer is lit - consoles and X startup are mostly black, the greeter isn't.
    var graphicalScreen: Milestone?
    /// Entry n is when the guest completed (n + 1) * `syscallMilestoneInterval` syscalls.
    var syscallMilestones = [Milestone]()
    var userEntries = 0
    var userExceptions = 0
    var exceptions = [String: Int]()
    var kernelPanic: String?
    var consoleMarkers = [String]()
    var uartTail = [String: String]()
    var samples = [Sample]()
    var checkpoints = [Checkpoint]()
}

// MARK: - Guest memory search

enum GuestMemory {
    /// Returns the printable text surrounding each occurrence of `needle`, deduplicated, in address order.
    /// Text containing `%` is skipped: that's a printk format string in the kernel image, not a rendered message.
    static func lines(in memory: UnsafeRawBufferPointer, containing needle: String, limit: Int) -> [String] {
        let pattern = Array(needle.utf8)
        guard let base = memory.baseAddress else { return [] }
        let end = base + memory.count
        var cursor = base
        var results = [String]()

        func isText(_ byte: Byte) -> Bool {
            (0x20 ..< 0x7F).contains(byte) || byte == 0x09
        }

        while results.count < limit, cursor < end {
            guard let match = pattern.withUnsafeBytes({
                memmem(cursor, end - cursor, $0.baseAddress, pattern.count)
            }) else { break }
            let hit = UnsafeRawPointer(match)

            var lower = hit, upper = hit + pattern.count
            while lower > base, hit - lower < 160, isText((lower - 1).load(as: Byte.self)) { lower -= 1 }
            while upper < end, upper - hit < 160, isText(upper.load(as: Byte.self)) { upper += 1 }

            let line = String(decoding: UnsafeRawBufferPointer(start: lower, count: upper - lower), as: UTF8.self)
            if !line.contains("%"), !results.contains(line) { results.append(line) }
            cursor = hit + pattern.count
        }
        return results
    }
}
