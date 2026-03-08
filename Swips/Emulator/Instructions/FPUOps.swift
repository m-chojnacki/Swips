//
//  FPUOps.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// Coprocessor 1 (FPU) instruction implementations.
//
// MIPS FPU instruction encoding:
//   fd  = bits[10:6]  - destination FPU register
//   fs  = bits[15:11] - source FPU register 1
//   ft  = bits[20:16] - source FPU register 2
//
// Note: fd/fs/ft are defined as Word extensions in Types.swift.

extension EmulatorState {
    // MARK: - FPU ↔ GPR transfers

    mutating func op_mfc1(_ i: Word) throws {
        // Move from FPU register (fs field = bits[15:11]) to GPR (rt).
        registers[i.rt] = fpu[i.fs]
    }

    mutating func op_mtc1(_ i: Word) throws {
        // Move from GPR (rt) to FPU register (fs field = bits[15:11]).
        fpu[i.fs] = registers[i.rt]
    }

    mutating func op_cfc1(_ i: Word) throws {
        // Move from FPU control register (fs field) to GPR (rt).
        registers[i.rt] = fcsr[i.fs]
    }

    mutating func op_ctc1(_ i: Word) throws {
        // Move from GPR (rt) to FPU control register (fs field).
        fcsr[i.fs] = registers[i.rt]
    }

    // MARK: - FPU loads / stores

    mutating func op_lwc1(_ i: Word) throws {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        fpu[i.rt] = try bus.readWord(from: addr)
    }

    mutating func op_swc1(_ i: Word) throws {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        try bus.writeWord(to: addr, fpu[i.rt])
    }

    mutating func op_ldc1(_ i: Word) throws {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        fpu[i.rt] = try bus.readWord(from: addr)
        fpu[i.rt &+ 1] = try bus.readWord(from: addr &+ 4)
    }

    mutating func op_sdc1(_ i: Word) throws {
        let addr = i.immediate.signExtendedHalfword &+ registers[i.rs]
        try bus.writeWord(to: addr, fpu[i.rt])
        try bus.writeWord(to: addr &+ 4, fpu[i.rt &+ 1])
    }

    // MARK: - FPU branches

    mutating func op_bc1f(_ i: Word) throws {
        if !fcsr.condition { branchTarget = pc &+ i.immediate.signExtendedHalfword << 2 }
    }

    mutating func op_bc1t(_ i: Word) throws {
        if fcsr.condition { branchTarget = pc &+ i.immediate.signExtendedHalfword << 2 }
    }

    mutating func op_bc1fl(_ i: Word) throws { // branch likely - annul delay slot if not taken
        if !fcsr.condition { branchTarget = pc &+ i.immediate.signExtendedHalfword << 2 }
        else { pc &+= 4 }
    }

    mutating func op_bc1tl(_ i: Word) throws {
        if fcsr.condition { branchTarget = pc &+ i.immediate.signExtendedHalfword << 2 }
        else { pc &+= 4 }
    }

    // MARK: - Single-precision arithmetic

    mutating func op_abs_s(_ i: Word) throws {
        fpu[single: i.fd] = abs(fpu[single: i.fs])
    }

    mutating func op_neg_s(_ i: Word) throws {
        fpu[single: i.fd] = -fpu[single: i.fs]
    }

    mutating func op_mov_s(_ i: Word) throws {
        fpu[single: i.fd] = fpu[single: i.fs]
    }

    mutating func op_sqrt_s(_ i: Word) throws {
        fpu[single: i.fd] = sqrt(fpu[single: i.fs])
    }

    mutating func op_add_s(_ i: Word) throws {
        fpu[single: i.fd] = fpu[single: i.fs] + fpu[single: i.ft]
    }

    mutating func op_sub_s(_ i: Word) throws {
        fpu[single: i.fd] = fpu[single: i.fs] - fpu[single: i.ft]
    }

    mutating func op_mul_s(_ i: Word) throws {
        fpu[single: i.fd] = fpu[single: i.fs] * fpu[single: i.ft]
    }

    mutating func op_div_s(_ i: Word) throws {
        fpu[single: i.fd] = fpu[single: i.fs] / fpu[single: i.ft]
    }

    mutating func op_ceil_w_s(_ i: Word) throws {
        fpu[fixed: i.fd] = SignedWord(ceil(fpu[single: i.fs]))
    }

    mutating func op_floor_w_s(_ i: Word) throws {
        fpu[fixed: i.fd] = SignedWord(floor(fpu[single: i.fs]))
    }

    mutating func op_round_w_s(_ i: Word) throws {
        fpu[fixed: i.fd] = SignedWord(round(fpu[single: i.fs]))
    }

