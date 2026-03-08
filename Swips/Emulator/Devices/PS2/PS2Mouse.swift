//
//  PS2Mouse.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

final class PS2Mouse: PS2Controller {
    enum Mode { case stream, remote, wrap }
    enum Scaling { case oneToOne, twoToOne }

    private var sampleRate: Byte = 0
    private var resolution: Byte = 0
    private var scaling = Scaling.oneToOne
    private var dataReporting = false
    private var mode = Mode.stream
    private var modeBeforeWrap = Mode.stream
    private var deviceId: Byte = 0
    private var intelliMouseStep = 0 // tracks the 200→100→80 sequence for IntelliMouse detection

    func move(x: SignedHalfword, y: SignedHalfword, left: Bool, right: Bool) {
        guard mode == .stream, dataReporting else { return }

        var flags: Byte = 0b0000_1000 // always-set bit
        if x < 0 { flags |= 0b0001_0000 }
        if y < 0 { flags |= 0b0010_0000 }
        if left { flags |= 0b0000_0001 }
        if right { flags |= 0b0000_0010 }

        inputBuffer.append(flags)
        inputBuffer.append(Byte(truncatingIfNeeded: x))
        inputBuffer.append(Byte(truncatingIfNeeded: y))
        inputBuffer.append(0) // scroll wheel (not implemented)
    }

    private func setDefaults() {
        sampleRate = 100
        resolution = 0x02
        scaling = .oneToOne
        dataReporting = false
        mode = .stream
    }

    override func handleCommand() {
        guard !commandBuffer.isEmpty else { return }

        switch (commandBuffer[safe: 0], commandBuffer[safe: 1]) {
        case (0xFF, _): // Reset
            inputBuffer.append(0xFA)
            setDefaults()
            deviceId = 0
            intelliMouseStep = 0
            inputBuffer.append(0xAA)
            inputBuffer.append(0x00)
            commandBuffer.removeFirst()

        case (0xF2, _): // Get device ID
            inputBuffer.append(0xFA)
            inputBuffer.append(deviceId)
            commandBuffer.removeFirst()

        case (0xF6, _): // Set defaults
            inputBuffer.append(0xFA)
            setDefaults()
            commandBuffer.removeFirst()

        case (0xF3, .none): // Set sample rate - waiting for argument
            inputBuffer.append(0xFA)

        case let (0xF3, .some(arg)): // Set sample rate - argument received
            sampleRate = arg
            // Detect IntelliMouse (scroll wheel) via the magic 200→100→80 sequence.
            if intelliMouseStep == 0, sampleRate == 200 { intelliMouseStep = 1 }
            else if intelliMouseStep == 1, sampleRate == 100 { intelliMouseStep = 2 }
            else if intelliMouseStep == 2, sampleRate == 80 { intelliMouseStep = 0; deviceId = 0x03 }
            else { intelliMouseStep = 0 }

            commandBuffer.removeFirst()
            commandBuffer.removeFirst()
            inputBuffer.append(0xFA)

        case (0xE8, .none): // Set resolution - waiting for argument
            inputBuffer.append(0xFA)

        case let (0xE8, .some(arg)): // Set resolution - argument received
            resolution = arg
            commandBuffer.removeFirst()
            commandBuffer.removeFirst()
            inputBuffer.append(0xFA)

        case (0xE9, _): // Status request
            inputBuffer.append(0xFA)
            inputBuffer.append(0x00)
            inputBuffer.append(resolution)
            inputBuffer.append(sampleRate)
            commandBuffer.removeFirst()

        case (0xE7, _): // Scale 2:1
            scaling = .twoToOne
            inputBuffer.append(0xFA)
            commandBuffer.removeFirst()

        case (0xE6, _): // Scale 1:1
            scaling = .oneToOne
            inputBuffer.append(0xFA)
            commandBuffer.removeFirst()

        case (0xEA, _): // Set stream mode
            inputBuffer.append(0xFA)
            commandBuffer.removeFirst()
            mode = .stream

        case (0xEC, _): // Reset wrap mode
            inputBuffer.append(0xFA)
            commandBuffer.removeFirst()
            mode = modeBeforeWrap

        case (0xF4, _): // Enable data reporting
            inputBuffer.append(0xFA)
            commandBuffer.removeFirst()
            dataReporting = true

        case (0xF5, _): // Disable data reporting
            inputBuffer.append(0xFA)
            commandBuffer.removeFirst()
            dataReporting = false

        default:
            inputBuffer.append(0xFF) // NACK unknown commands
            commandBuffer.removeFirst()
        }
    }
}
