//
//  Framebuffer.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

/// Memory-mapped framebuffer device (RGB565, 800×600 by default).
final class Framebuffer: Addressable {
    enum PixelFormat {
        case rgb565 // 2 bytes per pixel

        var bytesPerPixel: Word {
            switch self {
            case .rgb565: 2
            }
        }
    }

    let width: Word
    let height: Word
    let format: PixelFormat

    private(set) var buffer: UnsafeMutablePointer<Byte>
    private let raw: UnsafeMutableRawPointer

    /// Set on every write. The UI clears it before copying the pixels, so a write racing with the copy
    /// just marks the next frame dirty.
    var isDirty = true

    init(width: Word = 800, height: Word = 600, format: PixelFormat = .rgb565) {
        self.width = width
        self.height = height
        self.format = format
        buffer = .zeroed(count: Int(width &* height &* format.bytesPerPixel))
        raw = UnsafeMutableRawPointer(buffer)
    }

    var size: Word {
        width &* height &* format.bytesPerPixel
    }

    // Wider accesses are little-endian and may be unaligned, exactly like composing them from bytes.

    func readByte(from address: Word) -> Byte {
        buffer[Int(address)]
    }

    func readHalfword(from address: Word) -> Halfword {
        Halfword(littleEndian: raw.loadUnaligned(fromByteOffset: Int(address), as: Halfword.self))
    }

    func readWord(from address: Word) -> Word {
        Word(littleEndian: raw.loadUnaligned(fromByteOffset: Int(address), as: Word.self))
    }

    func writeByte(to address: Word, _ value: Byte) {
        buffer[Int(address)] = value
        isDirty = true
    }

    func writeHalfword(to address: Word, _ value: Halfword) {
        raw.storeBytes(of: value.littleEndian, toByteOffset: Int(address), as: Halfword.self)
        isDirty = true
    }

    func writeWord(to address: Word, _ value: Word) {
        raw.storeBytes(of: value.littleEndian, toByteOffset: Int(address), as: Word.self)
        isDirty = true
    }
}
