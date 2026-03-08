//
//  CP0.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// Register map:
//   0  Index     (TLB)
//   1  Random    (TLB)
//   2  EntryLo   (TLB)
//   3  Config    (implementation-specific)
//   4  Context   (TLB)
//   8  BadVAddr  (exception)
//   9  Count     (timer)
//   10 EntryHi   (TLB)
//   11 Compare   (timer interrupt)
//   12 SR        (status register)
//   13 Cause     (exception cause)
//   14 EPC       (exception program counter)
//   15 PRId      (processor revision ID)

/// Coprocessor 0 (System Control Coprocessor) register bank for MIPS.
struct CP0Registers {
    // MARK: - Status Register (SR / CP0 register 12)

    struct StatusRegister: CustomStringConvertible {
        var value: Word = 0

        var cu3: Bool {
            get { value.getBit(31) } set { value = value.withBit(31, set: newValue) }
        }

        var cu2: Bool {
            get { value.getBit(30) } set { value = value.withBit(30, set: newValue) }
        }

        var cu1: Bool {
            get { value.getBit(29) } set { value = value.withBit(29, set: newValue) }
        }

        var cu0: Bool {
            get { value.getBit(28) } set { value = value.withBit(28, set: newValue) }
        }

        /// Reverse endianness in user mode.
        var re: Bool {
            get { value.getBit(25) } set { value = value.withBit(25, set: newValue) }
        }

        /// Bootstrap exception vectors.
        var bev: Bool {
            get { value.getBit(22) } set { value = value.withBit(22, set: newValue) }
        }

        var ts: Bool {
            get { value.getBit(21) } set { value = value.withBit(21, set: newValue) }
        }

        var pe: Bool {
            get { value.getBit(20) } set { value = value.withBit(20, set: newValue) }
        }

        var cm: Bool {
            get { value.getBit(19) } set { value = value.withBit(19, set: newValue) }
        }

        var pz: Bool {
            get { value.getBit(18) } set { value = value.withBit(18, set: newValue) }
        }

        var swc: Bool {
            get { value.getBit(17) } set { value = value.withBit(17, set: newValue) }
        }

        var isc: Bool {
            get { value.getBit(16) } set { value = value.withBit(16, set: newValue) }
        }

        /// Interrupt mask (bits [15:8]).
        var im: Word {
            get { (value & 0x0000_FF00) >> 8 }
            set { value = (value & 0xFFFF_00FF) | ((newValue & 0xFF) << 8) }
        }

        /// Kernel/user mode + interrupt enable: three-level stack (o = old, p = previous, c = current)
        var kuo: Bool {
            get { value.getBit(5) } set { value = value.withBit(5, set: newValue) }
        }

        var ieo: Bool {
            get { value.getBit(4) } set { value = value.withBit(4, set: newValue) }
        }

        var kup: Bool {
            get { value.getBit(3) } set { value = value.withBit(3, set: newValue) }
        }

        var iep: Bool {
            get { value.getBit(2) } set { value = value.withBit(2, set: newValue) }
        }

        var kuc: Bool {
            get { value.getBit(1) } set { value = value.withBit(1, set: newValue) }
        }

        /// Global interrupt enable.
        var iec: Bool {
            get { value.getBit(0) } set { value = value.withBit(0, set: newValue) }
        }

        init() {
            kuc = true
            iec = true
        }

        var description: String {
            "CU3=\(cu3 ? 1 : 0) CU2=\(cu2 ? 1 : 0) CU1=\(cu1 ? 1 : 0) CU0=\(cu0 ? 1 : 0) " +
                "RE=\(re ? 1 : 0) BEV=\(bev ? 1 : 0) TS=\(ts ? 1 : 0) PE=\(pe ? 1 : 0) " +
                "CM=\(cm ? 1 : 0) PZ=\(pz ? 1 : 0) SwC=\(swc ? 1 : 0) IsC=\(isc ? 1 : 0) " +
                "KUo=\(kuo ? 1 : 0) IEo=\(ieo ? 1 : 0) KUp=\(kup ? 1 : 0) IEp=\(iep ? 1 : 0) " +
                "KUc=\(kuc ? 1 : 0) IEc=\(iec ? 1 : 0)"
        }
    }

    // MARK: - Stored registers

    var sr = StatusRegister()
    var cause: Word = 0
    var epc: Word = 0

    var index: Word = 0
    var random: Word = 63
    var config: Word = 0
    var entryHi: Word = 0
    var entryLo: Word = 0
    var context: Word = 0
    var badVAddr: Word = 0

    var count: Word = 0
    var compare: Word = 0xFFFFFF

    // MARK: - Interrupt line

    /// Sets or clears interrupt pending bit `bit` in the Cause register.
    mutating func setInterrupt(bit: Word, pending: Bool) {
        let mask: Word = (1 << bit) << 8
        if pending {
            cause |= mask
        } else {
            cause &= ~mask
        }
    }

    // MARK: - Subscript (register read/write by number)

    subscript(_ reg: Word) -> Word {
        mutating get {
            switch reg {
            case 0: index
            case 1: random << 8
            case 2: entryLo
            case 3: config
            case 4: (context & 0xFF80_0000) | ((badVAddr >> 12) << 2)
            case 8: badVAddr
            case 9: count
            case 10: entryHi
            case 11: compare
            case 12: sr.value
            case 13: cause
            case 14: epc
            case 15: 0x0230 // PRId: R3000A
            default: fatalError("CP0: read from unknown register \(reg)")
            }
        }
        set {
            switch reg {
            case 0: index = newValue
            case 1: random = newValue >> 8
            case 2: entryLo = newValue
            case 3: config = newValue
            case 4: context = newValue
            case 8: badVAddr = newValue
            case 9: count = newValue
            case 10: entryHi = newValue
            case 11:
                cause &= ~0x0000_8000 // clear timer interrupt pending
                compare = newValue
            case 12: sr.value = newValue
            case 13: cause = newValue
            case 14: epc = newValue
            default: fatalError("CP0: write to unknown register \(reg)")
            }
        }
    }
}
