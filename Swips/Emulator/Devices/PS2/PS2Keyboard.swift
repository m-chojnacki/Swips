//
//  PS2Keyboard.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

final class PS2Keyboard: PS2Controller {
    override func handleCommand() {
        guard !commandBuffer.isEmpty else { return }

        switch (commandBuffer[safe: 0], commandBuffer[safe: 1]) {
        case (0xFF, _): // Reset
            inputBuffer.append(0xFA) // ACK
            inputBuffer.append(0xAA) // BAT OK
            commandBuffer.removeFirst()

        case (0xF2, _): // Get device ID
            inputBuffer.append(0xAB)
            inputBuffer.append(0x83)
            commandBuffer.removeFirst()

        case (0xED, .none): // Set LEDs - waiting for argument
            inputBuffer.append(0xFA)

        case (0xED, .some): // Set LEDs - argument received
            commandBuffer.removeFirst()
            commandBuffer.removeFirst()
            inputBuffer.append(0xFA)

        case (0xF3, .none): // Set typematic - waiting for argument
            inputBuffer.append(0xFA)

        case (0xF3, .some): // Set typematic - argument received
            commandBuffer.removeFirst()
            commandBuffer.removeFirst()
            inputBuffer.append(0xFA)

        case (0xF4, _): // Enable scanning
            commandBuffer.removeFirst()
            inputBuffer.append(0xFA)

        default:
            fatalError("PS2Keyboard: unknown command \(commandBuffer[0].hex)")
        }
    }

    func pressed(_ keyCode: Halfword) {
        if let seq = keyScanCodes[keyCode] {
            inputBuffer.append(contentsOf: seq.pressed)
        }
    }

    func depressed(_ keyCode: Halfword) {
        if let seq = keyScanCodes[keyCode] {
            inputBuffer.append(contentsOf: seq.released)
        }
    }
}

// MARK: - macOS virtual key code → PS/2 scan code set 2 mapping

