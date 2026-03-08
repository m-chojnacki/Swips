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

    // MARK: - Memory system

    /// Virtual address bus - translates virtual → physical addresses and dispatches to devices.
    let bus = VirtualBus()

    // MARK: - FPU state

    var fpu = FPURegisters()
    var fcsr = FPUControlRegisters()
}
