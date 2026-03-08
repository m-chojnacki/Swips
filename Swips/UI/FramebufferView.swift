//
//  FramebufferView.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import SwiftUI

#if os(macOS)
    struct FramebufferView: NSViewRepresentable {
        let pixels: PixelBuffer

        func makeNSView(context _: Context) -> NSView {
            let view = pixels.platformView
            view.wantsLayer = true
            view.layer?.magnificationFilter = .nearest
            pixels.flush()
            return view
        }

        func updateNSView(_: NSView, context _: Context) {}
    }
#else
    struct FramebufferView: UIViewRepresentable {
        let pixels: PixelBuffer

        func makeUIView(context _: Context) -> UIView {
            let view = pixels.platformView
            view.layer.magnificationFilter = .nearest
            pixels.flush()
            return view
        }

        func updateUIView(_: UIView, context _: Context) {}
    }
#endif

// MARK: - PixelBuffer

/// An RGBA8888 pixel buffer backed by a CGDataProvider.
/// Writes go directly into a raw pointer; call `flush()` to push the image to the layer.
final class PixelBuffer {
    let width: Int
    let height: Int

    private let bytesPerPixel = 4

    #if os(macOS)
        fileprivate let platformView = NSView()
    #else
        fileprivate let platformView = UIView()
    #endif

    private let data: UnsafeMutablePointer<Byte>
    private let dataProvider: CGDataProvider

    subscript(_ index: Int) -> Byte {
        get { data[index] }
        set { data[index] = newValue }
    }

    init(width: Int, height: Int) {
        self.width = width
        self.height = height

        let length = width &* height &* bytesPerPixel
        data = UnsafeMutablePointer<Byte>.allocate(capacity: length)

        var callbacks = CGDataProviderDirectCallbacks(
            version: 0,
            getBytePointer: { UnsafeRawPointer($0) },
            releaseBytePointer: nil,
            getBytesAtPosition: nil,
            releaseInfo: nil,
        )

        dataProvider = CGDataProvider(
            directInfo: data,
            size: off_t(length),
            callbacks: &callbacks,
        )!
    }

    /// Pushes the current pixel data to the view layer.
    func flush() {
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: bytesPerPixel &* 8,
            bytesPerRow: width &* bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent,
        )!

        #if os(macOS)
            platformView.layer?.contents = image
        #else
            platformView.layer.contents = image
        #endif
    }
}
