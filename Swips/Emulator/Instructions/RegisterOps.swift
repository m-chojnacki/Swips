//
//  RegisterOps.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    @inline(__always)
    mutating func op_lui(_ i: Word) throws(MIPSException) {
        registers[i.rt] = i.immediate << 16
    }

    @inline(__always)
    mutating func op_mfhi(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers.hi
    }

    @inline(__always)
    mutating func op_mflo(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers.lo
    }

    @inline(__always)
    mutating func op_mthi(_ i: Word) throws(MIPSException) {
        registers.hi = registers[i.rs]
    }

    @inline(__always)
    mutating func op_mtlo(_ i: Word) throws(MIPSException) {
        registers.lo = registers[i.rs]
    }
}