private let keyScanCodes: [Halfword: (pressed: [Byte], released: [Byte])] = [
    0: (pressed: [0x1C], released: [0xF0, 0x1C]), // A
    11: (pressed: [0x32], released: [0xF0, 0x32]), // B
    8: (pressed: [0x21], released: [0xF0, 0x21]), // C
    2: (pressed: [0x23], released: [0xF0, 0x23]), // D
    14: (pressed: [0x24], released: [0xF0, 0x24]), // E
    3: (pressed: [0x2B], released: [0xF0, 0x2B]), // F
    5: (pressed: [0x34], released: [0xF0, 0x34]), // G
    4: (pressed: [0x33], released: [0xF0, 0x33]), // H
    34: (pressed: [0x43], released: [0xF0, 0x43]), // I
    38: (pressed: [0x3B], released: [0xF0, 0x3B]), // J
    40: (pressed: [0x42], released: [0xF0, 0x42]), // K
    37: (pressed: [0x4B], released: [0xF0, 0x4B]), // L
    46: (pressed: [0x3A], released: [0xF0, 0x3A]), // M
    45: (pressed: [0x31], released: [0xF0, 0x31]), // N
    31: (pressed: [0x44], released: [0xF0, 0x44]), // O
    35: (pressed: [0x4D], released: [0xF0, 0x4D]), // P
    12: (pressed: [0x15], released: [0xF0, 0x15]), // Q
    15: (pressed: [0x2D], released: [0xF0, 0x2D]), // R
    1: (pressed: [0x1B], released: [0xF0, 0x1B]), // S
    17: (pressed: [0x2C], released: [0xF0, 0x2C]), // T
    32: (pressed: [0x3C], released: [0xF0, 0x3C]), // U
    9: (pressed: [0x2A], released: [0xF0, 0x2A]), // V
    13: (pressed: [0x1D], released: [0xF0, 0x1D]), // W
    7: (pressed: [0x22], released: [0xF0, 0x22]), // X
    16: (pressed: [0x35], released: [0xF0, 0x35]), // Y
    6: (pressed: [0x1A], released: [0xF0, 0x1A]), // Z
    29: (pressed: [0x45], released: [0xF0, 0x45]), // 0
    18: (pressed: [0x16], released: [0xF0, 0x16]), // 1
    19: (pressed: [0x1E], released: [0xF0, 0x1E]), // 2
    20: (pressed: [0x26], released: [0xF0, 0x26]), // 3
    21: (pressed: [0x25], released: [0xF0, 0x25]), // 4
    23: (pressed: [0x2E], released: [0xF0, 0x2E]), // 5
    22: (pressed: [0x36], released: [0xF0, 0x36]), // 6
    26: (pressed: [0x3D], released: [0xF0, 0x3D]), // 7
    28: (pressed: [0x3E], released: [0xF0, 0x3E]), // 8
    25: (pressed: [0x46], released: [0xF0, 0x46]), // 9
    50: (pressed: [0x0E], released: [0xF0, 0x0E]), // `
    27: (pressed: [0x4E], released: [0xF0, 0x4E]), // -
    24: (pressed: [0x55], released: [0xF0, 0x55]), // =
    42: (pressed: [0x5D], released: [0xF0, 0x5D]), // backslash
    51: (pressed: [0x66], released: [0xF0, 0x66]), // Backspace
    49: (pressed: [0x29], released: [0xF0, 0x29]), // Space
    48: (pressed: [0x0D], released: [0xF0, 0x0D]), // Tab
    56: (pressed: [0x12], released: [0xF0, 0x12]), // Left Shift
    59: (pressed: [0x14], released: [0xF0, 0x14]), // Left Ctrl
    55: (pressed: [0xE0, 0x1F], released: [0xE0, 0xF0, 0x1F]), // Left GUI
    58: (pressed: [0x11], released: [0xF0, 0x11]), // Left Alt
    60: (pressed: [0x59], released: [0xF0, 0x59]), // Right Shift
    54: (pressed: [0xE0, 0x27], released: [0xE0, 0xF0, 0x27]), // Right GUI
    61: (pressed: [0xE0, 0x11], released: [0xE0, 0xF0, 0x11]), // Right Alt
    36: (pressed: [0x5A], released: [0xF0, 0x5A]), // Return
    53: (pressed: [0x76], released: [0xF0, 0x76]), // Escape
    122: (pressed: [0x05], released: [0xF0, 0x05]), // F1
    120: (pressed: [0x06], released: [0xF0, 0x06]), // F2
    99: (pressed: [0x04], released: [0xF0, 0x04]), // F3
    118: (pressed: [0x0C], released: [0xF0, 0x0C]), // F4
    96: (pressed: [0x03], released: [0xF0, 0x03]), // F5
    97: (pressed: [0x0B], released: [0xF0, 0x0B]), // F6
    98: (pressed: [0x83], released: [0xF0, 0x83]), // F7
    100: (pressed: [0x0A], released: [0xF0, 0x0A]), // F8
    101: (pressed: [0x01], released: [0xF0, 0x01]), // F9
    109: (pressed: [0x09], released: [0xF0, 0x09]), // F10
    103: (pressed: [0x78], released: [0xF0, 0x78]), // F11
    111: (pressed: [0x07], released: [0xF0, 0x07]), // F12
    33: (pressed: [0x54], released: [0xF0, 0x54]), // [
    30: (pressed: [0x5B], released: [0xF0, 0x5B]), // ]
    41: (pressed: [0x4C], released: [0xF0, 0x4C]), // ;
    39: (pressed: [0x52], released: [0xF0, 0x52]), // '
    43: (pressed: [0x41], released: [0xF0, 0x41]), // ,
    47: (pressed: [0x49], released: [0xF0, 0x49]), // .
    44: (pressed: [0x4A], released: [0xF0, 0x4A]), // /
    126: (pressed: [0xE0, 0x75], released: [0xE0, 0xF0, 0x75]), // Up arrow
    123: (pressed: [0xE0, 0x6B], released: [0xE0, 0xF0, 0x6B]), // Left arrow
    125: (pressed: [0xE0, 0x72], released: [0xE0, 0xF0, 0x72]), // Down arrow
    124: (pressed: [0xE0, 0x74], released: [0xE0, 0xF0, 0x74]), // Right arrow
]
