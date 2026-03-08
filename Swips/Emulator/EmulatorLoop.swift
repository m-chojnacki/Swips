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
import QuartzCore

// MARK: - Boot sequence + run loop

func runEmulatorLoop(_ cpu: inout EmulatorState, onSpeedUpdate: ((Double) -> Void)?) {
    // Load kernel image into RAM at 0x81000000.
    cpu.bus.load(Bundle.main.runtimePath(of: "vmlinuz.systemd.bin"), at: 0x8100_0000)

    // Build Linux kernel command line.
    let cmdline: String
    #if os(macOS)
        // console=tty0 - use framebuffer console (use fbcon=map:1 to disable it)
        // init=/init - hand off to systemd after boot
        // root=/dev/kda1 rw - mount the disk image as root
        cmdline = "console=tty0 init=/debian root=/dev/kda1 rw"
    #else
        let initrdSize = cpu.bus.load(Bundle.main.runtimePath(of: "initrd"), at: 0x8300_0000)
        let initrdExtras = "rd_start=0x83000000 rd_size=\(initrdSize.hex)"
        cmdline = "fbcon=map:1 rw init=/init \(initrdExtras)"
    #endif

    // Jump to kernel entry point.
    cpu.pc = 0x8100_0000

    // MIPS firmware arguments passed in $a0–$a3.
    cpu.registers[4] = 2 // fw_arg0 - argc
    cpu.registers[5] = 0x8200_0000 // fw_arg1 - pointer to argv array
    cpu.registers[6] = 0 // fw_arg2
    cpu.registers[7] = 0 // fw_arg3

    // Set FPU implementation/revision in FIR register (control reg 0).
    cpu.fcsr[0] = 0b0000_0000_0000_0000_0000_0001_0000_0001

    // Set up the kernel argument block at 0x82000000:
    //   argv[0] → 0x82001000  (unused)
    //   argv[1] → 0x82002000  (kernel command line string)
    //   argv[2] → 0           (terminator)
    try! cpu.bus.writeWord(to: 0x8200_0000, 0x8200_1000)
    try! cpu.bus.writeWord(to: 0x8200_0004, 0x8200_2000)
    try! cpu.bus.writeWord(to: 0x8200_0008, 0)
    cpu.bus.writeString(to: 0x8200_2000, cmdline)

    // Run the CPU.
    var tickCounter = 0

    func tickCP0(_ cpu: inout EmulatorState) throws {
        // Decrement the TLB Random register (wraps at 8 to keep entries 0–7 wired).
        cpu.bus.cp0.random &-= 1
        if cpu.bus.cp0.random == 7 {
            cpu.bus.cp0.random = 63
        }

        // Increment the Count register every 10 ticks; fire timer interrupt when it matches Compare.
        if tickCounter == 10 {
            cpu.bus.cp0.count &+= 1
            if cpu.bus.cp0.count == cpu.bus.cp0.compare {
                cpu.bus.cp0.setInterrupt(bit: 7, pending: true)
            }
            tickCounter = 0
        } else {
            tickCounter += 1
        }

        // Check for pending, enabled interrupts.
        if cpu.bus.cp0.sr.iec, (cpu.bus.cp0.sr.value & 0xFF00) & (cpu.bus.cp0.cause & 0xFF00) != 0 {
            throw MIPSException(code: .interrupt)
        }
    }

    func handleException(_ exception: MIPSException, _ cpu: inout EmulatorState) {
        // If we're in a branch delay slot, EPC points to the branch instruction.
        if cpu.branchTarget != nil {
            cpu.bus.cp0.epc = cpu.pc &- 4
            cpu.bus.cp0.cause |= 0x8000_0000 // set BD bit
            cpu.branchTarget = nil
        } else {
            cpu.bus.cp0.epc = cpu.pc
            cpu.bus.cp0.cause &= ~0x8000_0000
        }

        // Write ExcCode into Cause[6:2].
        cpu.bus.cp0.cause &= ~0b1111100
        cpu.bus.cp0.cause |= exception.code.rawValue << 2

        // Push the KU/IE mode stack: o ← p, p ← c, c ← kernel/disabled.
        cpu.bus.cp0.sr.kuo = cpu.bus.cp0.sr.kup; cpu.bus.cp0.sr.ieo = cpu.bus.cp0.sr.iep
        cpu.bus.cp0.sr.kup = cpu.bus.cp0.sr.kuc; cpu.bus.cp0.sr.iep = cpu.bus.cp0.sr.iec
        cpu.bus.cp0.sr.kuc = true
        cpu.bus.cp0.sr.iec = false

        if let badVAddr = exception.badVAddr {
            cpu.bus.cp0.badVAddr = badVAddr
            if let entryHi = exception.entryHi {
                cpu.bus.cp0.entryHi = entryHi
            }
        }

        cpu.pc = exception.vector.rawValue
    }

    func step(_ cpu: inout EmulatorState) {
        do {
            try tickCP0(&cpu)

            let instruction = try cpu.bus.readWord(from: cpu.pc)

            if let target = cpu.branchTarget {
                // Executing the delay-slot instruction; jump after it completes.
                try cpu.executeInstruction(instruction)
                cpu.branchTarget = nil
                cpu.pc = target &+ 4
            } else {
                try cpu.executeInstruction(instruction)
                cpu.pc &+= 4
            }
        } catch let e as MIPSException {
            handleException(e, &cpu)
        } catch {}
    }

    // Main run loop - batch 50 million instructions at a time and report the throughput.
    while true {
        let t0 = CACurrentMediaTime()

        for _ in 0 ..< 50_000_000 {
            step(&cpu)
        }

        let elapsed = CACurrentMediaTime() - t0
        onSpeedUpdate?(50.0 / elapsed)
    }
}
