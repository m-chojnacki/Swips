//
//  Special.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    mutating func op_syscall(_: Word) throws(MIPSException) {
        throw MIPSException(code: .syscall)
    }

    mutating func op_break(_ i: Word) throws(MIPSException) {
        // The break code is encoded in bits [25:6] of the instruction word.
        assertionFailure("BREAK \(i.code)")
    }

    mutating func op_sync(_: Word) throws(MIPSException) {
        // SYNC is a memory-ordering barrier; in a single-threaded emulator it's a no-op.
    }
}