    mutating func op_trunc_w_s(_ i: Word) throws {
        fpu[fixed: i.fd] = fpu[single: i.fs].asInt32
    }

    // MARK: - Double-precision arithmetic

    mutating func op_abs_d(_ i: Word) throws {
        fpu[double: i.fd] = abs(fpu[double: i.fs])
    }

    mutating func op_neg_d(_ i: Word) throws {
        fpu[double: i.fd] = -fpu[double: i.fs]
    }

    mutating func op_mov_d(_ i: Word) throws {
        fpu[double: i.fd] = fpu[double: i.fs]
    }

    mutating func op_sqrt_d(_ i: Word) throws {
        fpu[double: i.fd] = sqrt(fpu[double: i.fs])
    }

    mutating func op_add_d(_ i: Word) throws {
        fpu[double: i.fd] = fpu[double: i.fs] + fpu[double: i.ft]
    }

    mutating func op_sub_d(_ i: Word) throws {
        fpu[double: i.fd] = fpu[double: i.fs] - fpu[double: i.ft]
    }

    mutating func op_mul_d(_ i: Word) throws {
        fpu[double: i.fd] = fpu[double: i.fs] * fpu[double: i.ft]
    }

    mutating func op_div_d(_ i: Word) throws {
        fpu[double: i.fd] = fpu[double: i.fs] / fpu[double: i.ft]
    }

    mutating func op_ceil_w_d(_ i: Word) throws {
        fpu[fixed: i.fd] = SignedWord(ceil(fpu[double: i.fs]))
    }

    mutating func op_floor_w_d(_ i: Word) throws {
        fpu[fixed: i.fd] = SignedWord(floor(fpu[double: i.fs]))
    }

    mutating func op_round_w_d(_ i: Word) throws {
        fpu[fixed: i.fd] = SignedWord(round(fpu[double: i.fs]))
    }

    mutating func op_trunc_w_d(_ i: Word) throws {
        fpu[fixed: i.fd] = fpu[double: i.fs].asInt32
    }

    // MARK: - Comparisons (result stored in FCSR condition bit)

    mutating func op_c_eq_s(_ i: Word) throws {
        fcsr.condition = fpu[single: i.fs] == fpu[single: i.ft]
    }

    mutating func op_c_lt_s(_ i: Word) throws {
        fcsr.condition = fpu[single: i.fs] < fpu[single: i.ft]
    }

    mutating func op_c_le_s(_ i: Word) throws {
        fcsr.condition = fpu[single: i.fs] <= fpu[single: i.ft]
    }

    // TODO: c.ult.s and c.ule.s should also signal an invalid-operation exception when
    //       operands are unordered (NaN). Currently they behave the same as c.lt.s / c.le.s.
    mutating func op_c_ult_s(_ i: Word) throws {
        fcsr.condition = fpu[single: i.fs] < fpu[single: i.ft]
    }

    mutating func op_c_ule_s(_ i: Word) throws {
        fcsr.condition = fpu[single: i.fs] <= fpu[single: i.ft]
    }

    mutating func op_c_eq_d(_ i: Word) throws {
        fcsr.condition = fpu[double: i.fs] == fpu[double: i.ft]
    }

    mutating func op_c_lt_d(_ i: Word) throws {
        fcsr.condition = fpu[double: i.fs] < fpu[double: i.ft]
    }

    mutating func op_c_le_d(_ i: Word) throws {
        fcsr.condition = fpu[double: i.fs] <= fpu[double: i.ft]
    }

    // TODO: same as above - unordered exception missing for c.ult.d / c.ule.d.
    mutating func op_c_ult_d(_ i: Word) throws {
        fcsr.condition = fpu[double: i.fs] < fpu[double: i.ft]
    }

    mutating func op_c_ule_d(_ i: Word) throws {
        fcsr.condition = fpu[double: i.fs] <= fpu[double: i.ft]
    }

    // MARK: - Format conversions

    mutating func op_cvt_d_s(_ i: Word) throws {
        fpu[double: i.fd] = Double(fpu[single: i.fs])
    }

    mutating func op_cvt_d_w(_ i: Word) throws {
        fpu[double: i.fd] = Double(fpu[fixed: i.fs])
    }

    mutating func op_cvt_s_d(_ i: Word) throws {
        fpu[single: i.fd] = Float(fpu[double: i.fs])
    }

    mutating func op_cvt_s_w(_ i: Word) throws {
        fpu[single: i.fd] = Float(fpu[fixed: i.fs])
    }

    mutating func op_cvt_w_s(_ i: Word) throws {
        fpu[fixed: i.fd] = fpu[single: i.fs].asInt32
    }

    mutating func op_cvt_w_d(_ i: Word) throws {
        fpu[fixed: i.fd] = fpu[double: i.fs].asInt32
    }
}
