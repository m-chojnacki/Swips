//
//  EmulatorState.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - CPU state

struct EmulatorState {
    var registers = RegisterFile()

    /// Current program counter.
    var pc: Word = 0xBFC0_0000 // reset vector → physical 0x1FC00000 (ROM)

    /// When non-nil the CPU is in a branch delay slot;
    /// this holds the branch target (adjusted by -4 for the post-step increment).
    var branchTarget: Word?

    var clock = CP0Clock(compare: CP0Registers.resetCompare)

    /// LL/SC link bit - set by LL, cleared by SC and by taking any exception.
    var llBit = false

    /// Virtual page of the last instruction fetch from RAM and its host address, so fetches within the page skip
    /// address translation. Must be invalidated whenever translation can change: TLB writes and ASID changes.
    var fetchPage: Word = EmulatorState.invalidFetchPage
    var fetchHost = UnsafeRawPointer(bitPattern: 1)!

    /// Page addresses have their low 12 bits clear, so this never matches.
    static let invalidFetchPage: Word = 1

    var stats = EmulatorStats()

    // MARK: - Memory system

    /// Virtual address bus - translates virtual → physical addresses and dispatches to devices.
    let bus = VirtualBus()

    // MARK: - FPU state

    var fpu = FPURegisters()
    var fcsr = FPUControlRegisters()
}

// MARK: - Statistics

/// Counters updated only on slow paths (exceptions, mode switches), so they cost nothing in the hot loop.
struct EmulatorStats {
    /// Exceptions taken, indexed by ExcCode.
    var exceptions = [Int](repeating: 0, count: 32)

    /// Exceptions taken while executing user (kuseg) code.
    var userExceptions = 0

    /// Number of `rfe` returns into user (kuseg) code.
    var userEntries = 0
}
