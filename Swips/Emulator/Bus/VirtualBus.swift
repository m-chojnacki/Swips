//
//  VirtualBus.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// MIPS virtual address space:
//   0x00000000 – 0x7FFFFFFF  kuseg  - user space, TLB-mapped
//   0x80000000 – 0x9FFFFFFF  kseg0  - kernel, cached, mapped by stripping bit 31
//   0xA0000000 – 0xBFFFFFFF  kseg1  - kernel, uncached, mapped by stripping top 3 bits
//   0xC0000000 – 0xFFFFFFFF  kseg2  - kernel, TLB-mapped

/// Virtual address bus - translates MIPS virtual addresses to physical ones.
final class VirtualBus: ThrowingAddressable {
    let physical = PhysicalBus()

    var size: Word {
        0xFFFF_FFFF
    }

    // MARK: - TLB state (address-translation hardware; moved here from global scope)

    var cp0 = CP0Registers()

    /// The 64-entry TLB array.
    let tlb = UnsafeMutablePointer<TLBEntry>.allocate(capacity: 64)

    /// 256-bucket hash cache; each bucket holds TLBEntries that hash there.
    var tlbCache: [[TLBEntry]] = {
        var cache = [[TLBEntry]]()
        cache.reserveCapacity(256)
        for _ in 0 ..< 256 {
            var bucket = [TLBEntry]()
            bucket.reserveCapacity(4)
            cache.append(bucket)
        }
        return cache
    }()

    // MARK: - Address translation

    private func translate(_ address: Word, write: Bool) throws -> Word {
        switch address {
        case 0x8000_0000 ... 0x9FFF_FFFF: // kseg0 - cached, direct-mapped
            address & 0x7FFF_FFFF

        case 0xA000_0000 ... 0xBFFF_FFFF: // kseg1 - uncached, direct-mapped
            address & 0x1FFF_FFFF

        case 0x0000_0000 ... 0x7FFF_FFFF: // kuseg - TLB mapped
            try tlbTranslate(address, write: write, isKUSeg: true)

        case 0xC000_0000 ... 0xFFFF_FFFF: // kseg2 - TLB mapped (kernel only)
            try tlbTranslate(address, write: write, isKUSeg: false)

        default:
            fatalError("VirtualBus: address \(address.hex) fell through all cases")
        }
    }

    func readByte(from address: Word) throws -> Byte {
        try physical.readByte(from: translate(address, write: false))
    }

    func writeByte(to address: Word, _ value: Byte) throws {
        try physical.writeByte(to: translate(address, write: true), value)
    }

    func readHalfword(from address: Word) throws -> Halfword {
        try physical.readHalfword(from: translate(address, write: false))
    }

    func writeHalfword(to address: Word, _ value: Halfword) throws {
        try physical.writeHalfword(to: translate(address, write: true), value)
    }

    func readWord(from address: Word) throws -> Word {
        try physical.readWord(from: translate(address, write: false))
    }

    func writeWord(to address: Word, _ value: Word) throws {
        try physical.writeWord(to: translate(address, write: true), value)
    }
}
