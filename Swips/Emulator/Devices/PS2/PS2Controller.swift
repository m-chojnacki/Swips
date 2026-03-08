//
//  PS2Controller.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

class PS2Controller: Addressable {
    private enum Reg {
        static let fifo: Word = 0 // read: pop byte from input FIFO; write: send command byte
        static let irqEnabled: Word = 1
    }

    private let addressShift: Word = 2

    private var irqEnabled = false {
        didSet { updateIRQ() }
    }

    /// Bytes arriving from the device to the host (keyboard/mouse → CPU).
    var inputBuffer: [Byte] = [] {
        didSet { updateIRQ() }
    }

    /// Bytes sent from the host to the device (CPU → keyboard/mouse).
    var commandBuffer: [Byte] = []

    var interrupt: ((_ pending: Bool) -> Void)?

    private var isInterruptPending: Bool {
        irqEnabled && !inputBuffer.isEmpty
    }

    private func updateIRQ() {
        interrupt?(isInterruptPending)
    }

    var size: Word {
        8
    }

    /// Promote byte/halfword reads/writes to word operations.
    func readByte(from address: Word) -> Byte {
        Byte(truncatingIfNeeded: readWord(from: address))
    }

    func writeByte(to address: Word, _ v: Byte) {
        writeWord(to: address, Word(v))
    }

    func readHalfword(from address: Word) -> Halfword {
        Halfword(truncatingIfNeeded: readWord(from: address))
    }

    func writeHalfword(to address: Word, _ v: Halfword) {
        writeWord(to: address, Word(v))
    }

    func readWord(from address: Word) -> Word {
        switch address >> addressShift {
        case Reg.fifo:
            guard !inputBuffer.isEmpty else { return 0 }
            let remaining = Word(inputBuffer.count)
            let first = Word(inputBuffer.removeFirst())
            return first | (remaining << 16)

        case Reg.irqEnabled:
            return irqEnabled ? 1 : 0

        default:
            fatalError("PS2: read from unknown register \(address >> addressShift)")
        }
    }

    func writeWord(to address: Word, _ value: Word) {
        switch address >> addressShift {
        case Reg.fifo:
            commandBuffer.append(Byte(truncatingIfNeeded: value))
            handleCommand()

        case Reg.irqEnabled:
            irqEnabled = value != 0

        default:
            fatalError("PS2: write to unknown register \(address >> addressShift)")
        }
    }

    /// Override in subclasses to process `commandBuffer`.
    func handleCommand() {}
}
