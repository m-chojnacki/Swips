//
//  Addressable.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// MARK: - Non-throwing addressable (physical devices)

protocol Addressable: AnyObject {
    var size: Word { get }

    func readByte(from address: Word) -> Byte
    func readHalfword(from address: Word) -> Halfword
    func readWord(from address: Word) -> Word

    func writeByte(to address: Word, _ value: Byte)
    func writeHalfword(to address: Word, _ value: Halfword)
    func writeWord(to address: Word, _ value: Word)
}

// MARK: - Throwing addressable (virtual address bus - may throw TLB exceptions)

protocol ThrowingAddressable: AnyObject {
    var size: Word { get }

    func readByte(from address: Word) throws(MIPSException) -> Byte
    func readHalfword(from address: Word) throws(MIPSException) -> Halfword
    func readWord(from address: Word) throws(MIPSException) -> Word

    func writeByte(to address: Word, _ value: Byte) throws(MIPSException)
    func writeHalfword(to address: Word, _ value: Halfword) throws(MIPSException)
    func writeWord(to address: Word, _ value: Word) throws(MIPSException)
}

extension ThrowingAddressable {
    /// Loads a binary file into memory at the given address.  Returns the number of bytes loaded.
    @discardableResult
    func load(_ path: String, at offset: Word) -> Word {
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        for (i, byte) in data.enumerated() {
            try! writeByte(to: offset &+ Word(i), byte)
        }
        return Word(data.count)
    }

    /// Writes a null-terminated ASCII string into memory.
    func writeString(to address: Word, _ string: String) {
        let bytes = string.unicodeScalars
            .filter(\.isASCII)
            .map { Byte(truncatingIfNeeded: $0.value) }

        for (i, byte) in (bytes + [0]).enumerated() {
            try! writeByte(to: address &+ Word(i), byte)
        }
    }
}

// MARK: - Byte-only addressable (devices that only implement byte access)

/// Devices conforming to this protocol get halfword/word access synthesised from byte reads/writes.
protocol ByteOnlyAddressable: Addressable {}

extension ByteOnlyAddressable {
    func readHalfword(from address: Word) -> Halfword {
        Halfword(readByte(from: address)) |
            Halfword(readByte(from: address &+ 1)) << 8
    }

    func readWord(from address: Word) -> Word {
        Word(readByte(from: address)) |
            Word(readByte(from: address &+ 1)) << 8 |
            Word(readByte(from: address &+ 2)) << 16 |
            Word(readByte(from: address &+ 3)) << 24
    }

    func writeHalfword(to address: Word, _ value: Halfword) {
        writeByte(to: address, Byte(truncatingIfNeeded: value & 0xFF))
        writeByte(to: address &+ 1, Byte(truncatingIfNeeded: value >> 8))
    }

    func writeWord(to address: Word, _ value: Word) {
        writeByte(to: address, Byte(truncatingIfNeeded: value))
        writeByte(to: address &+ 1, Byte(truncatingIfNeeded: value >> 8))
        writeByte(to: address &+ 2, Byte(truncatingIfNeeded: value >> 16))
        writeByte(to: address &+ 3, Byte(truncatingIfNeeded: value >> 24))
    }
}

// MARK: - Range helper operator

infix operator +>

/// Creates a half-open range `lhs ..< lhs + rhs` with wrapping arithmetic.
func +> <T: FixedWidthInteger>(lhs: T, rhs: T) -> Range<T> {
    lhs ..< (lhs &+ rhs)
}
