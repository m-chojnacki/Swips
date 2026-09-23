//
//  FramebufferSnapshot.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FramebufferSnapshot {
    /// Whether at least 75% of a 16×16 grid of sampled pixels is non-black.
    static func isMostlyLit(_ framebuffer: Framebuffer) -> Bool {
        let width = Int(framebuffer.width), height = Int(framebuffer.height)
        var lit = 0
        for row in 0 ..< 16 {
            for column in 0 ..< 16 {
                let index = (row * height / 16 + height / 32) * width + column * width / 16 + width / 32
                if framebuffer.buffer[index * 2] | framebuffer.buffer[index * 2 + 1] != 0 { lit += 1 }
            }
        }
        return lit >= 192
    }

    static func writePNG(_ framebuffer: Framebuffer, to path: String) {
        let width = Int(framebuffer.width), height = Int(framebuffer.height)
        var rgbx = [Byte](repeating: 0xFF, count: width * height * 4)

        for index in 0 ..< width * height {
            let pixel = Halfword(framebuffer.buffer[index * 2]) | Halfword(framebuffer.buffer[index * 2 + 1]) << 8
            rgbx[index * 4] = Byte((pixel >> 11) * 255 / 31)
            rgbx[index * 4 + 1] = Byte((pixel >> 5 & 0x3F) * 255 / 63)
            rgbx[index * 4 + 2] = Byte((pixel & 0x1F) * 255 / 31)
        }

        let image = CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: CGDataProvider(data: Data(rgbx) as CFData)!,
            decode: nil, shouldInterpolate: false, intent: .defaultIntent,
        )!

        let url = URL(fileURLWithPath: path) as CFURL
        let destination = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
