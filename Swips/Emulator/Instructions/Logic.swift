//
//  Logic.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    @inline(__always)
    mutating func op_and(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs] & registers[i.rt]
    }

    @inline(__always)
    mutating func op_andi(_ i: Word) throws(MIPSException) {
        registers[i.rt] = registers[i.rs] & i.immediate // zero-extended (no sign extend)
    }

    @inline(__always)
    mutating func op_nor(_ i: Word) throws(MIPSException) {
        registers[i.rd] = ~(registers[i.rs] | registers[i.rt])
    }

    @inline(__always)
    mutating func op_or(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs] | registers[i.rt]
    }

    @inline(__always)
    mutating func op_ori(_ i: Word) throws(MIPSException) {
        registers[i.rt] = registers[i.rs] | i.immediate // zero-extended
    }

    @inline(__always)
    mutating func op_xor(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rs] ^ registers[i.rt]
    }

    @inline(__always)
    mutating func op_xori(_ i: Word) throws(MIPSException) {
        registers[i.rt] = registers[i.rs] ^ i.immediate // zero-extended
    }

    @inline(__always)
    mutating func op_sll(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rt] << i.shamt
    }

    @inline(__always)
    mutating func op_sllv(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rt] << (registers[i.rs] & 0x1F)
    }

    @inline(__always)
    mutating func op_srl(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rt] >> i.shamt
    }

    @inline(__always)
    mutating func op_srlv(_ i: Word) throws(MIPSException) {
        registers[i.rd] = registers[i.rt] >> (registers[i.rs] & 0x1F)
    }

    @inline(__always)
    mutating func op_sra(_ i: Word) throws(MIPSException) {
        registers[i.rd] = Word(bitPattern: registers[i.rt].signed >> i.shamt)
    }

    @inline(__always)
    mutating func op_srav(_ i: Word) throws(MIPSException) {
        registers[i.rd] = Word(bitPattern: registers[i.rt].signed >> (registers[i.rs] & 0x1F))
    }
}
