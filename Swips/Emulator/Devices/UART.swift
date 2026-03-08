//
//  UART.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

/// 8250-compatible UART peripheral (no FIFO - like the original 8250).
final class UART: ByteOnlyAddressable {
    // MARK: - Register offsets (byte address ÷ shift)

    private enum Reg {
        static let rxTx: Word = 0 // In: Receive / Out: Transmit
        static let ier: Word = 1 // Interrupt Enable Register
        static let iirFcr: Word = 2 // In: Interrupt ID / Out: FIFO Control (no FIFO here)
        static let lcr: Word = 3 // Line Control Register
        static let mcr: Word = 4 // Modem Control Register
        static let lsr: Word = 5 // Line Status Register
        static let msr: Word = 6 // Modem Status Register
    }

    private enum LSRBit {
        static let transmitterEmpty: Byte = 0x40
        static let txHoldingEmpty: Byte = 0x20
        static let dataReady: Byte = 0x01
    }

    // MARK: - Configuration

    let name: String

    init(name: String) {
        self.name = name
    }

    // MARK: - Transmit callback

    /// Called on the emulator thread each time the guest writes a byte to TX.
    var txReady: ((Byte) -> Void)?

    // MARK: - Interrupt state

    var interrupt: ((_ pending: Bool) -> Void)?

    private var modemStatusPending: Bool = false {
        didSet { updateIRQ() }
    }

    private var txHoldingEmptyPending: Bool = false {
        didSet { updateIRQ() }
    }

    private var receivedDataAvailablePending: Bool = false {
        didSet { updateIRQ() }
    }

    private var receiverLineStatusPending: Bool = false {
        didSet { updateIRQ() }
    }

    private var isInterruptPending: Bool {
        modemStatusPending || txHoldingEmptyPending
            || receivedDataAvailablePending || receiverLineStatusPending
    }

    private func updateIRQ() {
        interrupt?(isInterruptPending)
    }

    // MARK: - Receive buffer

    var rxBuffer = [Byte]()

    /// Enqueue bytes into the receive buffer (call from the UI/host thread).
    func insertIntoBuffer(_ bytes: [Byte]) {
        rxBuffer.append(contentsOf: bytes)
        if ier & 0b0000_0001 != 0 {
            receivedDataAvailablePending = true
        }
    }

    // MARK: - Stored register values

    var ier: Byte = 0
    var lcr: Byte = 0
    var mcr: Byte = 0
    var msr: Byte = 0

    var size: Word {
        0x100
    } // occupies 256 bytes; only low 3 bits of the address are decoded

    /// The register index is the byte address shifted right by 2
    /// (the original hardware uses a 4-byte stride between registers).
    private let addressShift: Word = 2

    // MARK: - Read

    func readByte(from address: Word) -> Byte {
        switch address >> addressShift {
        case Reg.rxTx:
            if rxBuffer.isEmpty {
                receivedDataAvailablePending = false
                return 0
            }
            let value = rxBuffer.removeFirst()
            if rxBuffer.isEmpty { receivedDataAvailablePending = false }
            return value

        case Reg.lsr:
            receiverLineStatusPending = false
            return rxBuffer.isEmpty
                ? (LSRBit.transmitterEmpty | LSRBit.txHoldingEmpty)
                : (LSRBit.transmitterEmpty | LSRBit.txHoldingEmpty | LSRBit.dataReady)

        case Reg.ier:
            return ier

        case Reg.iirFcr:
            let val: Byte = if receiverLineStatusPending { 0b0110 } // highest priority
            else if receivedDataAvailablePending { 0b0100 }
            else if txHoldingEmptyPending { 0b0010 }
            else if modemStatusPending { 0b0000 } // lowest priority
            else { 0b0001 } // no interrupt

            txHoldingEmptyPending = false
            return val

        case Reg.lcr: return lcr

        case Reg.mcr: return mcr

        case Reg.msr:
            modemStatusPending = false
            return msr

        default:
            fatalError("UART \(name): read from unknown register \(address >> addressShift)")
        }
    }

    // MARK: - Write

    func writeByte(to address: Word, _ value: Byte) {
        switch address >> addressShift {
        case Reg.rxTx:
            txHoldingEmptyPending = false
            txReady?(value)
            if ier & 0b0000_0010 != 0 {
                txHoldingEmptyPending = true
            }

        case Reg.ier:
            ier = value

        case Reg.iirFcr:
            break // 8250 has no FIFO - FCR writes are ignored

        case Reg.lcr: lcr = value

        case Reg.mcr: mcr = value

        default:
            fatalError("UART \(name): write to unknown register \(address >> addressShift)")
        }
    }
}
