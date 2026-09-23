//
//  RegisterFile.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

/// MIPS general-purpose register file, plus HI/LO multiply-divide registers.
struct RegisterFile {
    /// HI register (multiply / divide result upper half).
    var hi: Word = 0

    /// LO register (multiply / divide result lower half).
    var lo: Word = 0

    private var storage = UnsafeMutablePointer<Word>.zeroed(count: 32)

    subscript(_ index: Word) -> Word {
        get {
            storage[Int(index)]
        }
        set {
            // Always write unconditionally (avoids a branch on every register write),
            // then reset $zero. The unconditional store to storage[0] is cheaper than
            // a branch that is almost-always-taken but still must be predicted.
            storage[Int(index)] = newValue
            storage[0] = 0
        }
    }
}
