//
//  TLB.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// MARK: - TLB entry

struct TLBEntry {
    let entryHi: Word
    let entryLo: Word

    /// Virtual Page Number (bits [31:12] of EntryHi).
    var vpn: Word {
        entryHi >> 12
    }

    /// Address Space ID (bits [11:6] of EntryHi).
    var asid: Word {
        (entryHi & 0b0000_0000_0000_0000_0000_1111_1100_0000) >> 6
    }

    /// Physical Frame Number (bits [31:12] of EntryLo).
    var pfn: Word {
        entryLo >> 12
    }

    /// Dirty bit - write access is allowed when set.
    var dirty: Bool {
        entryLo.getBit(10)
    }

    /// Valid bit - the entry maps a live page when set.
    var valid: Bool {
        entryLo.getBit(9)
    }

    /// Global bit - ASID is ignored during lookup when set.
    var global: Bool {
        entryLo.getBit(8)
    }

    /// Combined lookup key used for the hash cache.
    var cacheKey: Word {
        vpn << 7 | asid << 1
    }
}

// MARK: - Address translation (extension on VirtualBus)

extension VirtualBus {
    /// Translates a virtual page address using the TLB, throwing on a miss or protection fault.
    func tlbTranslate(_ address: Word, write: Bool, isKUSeg: Bool) throws -> Word {
        let vpn = address >> 12
        let asid = (cp0.entryHi & 0b0000_0000_0000_0000_0000_1111_1100_0000) >> 6
        let key = vpn << 7 | asid << 1

        for entry in tlbCache[key.tlbCacheHash]
            where entry.vpn == vpn && (asid == entry.asid || entry.global)
        {
            if !entry.valid {
                throw MIPSException(
                    code: write ? .tlbMissOnStore : .tlbMissOnLoad,
                    badVAddr: address,
                    entryHi: entry.entryHi,
                )
            }
            if write, !entry.dirty {
                throw MIPSException(
                    code: .tlbModification,
                    badVAddr: address,
                    entryHi: entry.entryHi,
                )
            }
            return (entry.pfn << 12) | (address & 0x0000_0FFF)
        }

        // TLB miss - supply a refill entryHi with the faulting VPN.
        let refillEntryHi = (cp0.entryHi & 0x0000_0FFF) | (address & 0xFFFF_F000)
        throw MIPSException(
            code: write ? .tlbMissOnStore : .tlbMissOnLoad,
            vector: isKUSeg ? .kuSegTLB : .generic,
            badVAddr: address,
            entryHi: refillEntryHi,
        )
    }

    /// TLB write helper (called by COP0 tlbwi / tlbwr instructions)
    func writeTLBEntry(at index: Int, entryHi: Word, entryLo: Word) {
        let newEntry = TLBEntry(entryHi: entryHi, entryLo: entryLo)
        let oldEntry = tlb[index]

        // Remove the old entry from the hash cache.
        tlbCache[oldEntry.cacheKey.tlbCacheHash].removeAll { $0.cacheKey == oldEntry.cacheKey }

        // Install the new entry.
        tlb[index] = newEntry
        tlbCache[newEntry.cacheKey.tlbCacheHash].append(newEntry)
    }
}
