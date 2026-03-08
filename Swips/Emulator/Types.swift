//
//  Types.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// MARK: - Core type aliases matching MIPS data widths

typealias Longword = UInt64
typealias SignedLongword = Int64

typealias Word = UInt32
typealias SignedWord = Int32

typealias Halfword = UInt16
typealias SignedHalfword = Int16

typealias Byte = UInt8
typealias SignedByte = Int8

// MARK: - Word bit-field accessors (MIPS instruction encoding)

extension Word {
    /// Bits [31:26] - primary opcode.
    var op: Word {
        self >> 26
    }

    /// Bits [25:21] - RS register.
    var rs: Word {
        (self & 0b0000_0011_1110_0000_0000_0000_0000_0000) >> 21
    }

    /// Bits [20:16] - RT register.
    var rt: Word {
        (self & 0b0000_0000_0001_1111_0000_0000_0000_0000) >> 16
    }

    /// Bits [15:0] - 16-bit immediate.
    var immediate: Word {
        self & 0b0000_0000_0000_0000_1111_1111_1111_1111
    }

    /// Bits [25:0] - 26-bit jump target.
    var target: Word {
        self & 0b0000_0011_1111_1111_1111_1111_1111_1111
    }

    /// Bits [15:11] - RD register.
    var rd: Word {
        (self & 0b0000_0000_0000_0000_1111_1000_0000_0000) >> 11
    }

    /// Bits [10:6] - shift amount.
    var shamt: Word {
        (self & 0b0000_0000_0000_0000_0000_0111_1100_0000) >> 6
    }

    /// Bits [5:0] - function code.
    var funct: Word {
        self & 0b0000_0000_0000_0000_0000_0000_0011_1111
    }

    /// Bits [25:6] - syscall/break code field.
    var code: Word {
        (self & 0b0000_0011_1111_1111_1111_1111_1100_0000) >> 6
    }

    /// True when the sign bit (bit 31) is set.
    var isNegative: Bool {
        (self >> 31) != 0
    }

    /// Sign-extends the low 16 bits to 32 bits.
    var signExtendedHalfword: Word {
        self >> 15 != 0 ? self | 0xFFFF_0000 : self
    }

    /// Sign-extends the low 8 bits to 32 bits.
    var signExtendedByte: Word {
        self >> 7 != 0 ? self | 0xFFFF_FF00 : self
    }

    /// Reinterprets the bit pattern as a signed 32-bit integer.
    var signed: SignedWord {
        SignedWord(bitPattern: self)
    }

    var bin: String {
        "0b\(String(self, radix: 2, uppercase: true))"
    }

    var hex: String {
        let s = String(self, radix: 16, uppercase: true)
        let pad = String(repeating: "0", count: s.count >= 8 ? 0 : 8 &- s.count)
        return "0x\(pad)\(s)"
    }

    func getBit(_ bit: Word) -> Bool {
        self >> bit & 1 != 0
    }

    func withBit(_ bit: Word, set value: Bool) -> Word {
        let mask: Word = 1 << bit
        let val: Word = (value ? 1 : 0) << bit
        return self & ~mask | val
    }

    /// Reads byte `byte` from the word (big-endian byte numbering: 3 = MSB).
    func getByte(_ byte: Word) -> Byte {
        Byte(truncatingIfNeeded: (self << ((3 &- byte) << 3)) >> 24)
    }

    /// Returns a copy of this word with byte `byte` replaced by `replace`.
    func withByte(_ byte: Word, _ replace: Byte) -> Word {
        self & ~(0xFF << (byte << 3)) | (Word(replace) << (byte << 3))
    }

    /// Extracts bits [from:to] (inclusive, from ≥ to).
    func bits(from: Word, to: Word) -> Word {
        let waste = 31 &- from
        return (self << waste) >> (waste &+ to)
    }

    /// Hash used to index into the 256-bucket TLB cache.
    var tlbCacheHash: Int {
        Int((self ^ (self >> 9) ^ (self >> 18)) % 256)
    }
}

// MARK: - FPU instruction field accessors

extension Word {
    /// FT - bits [20:16] (second FPU source register, same bits as `rt`).
    var ft: Word {
        bits(from: 20, to: 16)
    }

    /// FS - bits [15:11] (first FPU source register, same bits as `rd`).
    var fs: Word {
        bits(from: 15, to: 11)
    }

    /// FD - bits [10:6] (FPU destination register, same bits as `shamt`).
    var fd: Word {
        bits(from: 10, to: 6)
    }
}

// MARK: - Hex formatting helpers

extension Byte {
    var hex: String {
        let s = String(self, radix: 16, uppercase: true)
        let pad = String(repeating: "0", count: s.count >= 2 ? 0 : 2 &- s.count)
        return "0x\(pad)\(s)"
    }
}

extension Halfword {
    var hex: String {
        let s = String(self, radix: 16, uppercase: true)
        let pad = String(repeating: "0", count: s.count >= 4 ? 0 : 4 &- s.count)
        return "0x\(pad)\(s)"
    }
}

extension UInt64 {
    var hex: String {
        let s = String(self, radix: 16, uppercase: true)
        let pad = String(repeating: "0", count: s.count >= 16 ? 0 : 16 &- s.count)
        return "0x\(pad)\(s)"
    }
}
