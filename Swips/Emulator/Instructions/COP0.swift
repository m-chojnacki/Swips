//
//  COP0.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    mutating func op_mfc0(_ i: Word) throws {
        registers[i.rt] = bus.cp0[i.rd]
    }

    mutating func op_mtc0(_ i: Word) throws {
        bus.cp0[i.rd] = registers[i.rt]
    }

    // MARK: - TLB instructions

    mutating func op_tlbp(_: Word) throws {
        // Probe the TLB for an entry matching EntryHi; write the index to CP0 Index register.
        let vpn = bus.cp0.entryHi >> 12
        let asid = (bus.cp0.entryHi & 0b0000_0000_0000_0000_0000_1111_1100_0000) >> 6

        for idx in 0 ..< 64 {
            let entry = bus.tlb[idx]
            let asidMatch = asid == entry.asid
            // TODO: !entry.global?
            if entry.vpn == vpn, asidMatch || entry.global {
                bus.cp0.index = Word(idx) << 8
                return
            }
        }

        // Set the P (Probe Failure) bit in Index when no match is found.
        bus.cp0.index |= 0x8000_0000
    }

    mutating func op_tlbr(_: Word) throws {
        // TODO: Implement TLBR (read the TLB entry at CP0 Index into EntryHi/EntryLo).
        fatalError("TLBR not implemented")
    }

    mutating func op_tlbwi(_: Word) throws {
        // Write current EntryHi/EntryLo into the TLB slot indexed by CP0 Index.
        bus.writeTLBEntry(
            at: Int(bus.cp0.index.bits(from: 13, to: 8)),
            entryHi: bus.cp0.entryHi,
            entryLo: bus.cp0.entryLo,
        )
    }

    mutating func op_tlbwr(_: Word) throws {
        // Write current EntryHi/EntryLo into the TLB slot indexed by CP0 Random.
        bus.writeTLBEntry(
            at: Int(bus.cp0.random),
            entryHi: bus.cp0.entryHi,
            entryLo: bus.cp0.entryLo,
        )
    }

    mutating func op_rfe(_: Word) throws {
        // Restore From Exception - pops the KU/IE mode stack.
        bus.cp0.sr.kuc = bus.cp0.sr.kup; bus.cp0.sr.iec = bus.cp0.sr.iep
        bus.cp0.sr.kup = bus.cp0.sr.kuo; bus.cp0.sr.iep = bus.cp0.sr.ieo
    }
}
