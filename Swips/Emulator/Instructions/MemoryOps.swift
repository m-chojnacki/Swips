//
//  MemoryOps.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    @inline(__always)
    mutating func op_lb(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        registers[i.rt] = try Word(bus.readByte(from: addr)).signExtendedByte
    }

    @inline(__always)
    mutating func op_lbu(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        registers[i.rt] = try Word(bus.readByte(from: addr))
    }

    @inline(__always)
    mutating func op_lh(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        registers[i.rt] = try Word(bus.readHalfword(from: addr)).signExtendedHalfword
    }

    @inline(__always)
    mutating func op_lhu(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        registers[i.rt] = try Word(bus.readHalfword(from: addr))
    }

    @inline(__always)
    mutating func op_lw(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        registers[i.rt] = try bus.readWord(from: addr)
    }

    /// Load Linked - MIPS II. Without it the kernel traps and emulates every userland atomic operation.
    @inline(__always)
    mutating func op_ll(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        registers[i.rt] = try bus.readWord(from: addr)
        llBit = true
    }

    /// Store Conditional - stores only if nothing could have intervened since LL. On a single CPU only an
    /// exception can (context switch, signal), and taking one clears `llBit`.
    @inline(__always)
    mutating func op_sc(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        if llBit {
            try bus.writeWord(to: addr, registers[i.rt])
            registers[i.rt] = 1
        } else {
            registers[i.rt] = 0
        }
        llBit = false
    }

    /// Load Word Left - loads the most-significant bytes of an unaligned word.
    mutating func op_lwl(_ i: Word) throws(MIPSException) {
        let addr = registers[i.rs] &+ i.immediate.signExtendedHalfword
        var value = registers[i.rt]
        for offset in 0 ... (addr % 4) {
            value = try value.withByte(3 &- offset, bus.readByte(from: addr &- offset))
        }
        registers[i.rt] = value
    }

    /// Load Word Right - loads the least-significant bytes of an unaligned word.
    mutating func op_lwr(_ i: Word) throws(MIPSException) {
        let addr = registers[i.rs] &+ i.immediate.signExtendedHalfword
        var value = registers[i.rt]
        for offset in 0 ... (3 &- addr % 4) {
            value = try value.withByte(offset, bus.readByte(from: addr &+ offset))
        }
        registers[i.rt] = value
    }

    @inline(__always)
    mutating func op_sb(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        try bus.writeByte(to: addr, Byte(truncatingIfNeeded: registers[i.rt]))
    }

    @inline(__always)
    mutating func op_sh(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        try bus.writeHalfword(to: addr, Halfword(truncatingIfNeeded: registers[i.rt]))
    }

    @inline(__always)
    mutating func op_sw(_ i: Word) throws(MIPSException) {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        try bus.writeWord(to: addr, registers[i.rt])
    }

    /// Store Word Left - stores the most-significant bytes of an unaligned word.
    mutating func op_swl(_ i: Word) throws(MIPSException) {
        let addr = registers[i.rs] &+ i.immediate.signExtendedHalfword
        let src = registers[i.rt]
        for offset in 0 ... (addr % 4) {
            try bus.writeByte(to: addr &- offset, src.getByte(3 &- offset))
        }
    }

    /// Store Word Right - stores the least-significant bytes of an unaligned word.
    mutating func op_swr(_ i: Word) throws(MIPSException) {
        let addr = registers[i.rs] &+ i.immediate.signExtendedHalfword
        let src = registers[i.rt]
        for offset in 0 ... (3 &- addr % 4) {
            try bus.writeByte(to: addr &+ offset, src.getByte(offset))
        }
    }
}
