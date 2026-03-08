//
//  Symbol.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// Debug symbol loader - parses a Linux kernel symbol map (nm output format).

struct Symbol: CustomStringConvertible {
    let address: Word
    let type: String
    let name: String

    var description: String {
        "\(address.hex) \(type) \(name)"
    }
}

/// Loads a symbol map from a file in `nm` format ("address type name" per line).
/// Returns a dictionary keyed by address.
func loadSymbols(from path: String) -> [Word: Symbol] {
    let text = try! String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)

    let pairs: [(Word, Symbol)] = text.split(separator: "\n").map { line in
        let parts = line.split(separator: " ")
        assert(parts.count == 3)

        // Strip the upper 32-bit "ffffffff" prefix that nm emits for kernel symbols.
        let addressString = parts[0].replacingOccurrences(of: "ffffffff", with: "")
        assert(addressString.count == 8)

        let address = Word(addressString, radix: 16)!
        let symbol = Symbol(address: address, type: String(parts[1]), name: String(parts[2]))
        return (address, symbol)
    }

    return Dictionary(pairs, uniquingKeysWith: { $1 })
}
