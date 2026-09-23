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

    private let ramBase: UnsafeMutableRawPointer
    private let ramSize: Word

    var size: Word {
        0xFFFF_FFFF
    }

    // MARK: - TLB state (address-translation hardware; moved here from global scope)

    var cp0 = CP0Registers()

    /// The 64-entry TLB array.
    let tlb: UnsafeMutablePointer<TLBEntry> = {
        let tlb = UnsafeMutablePointer<TLBEntry>.allocate(capacity: 64)
        tlb.initialize(repeating: TLBEntry(entryHi: 0, entryLo: 0), count: 64)
        return tlb
    }()

    static let microTLBMask: Word = 1023

    let microTLB: UnsafeMutablePointer<MicroTLBEntry> = {
        let microTLB = UnsafeMutablePointer<MicroTLBEntry>.allocate(capacity: Int(microTLBMask) + 1)
        microTLB.initialize(repeating: MicroTLBEntry(), count: Int(microTLBMask) + 1)
        return microTLB
    }()

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

    init() {
        ramBase = physical.ram.base
        ramSize = physical.ram.size

        // Device IRQ lines → CP0 Cause interrupt-pending bits.
        physical.uart0.interrupt = { [unowned self] in cp0.setInterrupt(bit: 4, pending: $0) }
        physical.uart1.interrupt = { [unowned self] in cp0.setInterrupt(bit: 5, pending: $0) }
        physical.ps2Keyboard.interrupt = { [unowned self] in cp0.setInterrupt(bit: 3, pending: $0) }
        physical.ps2Mouse.interrupt = { [unowned self] in cp0.setInterrupt(bit: 2, pending: $0) }
    }

    // MARK: - Address translation

    @inline(__always)
    private func translate(_ address: Word, write: Bool) throws(MIPSException) -> Word {
        if address & 0xC000_0000 == 0x8000_0000 {
            // kseg0 (cached) and kseg1 (uncached) are both direct-mapped onto the low 512 MB.
            return address & 0x1FFF_FFFF
        }
        // kuseg (user) or kseg2 (kernel) - TLB mapped.
        let vpn = address >> 12
        let cached = microTLB[Int(vpn & Self.microTLBMask)]
        if cached.tag == MicroTLBEntry.tag(vpn: vpn, asid: (cp0.entryHi >> 6) & 0x3F), !write || cached.writable {
            return cached.frame | (address & 0x0000_0FFF)
        }
        return try translateMapped(address, write: write)
    }

    @inline(never)
    private func translateMapped(_ address: Word, write: Bool) throws(MIPSException) -> Word {
        try tlbTranslate(address, write: write, isKUSeg: address < 0x8000_0000)
    }

    /// Host address of the RAM page backing `address`, if it's in kseg0/kseg1 (no translation needed).
    @inline(__always)
    func unmappedHostPage(at address: Word) -> UnsafeRawPointer? {
        let physical = address & 0x1FFF_FFFF
        guard address & 0xC000_0000 == 0x8000_0000, physical < ramSize else { return nil }
        return UnsafeRawPointer(ramBase + Int(physical & ~0xFFF))
    }

    /// Host address of the RAM page backing `address`, or nil when it isn't RAM. Throws like a load would.
    func hostPage(forFetchAt address: Word) throws(MIPSException) -> UnsafeRawPointer? {
        let physical = try translate(address, write: false)
        guard physical < ramSize else { return nil }
        return UnsafeRawPointer(ramBase + Int(physical & ~0xFFF))
    }

    // MARK: - Access (RAM is served inline; everything else goes through the physical bus)

    @inline(__always)
    func readByte(from address: Word) throws(MIPSException) -> Byte {
        let physical = try translate(address, write: false)
        if physical < ramSize { return ramBase.load(fromByteOffset: Int(physical), as: Byte.self) }
        return self.physical.readByte(from: physical)
    }

    @inline(__always)
    func writeByte(to address: Word, _ value: Byte) throws(MIPSException) {
        let physical = try translate(address, write: true)
        if physical < ramSize { return ramBase.storeBytes(of: value, toByteOffset: Int(physical), as: Byte.self) }
        self.physical.writeByte(to: physical, value)
    }

    // Halfword and word RAM accesses ignore the low address bits, like RAM's own accessors.

    @inline(__always)
    func readHalfword(from address: Word) throws(MIPSException) -> Halfword {
        let physical = try translate(address, write: false)
        if physical < ramSize { return ramBase.load(fromByteOffset: Int(physical & ~1), as: Halfword.self) }
        return self.physical.readHalfword(from: physical)
    }

    @inline(__always)
    func writeHalfword(to address: Word, _ value: Halfword) throws(MIPSException) {
        let physical = try translate(address, write: true)
        if physical < ramSize { return ramBase.storeBytes(of: value, toByteOffset: Int(physical & ~1), as: Halfword.self) }
        self.physical.writeHalfword(to: physical, value)
    }

    @inline(__always)
    func readWord(from address: Word) throws(MIPSException) -> Word {
        let physical = try translate(address, write: false)
        if physical < ramSize { return ramBase.load(fromByteOffset: Int(physical & ~3), as: Word.self) }
        return self.physical.readWord(from: physical)
    }

    @inline(__always)
    func writeWord(to address: Word, _ value: Word) throws(MIPSException) {
        let physical = try translate(address, write: true)
        if physical < ramSize { return ramBase.storeBytes(of: value, toByteOffset: Int(physical & ~3), as: Word.self) }
        self.physical.writeWord(to: physical, value)
    }
}
