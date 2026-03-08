//
//  ControlFlow.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

// All branches in MIPS have a delay slot: the instruction after the branch
// always executes before the branch takes effect. "Likely" variants (beql,
// bgezl, ...) annul the delay slot if the branch is NOT taken.

extension EmulatorState {
    // MARK: - Helpers

    /// Schedules a delayed branch to the given absolute address.
    /// `address` is stored as (target - 4) because EmulatorRunner adds 4 after each step.
    @inline(__always)
    private mutating func jump(to address: Word) {
        branchTarget = address &- 4
    }

    /// Schedules a PC-relative branch.  `offset` is the 16-bit signed immediate.
    @inline(__always)
    private mutating func branch(by offset: Word) {
        branchTarget = pc &+ offset.signExtendedHalfword << 2
    }

    /// Stores the return address (PC + 8, i.e. instruction after the delay slot) in `reg`.
    @inline(__always)
    private mutating func link(into reg: Word) {
        registers[reg] = pc &+ 8
    }

    // MARK: - Unconditional jumps

    mutating func op_j(_ i: Word) throws {
        jump(to: (pc & 0xF000_0000) | i.target << 2)
    }

    mutating func op_jal(_ i: Word) throws {
        link(into: 31)
        jump(to: (pc & 0xF000_0000) | i.target << 2)
    }

    mutating func op_jr(_ i: Word) throws {
        jump(to: registers[i.rs])
    }

    mutating func op_jalr(_ i: Word) throws {
        link(into: i.rd)
        jump(to: registers[i.rs])
    }

    // MARK: - Conditional branches

    mutating func op_beq(_ i: Word) throws {
        if registers[i.rs] == registers[i.rt] { branch(by: i.immediate) }
    }

    mutating func op_bne(_ i: Word) throws {
        if registers[i.rs] != registers[i.rt] { branch(by: i.immediate) }
    }

    mutating func op_bgez(_ i: Word) throws {
        if registers[i.rs].signed >= 0 { branch(by: i.immediate) }
    }

    mutating func op_bgezal(_ i: Word) throws {
        link(into: 31)
        if registers[i.rs].signed >= 0 { branch(by: i.immediate) }
    }

    mutating func op_bgtz(_ i: Word) throws {
        if registers[i.rs].signed > 0 { branch(by: i.immediate) }
    }

    mutating func op_blez(_ i: Word) throws {
        if registers[i.rs].signed <= 0 { branch(by: i.immediate) }
    }

    mutating func op_bltz(_ i: Word) throws {
        if registers[i.rs].signed < 0 { branch(by: i.immediate) }
    }

    mutating func op_bltzal(_ i: Word) throws {
        link(into: 31)
        if registers[i.rs].signed < 0 { branch(by: i.immediate) }
    }

    // MARK: - Branch Likely variants (delay slot annulled when not taken)

    mutating func op_beql(_ i: Word) throws {
        if registers[i.rs] == registers[i.rt] { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_bnel(_ i: Word) throws {
        if registers[i.rs] != registers[i.rt] { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_bgezl(_ i: Word) throws {
        if registers[i.rs].signed >= 0 { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_bgezall(_ i: Word) throws {
        link(into: 31)
        if registers[i.rs].signed >= 0 { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_bgtzl(_ i: Word) throws {
        if registers[i.rs].signed > 0 { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_blezl(_ i: Word) throws {
        if registers[i.rs].signed <= 0 { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_bltzl(_ i: Word) throws {
        if registers[i.rs].signed < 0 { branch(by: i.immediate) } else { pc &+= 4 }
    }

    mutating func op_bltzall(_ i: Word) throws {
        link(into: 31)
        if registers[i.rs].signed < 0 { branch(by: i.immediate) } else { pc &+= 4 }
    }

    // MARK: - Traps (register vs register)

    mutating func op_tge(_ i: Word) throws {
        if registers[i.rs].signed >= registers[i.rt].signed { throw MIPSException(code: .trap) }
    }

    mutating func op_tgeu(_ i: Word) throws {
        if registers[i.rs] >= registers[i.rt] { throw MIPSException(code: .trap) }
    }

    mutating func op_tlt(_ i: Word) throws {
        if registers[i.rs].signed < registers[i.rt].signed { throw MIPSException(code: .trap) }
    }

    mutating func op_tltu(_ i: Word) throws {
        if registers[i.rs] < registers[i.rt] { throw MIPSException(code: .trap) }
    }

    mutating func op_teq(_ i: Word) throws {
        if registers[i.rs] == registers[i.rt] { throw MIPSException(code: .trap) }
    }

    mutating func op_tne(_ i: Word) throws {
        if registers[i.rs] != registers[i.rt] { throw MIPSException(code: .trap) }
    }

    // MARK: - Traps (register vs immediate)

    mutating func op_tgei(_ i: Word) throws {
        if registers[i.rs].signed >= i.immediate.signExtendedHalfword.signed { throw MIPSException(code: .trap) }
    }

    mutating func op_tgeiu(_ i: Word) throws {
        if registers[i.rs] >= i.immediate.signExtendedHalfword { throw MIPSException(code: .trap) }
    }

    mutating func op_tlti(_ i: Word) throws {
        if registers[i.rs].signed < i.immediate.signExtendedHalfword.signed { throw MIPSException(code: .trap) }
    }

    mutating func op_tltiu(_ i: Word) throws {
        if registers[i.rs] < i.immediate.signExtendedHalfword { throw MIPSException(code: .trap) }
    }

    mutating func op_teqi(_ i: Word) throws {
        if registers[i.rs] == i.immediate.signExtendedHalfword { throw MIPSException(code: .trap) }
    }

    mutating func op_tnei(_ i: Word) throws {
        if registers[i.rs] != i.immediate.signExtendedHalfword { throw MIPSException(code: .trap) }
    }
}
