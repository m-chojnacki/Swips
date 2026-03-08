//
//  RegisterOps.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

extension EmulatorState {
    mutating func op_lui(_ i: Word) throws {
        registers[i.rt] = i.immediate << 16
    }

    mutating func op_mfhi(_ i: Word) throws {
        registers[i.rd] = registers.hi
    }

    mutating func op_mflo(_ i: Word) throws {
        registers[i.rd] = registers.lo
    }

    mutating func op_mthi(_ i: Word) throws {
        registers.hi = registers[i.rs]
    }

    mutating func op_mtlo(_ i: Word) throws {
        registers.lo = registers[i.rs]
    }
}
