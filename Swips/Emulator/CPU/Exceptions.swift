//
//  Exceptions.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// MARK: - Exception codes (ExcCode field in Cause register)

enum ExceptionCode: Word {
    case interrupt = 0
    case tlbModification = 1
    case tlbMissOnLoad = 2
    case tlbMissOnStore = 3
    case syscall = 8
    case breakpoint = 9
    case reservedInstruction = 10
    case coprocessorUnusable = 11
    case arithmeticOverflow = 12
    case trap = 13
}

// MARK: - Exception vectors

enum ExceptionVector: Word {
    /// TLB refill handler in KUSEG.
    case kuSegTLB = 0x8000_0000
    /// General exception handler.
    case generic = 0x8000_0080
}

// MARK: - Exception type

struct MIPSException: Error {
    let code: ExceptionCode
    let vector: ExceptionVector
    let badVAddr: Word?
    let entryHi: Word?

    init(
        code: ExceptionCode,
        vector: ExceptionVector = .generic,
        badVAddr: Word? = nil,
        entryHi: Word? = nil,
    ) {
        self.code = code
        self.vector = vector
        self.badVAddr = badVAddr
        self.entryHi = entryHi
    }
}
