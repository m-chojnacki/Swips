//
//  FPU.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - FPU data registers

struct FPURegisters {
    private var storage = UnsafeMutablePointer<Word>.allocate(capacity: 32)

    /// Raw 32-bit word access.
    subscript(_ index: Word) -> Word {
        get { storage[Int(index)] }
        set { storage[Int(index)] = newValue }
    }

    /// Single-precision (32-bit float) access.
    subscript(single index: Word) -> Float {
        get { Float(bitPattern: storage[Int(index)]) }
        set { storage[Int(index)] = newValue.bitPattern }
    }

    /// Double-precision (64-bit float) access. Index must be even.
    subscript(double index: Word) -> Double {
        get {
            precondition(index & 1 == 0, "FPU double register index must be even")
            let lo = Longword(storage[Int(index)])
            let hi = Longword(storage[Int(index) &+ 1])
            return Double(bitPattern: (hi << 32) | lo)
        }
        set {
            precondition(index & 1 == 0, "FPU double register index must be even")
            let bits = newValue.bitPattern
            storage[Int(index)] = Word(truncatingIfNeeded: bits)
            storage[Int(index) &+ 1] = Word(truncatingIfNeeded: bits >> 32)
        }
    }

    /// Fixed-point (signed 32-bit integer) access.
    subscript(fixed index: Word) -> SignedWord {
        get { SignedWord(bitPattern: storage[Int(index)]) }
        set { storage[Int(index)] = Word(bitPattern: newValue) }
    }
}

// MARK: - FPU control registers (FCSR)

struct FPUControlRegisters {
    private var storage = UnsafeMutablePointer<Word>.allocate(capacity: 32)

    subscript(_ index: Word) -> Word {
        get { storage[Int(index)] }
        set { storage[Int(index)] = newValue }
    }

    /// Condition bit - FPU comparison result (FCSR bit 23).
    var condition: Bool {
        get { storage[31].getBit(23) }
        set { storage[31] = storage[31].withBit(23, set: newValue) }
    }

    /// Rounding mode from FCSR bits [1:0].
    var roundingMode: Word {
        storage[31].bits(from: 1, to: 0)
    }
}

// MARK: - Float/Double → Int32 clamped conversion

extension Double {
    /// Converts to Int32, clamping at the representable range (matches MIPS cvt.w behaviour).
    var asInt32: Int32 {
        if self >= Double(Int32.max) { return .max }
        if self <= Double(Int32.min) { return .min }
        if isFinite { return Int32(self) }
        return .zero
    }
}

extension Float {
    /// Converts to Int32, clamping at the representable range (matches MIPS cvt.w behaviour).
    var asInt32: Int32 {
        if self >= Float(Int32.max) { return .max }
        if self <= Float(Int32.min) { return .min }
        if isFinite { return Int32(self) }
        return .zero
    }
}
