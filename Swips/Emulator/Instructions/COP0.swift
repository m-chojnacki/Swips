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
    @inline(__always)
    mutating func op_mfc0(_ i: Word) throws(MIPSException) {
        registers[i.rt] = switch i.rd {
        case 1: clock.random << 8
        case 9: clock.count
        default: bus.cp0[i.rd]
        }
    }

    @inline(__always)
    mutating func op_mtc0(_ i: Word) throws(MIPSException) {
        let value = registers[i.rt]
        switch i.rd {
        case 1:
            clock.setRandom(value >> 8)
        case 9:
            clock.setCount(value, compare: bus.cp0.compare)
        case 10:
            bus.cp0[i.rd] = value
            fetchPage = Self.invalidFetchPage // ASID may have changed
        case 11:
            bus.cp0[i.rd] = value
            clock.rescheduleTimer(compare: value)
        default:
            bus.cp0[i.rd] = value
        }
    }

    // MARK: - TLB instructions

    mutating func op_tlbp(_: Word) throws(MIPSException) {
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

    mutating func op_tlbr(_: Word) throws(MIPSException) {
        // TODO: Implement TLBR (read the TLB entry at CP0 Index into EntryHi/EntryLo).
        fatalError("TLBR not implemented")
    }

    mutating func op_tlbwi(_: Word) throws(MIPSException) {
        // Write current EntryHi/EntryLo into the TLB slot indexed by CP0 Index.
        bus.writeTLBEntry(
            at: Int(bus.cp0.index.bits(from: 13, to: 8)),
            entryHi: bus.cp0.entryHi,
            entryLo: bus.cp0.entryLo,
        )
        fetchPage = Self.invalidFetchPage
    }

    mutating func op_tlbwr(_: Word) throws(MIPSException) {
        // Write current EntryHi/EntryLo into the TLB slot indexed by CP0 Random.
        bus.writeTLBEntry(
            at: Int(clock.random),
            entryHi: bus.cp0.entryHi,
            entryLo: bus.cp0.entryLo,
        )
        fetchPage = Self.invalidFetchPage
    }

    @inline(__always)
    mutating func op_rfe(_: Word) throws(MIPSException) {
        // Restore From Exception - pops the KU/IE mode stack.
        bus.cp0.sr.kuc = bus.cp0.sr.kup; bus.cp0.sr.iec = bus.cp0.sr.iep
        bus.cp0.sr.kup = bus.cp0.sr.kuo; bus.cp0.sr.iep = bus.cp0.sr.ieo

        // Linux returns to user mode with `jr k0; rfe`, so the pending jump tells us where we're headed.
        if let target = branchTarget, target &+ 4 < 0x8000_0000 {
            stats.userEntries += 1
        }
    }
}
