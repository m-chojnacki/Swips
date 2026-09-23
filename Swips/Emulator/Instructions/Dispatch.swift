//
//  Dispatch.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    /// Decodes and executes one instruction word.
    /// Main instruction decoder - decodes the opcode fields and calls the appropriate handler.
    @inline(__always)
    mutating func executeInstruction(_ instruction: Word) throws(MIPSException) {
        switch instruction.op {
        // SPECIAL - secondary decode on funct field
        case 0b000000:
            switch instruction.funct {
            case 0b100000: try op_add(instruction)
            case 0b100001: try op_addu(instruction)
            case 0b100100: try op_and(instruction)
            case 0b001101: try op_break(instruction)
            case 0b011010: try op_div(instruction)
            case 0b011011: try op_divu(instruction)
            case 0b001001: try op_jalr(instruction)
            case 0b001000: try op_jr(instruction)
            case 0b010000: try op_mfhi(instruction)
            case 0b010010: try op_mflo(instruction)
            case 0b010001: try op_mthi(instruction)
            case 0b010011: try op_mtlo(instruction)
            case 0b011000: try op_mult(instruction)
            case 0b011001: try op_multu(instruction)
            case 0b100111: try op_nor(instruction)
            case 0b100101: try op_or(instruction)
            case 0b000000: try op_sll(instruction)
            case 0b000100: try op_sllv(instruction)
            case 0b101010: try op_slt(instruction)
            case 0b101011: try op_sltu(instruction)
            case 0b000011: try op_sra(instruction)
            case 0b000111: try op_srav(instruction)
            case 0b000010: try op_srl(instruction)
            case 0b000110: try op_srlv(instruction)
            case 0b100010: try op_sub(instruction)
            case 0b100011: try op_subu(instruction)
            case 0b001111: try op_sync(instruction)
            case 0b001100: try op_syscall(instruction)
            case 0b110100: try op_teq(instruction)
            case 0b110000: try op_tge(instruction)
            case 0b110001: try op_tgeu(instruction)
            case 0b110010: try op_tlt(instruction)
            case 0b110011: try op_tltu(instruction)
            case 0b110110: try op_tne(instruction)
            case 0b100110: try op_xor(instruction)
            default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
            }
        // REGIMM - secondary decode on rt field
        case 0b000001:
            switch instruction.rt {
            case 0b00001: try op_bgez(instruction)
            case 0b00011: try op_bgezl(instruction)
            case 0b10001: try op_bgezal(instruction)
            case 0b10011: try op_bgezall(instruction)
            case 0b00000: try op_bltz(instruction)
            case 0b00010: try op_bltzl(instruction)
            case 0b10000: try op_bltzal(instruction)
            case 0b10010: try op_bltzall(instruction)
            case 0b01100: try op_teqi(instruction)
            case 0b01000: try op_tgei(instruction)
            case 0b01001: try op_tgeiu(instruction)
            case 0b01010: try op_tlti(instruction)
            case 0b01011: try op_tltiu(instruction)
            case 0b01110: try op_tnei(instruction)
            default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
            }
        // COP0 - coprocessor 0
        case 0b010000:
            switch instruction.funct {
            case 0b000000:
                switch instruction.rs {
                case 0b00000: try op_mfc0(instruction)
                case 0b00100: try op_mtc0(instruction)
                default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
                }
            case 0b001000: try op_tlbp(instruction)
            case 0b000001: try op_tlbr(instruction)
            case 0b000010: try op_tlbwi(instruction)
            case 0b000110: try op_tlbwr(instruction)
            case 0b010000: try op_rfe(instruction)
            default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
            }
        // COP1 - FPU
        case 0b010001:
            switch instruction.rs {
            case 0b10000: // fmt = S (single)
                switch instruction.funct {
                case 0b000101: try op_abs_s(instruction)
                case 0b000000: try op_add_s(instruction)
                case 0b110010: try op_c_eq_s(instruction)
                case 0b111100: try op_c_lt_s(instruction)
                case 0b111110: try op_c_le_s(instruction)
                case 0b110101: try op_c_ult_s(instruction)
                case 0b110111: try op_c_ule_s(instruction)
                case 0b100001: try op_cvt_d_s(instruction)
                case 0b100100: try op_cvt_w_s(instruction)
                case 0b000011: try op_div_s(instruction)
                case 0b000110: try op_mov_s(instruction)
                case 0b000010: try op_mul_s(instruction)
                case 0b000111: try op_neg_s(instruction)
                case 0b000001: try op_sub_s(instruction)
                case 0b001110: try op_ceil_w_s(instruction)
                case 0b001111: try op_floor_w_s(instruction)
                case 0b001100: try op_round_w_s(instruction)
                case 0b000100: try op_sqrt_s(instruction)
                case 0b001101: try op_trunc_w_s(instruction)
                default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
                }
            case 0b10001: // fmt = D (double)
                switch instruction.funct {
                case 0b000101: try op_abs_d(instruction)
                case 0b000000: try op_add_d(instruction)
                case 0b110010: try op_c_eq_d(instruction)
                case 0b111100: try op_c_lt_d(instruction)
                case 0b111110: try op_c_le_d(instruction)
                case 0b110101: try op_c_ult_d(instruction)
                case 0b110111: try op_c_ule_d(instruction)
                case 0b100000: try op_cvt_s_d(instruction)
                case 0b100100: try op_cvt_w_d(instruction)
                case 0b000011: try op_div_d(instruction)
                case 0b000110: try op_mov_d(instruction)
                case 0b000010: try op_mul_d(instruction)
                case 0b000111: try op_neg_d(instruction)
                case 0b000001: try op_sub_d(instruction)
                case 0b001110: try op_ceil_w_d(instruction)
                case 0b001111: try op_floor_w_d(instruction)
                case 0b001100: try op_round_w_d(instruction)
                case 0b000100: try op_sqrt_d(instruction)
                case 0b001101: try op_trunc_w_d(instruction)
                default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
                }
            case 0b10100: // fmt = W (fixed)
                switch instruction.funct {
                case 0b100001: try op_cvt_d_w(instruction)
                case 0b100000: try op_cvt_s_w(instruction)
                default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
                }
            case 0b01000: // BC1
                switch instruction.rt {
                case 0b00000: try op_bc1f(instruction)
                case 0b00010: try op_bc1fl(instruction)
                case 0b00001: try op_bc1t(instruction)
                case 0b00011: try op_bc1tl(instruction)
                default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
                }
            case 0b00010: try op_cfc1(instruction)
            case 0b00110: try op_ctc1(instruction)
            case 0b00000: try op_mfc1(instruction)
            case 0b00100: try op_mtc1(instruction)
            default: throw MIPSException(code: .reservedInstruction, badVAddr: pc)
            }
        // I-type and J-type instructions
        case 0b001000: try op_addi(instruction)
        case 0b001001: try op_addiu(instruction)
        case 0b001100: try op_andi(instruction)
        case 0b000100: try op_beq(instruction)
        case 0b010100: try op_beql(instruction)
        case 0b000111: try op_bgtz(instruction)
        case 0b010111: try op_bgtzl(instruction)
        case 0b000110: try op_blez(instruction)
        case 0b010110: try op_blezl(instruction)
        case 0b000101: try op_bne(instruction)
        case 0b010101: try op_bnel(instruction)
        case 0b000010: try op_j(instruction)
        case 0b000011: try op_jal(instruction)
        case 0b100000: try op_lb(instruction)
        case 0b100100: try op_lbu(instruction)
        case 0b100001: try op_lh(instruction)
        case 0b100101: try op_lhu(instruction)
        case 0b001111: try op_lui(instruction)
        case 0b100011: try op_lw(instruction)
        case 0b110000: try op_ll(instruction)
        case 0b110001: try op_lwc1(instruction)
        case 0b110101: try op_ldc1(instruction)
        case 0b100010: try op_lwl(instruction)
        case 0b100110: try op_lwr(instruction)
        case 0b001101: try op_ori(instruction)
        case 0b101000: try op_sb(instruction)
        case 0b101001: try op_sh(instruction)
        case 0b001010: try op_slti(instruction)
        case 0b001011: try op_sltiu(instruction)
        case 0b101011: try op_sw(instruction)
        case 0b111000: try op_sc(instruction)
        case 0b111001: try op_swc1(instruction)
        case 0b111101: try op_sdc1(instruction)
        case 0b101010: try op_swl(instruction)
        case 0b101110: try op_swr(instruction)
        case 0b001110: try op_xori(instruction)
        default:
            throw MIPSException(code: .reservedInstruction, badVAddr: pc)
        }
    }
}
