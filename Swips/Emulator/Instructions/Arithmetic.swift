//
//  Arithmetic.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    @inline(__always)
    mutating func op_add(_ i: Word) throws(MIPSException) {
        let a = registers[i.rs], b = registers[i.rt]
        let result = a &+ b
        if a.isNegative == b.isNegative, result.isNegative != a.isNegative {
            throw MIPSException(code: .arithmeticOverflow)
        }
        registers[i.rd] = result
    }

    @inline(__always)
    mutating func op_addi(_ i: Word) throws(MIPSException) {
        let a = registers[i.rs], b = i.immediate.signExtendedHalfword
        let result = a &+ b
        if a.isNegative == b.isNegative, result.isNegative != a.isNegative {
            throw MIPSException(code: .arithmeticOverflow)
        }
        registers[i.rt] = result
    }

    @inline(__always)
    mutating func op_addiu(_ i: Word) throws(MIPSException) {
        registers[i.rt] = registers[i.rs] &+ i.immediate.signExtendedHalfword
    }

    @inline(__always)
    mutating func op_addu(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs] &+ registers[i.rt]
    }

    @inline(__always)
    mutating func op_sub(_ i: Word) throws(MIPSException) {
        let a = registers[i.rs], b = registers[i.rt]
        let result = a &- b
        if a.isNegative != b.isNegative, result.isNegative == b.isNegative {
            throw MIPSException(code: .arithmeticOverflow)
        }
        registers[i.rd] = result
    }

    @inline(__always)
    mutating func op_subu(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs] &- registers[i.rt]
    }

    @inline(__always)
    mutating func op_mult(_ i: Word) throws(MIPSException) {
        let result = SignedLongword(registers[i.rs].signed) &* SignedLongword(registers[i.rt].signed)
        registers.hi = Word(truncatingIfNeeded: result >> 32)
        registers.lo = Word(truncatingIfNeeded: result)
    }

    @inline(__always)
    mutating func op_multu(_ i: Word) throws(MIPSException) {
        let result = Longword(registers[i.rs]) &* Longword(registers[i.rt])
        registers.hi = Word(truncatingIfNeeded: result >> 32)
        registers.lo = Word(truncatingIfNeeded: result)
    }

    mutating func op_div(_ i: Word) throws(MIPSException) {
        let dividend = registers[i.rs].signed
        let divisor = registers[i.rt].signed
        guard divisor != 0 else { return } // division by zero: result undefined by MIPS spec
        registers.hi = Word(bitPattern: dividend % divisor)
        registers.lo = Word(bitPattern: dividend / divisor)
    }

    mutating func op_divu(_ i: Word) throws(MIPSException) {
        let dividend = registers[i.rs]
        let divisor = registers[i.rt]
        guard divisor != 0 else { return }
        registers.hi = dividend % divisor
        registers.lo = dividend / divisor
    }

    @inline(__always)
    mutating func op_slt(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs].signed < registers[i.rt].signed ? 1 : 0
    }

    @inline(__always)
    mutating func op_sltu(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs] < registers[i.rt] ? 1 : 0
    }

    @inline(__always)
    mutating func op_slti(_ i: Word) throws(MIPSException) {
        registers[i.rt] = registers[i.rs].signed < i.immediate.signExtendedHalfword.signed ? 1 : 0
    }

    @inline(__always)
    mutating func op_sltiu(_ i: Word) throws(MIPSException) {
        registers[i.rt] = registers[i.rs] < i.immediate.signExtendedHalfword ? 1 : 0
    }
}
