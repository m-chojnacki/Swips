//
//  RAM.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

/// Simple flat RAM block backed by a native pointer for performance.
final class RAM: Addressable {
    let size: Word

    let base: UnsafeMutableRawPointer
    private let bytes: UnsafeMutablePointer<Byte>
    private let halfwords: UnsafeMutablePointer<Halfword>
    private let words: UnsafeMutablePointer<Word>

    init(size: Word) {
        self.size = size
        bytes = .zeroed(count: Int(size))
        base = UnsafeMutableRawPointer(bytes)

        let opaque = OpaquePointer(bytes)
        halfwords = UnsafeMutablePointer<Halfword>(opaque)
        words = UnsafeMutablePointer<Word>(opaque)
    }

    func readByte(from address: Word) -> Byte {
        bytes[Int(address)]
    }

    func writeByte(to address: Word, _ value: Byte) {
        bytes[Int(address)] = value
    }

    func readHalfword(from address: Word) -> Halfword {
        halfwords[Int(address >> 1)]
    }

    func writeHalfword(to address: Word, _ value: Halfword) {
        halfwords[Int(address >> 1)] = value
    }

    func readWord(from address: Word) -> Word {
        words[Int(address >> 2)]
    }

    func writeWord(to address: Word, _ value: Word) {
        words[Int(address >> 2)] = value
    }

    // MARK: - Bulk access (DMA, diagnostics)

    func copyIn(_ source: UnsafeRawBufferPointer, at address: Word) {
        precondition(Int(address) + source.count <= Int(size), "RAM: DMA write out of bounds")
        guard !source.isEmpty else { return }
        UnsafeMutableRawPointer(bytes + Int(address)).copyMemory(from: source.baseAddress!, byteCount: source.count)
    }

    func copyOut(_ destination: UnsafeMutableRawBufferPointer, from address: Word) {
        precondition(Int(address) + destination.count <= Int(size), "RAM: DMA read out of bounds")
        guard !destination.isEmpty else { return }
        destination.baseAddress!.copyMemory(from: bytes + Int(address), byteCount: destination.count)
    }

    var contents: UnsafeRawBufferPointer {
        UnsafeRawBufferPointer(start: bytes, count: Int(size))
    }
}
