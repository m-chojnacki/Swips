//
//  PhysicalBus.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// Physical memory map:
//   0x00000000 – 0x0FFFFFFF  RAM (256 MB)
//   0x10030000 – 0x100300FF  UART 0
//   0x10030100 – 0x100301FF  UART 1
//   0x10040000 – 0x10040007  PS/2 Keyboard
//   0x10040100 – 0x10040107  PS/2 Mouse
//   0x11000000 – 0x11000013  Block device (KokoDrive)
//   0x1A000000 – ...         Framebuffer (800×600, RGB565)
//   0x1FC00000 – 0x1FFFFFFF  ROM (boot ROM)

/// Physical address bus - maps physical addresses to individual hardware devices.
final class PhysicalBus: Addressable {
    // MARK: - Attached devices

    let ram = RAM(size: 0x1000_0000) // 256 MB
    let rom = RAM(size: 0x0100_0000) // 16 MB
    let uart0 = UART(name: "UART0")
    let uart1 = UART(name: "UART1")
    let ps2Keyboard = PS2Keyboard()
    let ps2Mouse = PS2Mouse()
    let framebuffer = Framebuffer()
    let blockDevice = BlockDevice()

    init() {
        blockDevice.ram = ram
    }

    var size: Word {
        0xFFFF_FFFF
    }

    // MARK: - Address decode

    @discardableResult
    private func dispatch<T>(_ address: Word, _ body: (Addressable, Word) -> T) -> T {
        switch address {
        case 0x0000_0000 +> ram.size:
            body(ram, address)

        case 0x1A00_0000 +> framebuffer.size:
            body(framebuffer, address &- 0x1A00_0000)

        case 0x1FC0_0000 +> rom.size:
            body(rom, address &- 0x1FC0_0000)

        case 0x1003_0000 +> uart0.size:
            body(uart0, address &- 0x1003_0000)

        case 0x1003_0100 +> uart1.size:
            body(uart1, address &- 0x1003_0100)

        case 0x1004_0000 +> ps2Keyboard.size:
            body(ps2Keyboard, address &- 0x1004_0000)

        case 0x1004_0100 +> ps2Mouse.size:
            body(ps2Mouse, address &- 0x1004_0100)

        case 0x1100_0000 +> blockDevice.size:
            body(blockDevice, address &- 0x1100_0000)

        default:
            fatalError("PhysicalBus: access to unmapped address \(address.hex)")
        }
    }

    func readByte(from address: Word) -> Byte {
        dispatch(address) { $0.readByte(from: $1) }
    }

    func writeByte(to address: Word, _ v: Byte) {
        dispatch(address) { $0.writeByte(to: $1, v) }
    }

    func readHalfword(from address: Word) -> Halfword {
        dispatch(address) { $0.readHalfword(from: $1) }
    }

    func writeHalfword(to address: Word, _ v: Halfword) {
        dispatch(address) { $0.writeHalfword(to: $1, v) }
    }

    func readWord(from address: Word) -> Word {
        dispatch(address) { $0.readWord(from: $1) }
    }

    func writeWord(to address: Word, _ v: Word) {
        dispatch(address) { $0.writeWord(to: $1, v) }
    }
}
