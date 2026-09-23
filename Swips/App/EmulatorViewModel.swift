//
//  EmulatorViewModel.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Combine
import Foundation

final class EmulatorViewModel: ObservableObject {
    let uart0IO = TerminalIO()
    let uart1IO = TerminalIO()
    let pixelBuffer = PixelBuffer(width: 800, height: 600)

    private let emulator = Emulator()

    @Published private(set) var mipsSpeed = "MIPS = ?"

    init() {
        emulator.onSpeedUpdate = { [weak self] speed in
            self?.mipsSpeed = String(format: "MIPS = %.2f", speed)
        }

        // Wire UART 0: terminal input → emulator RX buffer; emulator TX → terminal display.
        uart0IO.input = { [emulator] bytes in
            emulator.send { $0.bus.physical.uart0.insertIntoBuffer(bytes) }
        }
        emulator.physical.uart0.txReady = { [uart0IO] byte in
            Task { @MainActor in uart0IO.output([byte]) }
        }

        emulator.scheduleEmulatorLoop()
        scheduleFrameUpdates()
    }

    #if os(macOS)

        // MARK: - Input events support

        func onKeyboardPressed(_ keyCode: KeyMonitor.KeyCode) {
            emulator.send { $0.bus.physical.ps2Keyboard.pressed(keyCode) }
        }

        func onKeyboardReleased(_ keyCode: KeyMonitor.KeyCode) {
            emulator.send { $0.bus.physical.ps2Keyboard.depressed(keyCode) }
        }

        func onMouseMoved(x: SignedHalfword, y: SignedHalfword, left: Bool, right: Bool) {
            emulator.send { $0.bus.physical.ps2Mouse.move(x: x, y: y, left: left, right: right) }
        }
    #endif

    // MARK: - Framebuffer → PixelBuffer conversion

    @MainActor private func redraw() {
        let fb = emulator.physical.framebuffer
        guard fb.isDirty else { return }
        fb.isDirty = false

        for y in 0 ..< Int(fb.height) {
            for x in 0 ..< Int(fb.width) {
                let base = y &* Int(fb.width) &+ x

                // RGB565 is stored little-endian: low byte first.
                let lo = Halfword(fb.buffer[base &* 2])
                let hi = Halfword(fb.buffer[base &* 2 &+ 1])
                let pixel = (hi << 8) | lo

                // Expand 5-6-5 channels to 8 bits each.
                let r5 = (pixel & 0b1111_1000_0000_0000) >> 11
                let g6 = (pixel & 0b0000_0111_1110_0000) >> 5
                let b5 = (pixel & 0b0000_0000_0001_1111)

                let r = Byte(truncatingIfNeeded: (r5 &* 255 &+ 15) / 31)
                let g = Byte(truncatingIfNeeded: (g6 &* 255 &+ 31) / 63)
                let b = Byte(truncatingIfNeeded: (b5 &* 255 &+ 15) / 31)

                pixelBuffer[base &* 4] = r
                pixelBuffer[base &* 4 &+ 1] = g
                pixelBuffer[base &* 4 &+ 2] = b
            }
        }

        pixelBuffer.flush()
    }

    private func scheduleFrameUpdates() {
        Task {
            while !Task.isCancelled {
                await redraw()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }
}
