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
final class Framebuffer: ByteOnlyAddressable {
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

    /// Called on every byte write; the UI layer uses this to mark the framebuffer dirty.
    var onWrite: ((Word, Byte) -> Void)?

    init(width: Word = 800, height: Word = 600, format: PixelFormat = .rgb565) {
        self.width = width
        self.height = height
        self.format = format
        buffer = UnsafeMutablePointer<Byte>.allocate(
            capacity: Int(width &* height &* format.bytesPerPixel),
        )
    }

    var size: Word {
        width &* height &* format.bytesPerPixel
    }

    func readByte(from address: Word) -> Byte {
        buffer[Int(address)]
    }

    func writeByte(to address: Word, _ value: Byte) {
        buffer[Int(address)] = value
        onWrite?(address, value)
    }
}
