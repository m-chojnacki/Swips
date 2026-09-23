//
//  EmulatorLoop.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Boot sequence

extension EmulatorState {
    mutating func boot() {
        // Load kernel image into RAM at 0x81000000.
        bus.load(Bundle.main.runtimePath(of: "vmlinuz.systemd.bin"), at: 0x8100_0000)

        // Build Linux kernel command line.
        let cmdline: String
        #if os(macOS)
            // console=tty0 - use framebuffer console (use fbcon=map:1 to disable it)
            // init=/init - hand off to systemd after boot
            // root=/dev/kda1 rw - mount the disk image as root
            cmdline = "console=tty0 init=/debian root=/dev/kda1 rw"
        #else
            let initrdSize = bus.load(Bundle.main.runtimePath(of: "initrd"), at: 0x8300_0000)
            let initrdExtras = "rd_start=0x83000000 rd_size=\(initrdSize.hex)"
            cmdline = "fbcon=map:1 rw init=/init \(initrdExtras)"
        #endif

        // Jump to kernel entry point.
        pc = 0x8100_0000

        // MIPS firmware arguments passed in $a0–$a3.
        registers[4] = 2 // fw_arg0 - argc
        registers[5] = 0x8200_0000 // fw_arg1 - pointer to argv array
        registers[6] = 0 // fw_arg2
        registers[7] = 0 // fw_arg3

        // Set FPU implementation/revision in FIR register (control reg 0).
        fcsr[0] = 0b0000_0000_0000_0000_0000_0001_0000_0001

        // Set up the kernel argument block at 0x82000000:
        //   argv[0] → 0x82001000  (unused)
        //   argv[1] → 0x82002000  (kernel command line string)
        //   argv[2] → 0           (terminator)
        try! bus.writeWord(to: 0x8200_0000, 0x8200_1000)
        try! bus.writeWord(to: 0x8200_0004, 0x8200_2000)
        try! bus.writeWord(to: 0x8200_0008, 0)
        bus.writeString(to: 0x8200_2000, cmdline)
    }
}

// MARK: - Run loop

extension EmulatorState {
    /// Executes exactly `steps` CPU steps (an exception counts as a step).
    mutating func run(steps: Int) {
        for _ in 0 ..< steps {
            step()
        }
    }

    @inline(__always)
    private mutating func step() {
        do throws(MIPSException) {
            try tickCP0()

            // Kernel code is unmapped; the cached page is then usually the user page we'll return to.
            let instruction = if pc & ~0xFFF == fetchPage {
                fetchHost.load(fromByteOffset: Int(pc & 0xFFC), as: Word.self)
            } else if let host = bus.unmappedHostPage(at: pc) {
                host.load(fromByteOffset: Int(pc & 0xFFC), as: Word.self)
            } else {
                try fetchFromNewPage()
            }

            // A pending branch means this is its delay slot; jump once the slot completes.
            // One call site keeps a single inlined copy of the (large) dispatcher.
            let delayedBranch = branchTarget
            try executeInstruction(instruction)
            if let target = delayedBranch {
                branchTarget = nil
                pc = target &+ 4
            } else {
                pc &+= 4
            }
        } catch {
            handleException(error)
        }
    }

    @inline(never)
    private mutating func fetchFromNewPage() throws(MIPSException) -> Word {
        guard let host = try bus.hostPage(forFetchAt: pc) else {
            return try bus.readWord(from: pc)
        }
        fetchPage = pc & ~0xFFF
        fetchHost = host
        return host.load(fromByteOffset: Int(pc & 0xFFC), as: Word.self)
    }

    @inline(__always)
    private mutating func tickCP0() throws(MIPSException) {
        clock.ticks &+= 1
        if clock.ticks == clock.nextTimerTick || bus.cp0.checkInterrupts {
            try serviceTimerAndInterrupts()
        }
    }

    @inline(never)
    private mutating func serviceTimerAndInterrupts() throws(MIPSException) {
        if clock.ticks == clock.nextTimerTick {
            clock.timerFired()
            bus.cp0.setInterrupt(bit: 7, pending: true)
        }

        // Anything that changes SR or Cause sets the flag again, including taking this interrupt.
        bus.cp0.checkInterrupts = false
        if bus.cp0.sr.iec, (bus.cp0.sr.value & 0xFF00) & (bus.cp0.cause & 0xFF00) != 0 {
            throw MIPSException(code: .interrupt)
        }
    }

    private mutating func handleException(_ exception: MIPSException) {
        stats.exceptions[Int(exception.code.rawValue)] += 1
        llBit = false

        // If we're in a branch delay slot, EPC points to the branch instruction.
        if branchTarget != nil {
            bus.cp0.epc = pc &- 4
            bus.cp0.cause |= 0x8000_0000 // set BD bit
            branchTarget = nil
        } else {
            bus.cp0.epc = pc
            bus.cp0.cause &= ~0x8000_0000
        }

        if bus.cp0.epc < 0x8000_0000 {
            stats.userExceptions += 1
        }

        // Write ExcCode into Cause[6:2].
        bus.cp0.cause &= ~0b1111100
        bus.cp0.cause |= exception.code.rawValue << 2

        // Push the KU/IE mode stack: o ← p, p ← c, c ← kernel/disabled.
        bus.cp0.sr.kuo = bus.cp0.sr.kup; bus.cp0.sr.ieo = bus.cp0.sr.iep
        bus.cp0.sr.kup = bus.cp0.sr.kuc; bus.cp0.sr.iep = bus.cp0.sr.iec
        bus.cp0.sr.kuc = true
        bus.cp0.sr.iec = false

        if let badVAddr = exception.badVAddr {
            bus.cp0.badVAddr = badVAddr
            if let entryHi = exception.entryHi {
                bus.cp0.entryHi = entryHi
                fetchPage = Self.invalidFetchPage // ASID may have changed
            }
        }

        pc = exception.vector.rawValue
    }
}
