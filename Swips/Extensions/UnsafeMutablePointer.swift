//
//  UnsafeMutablePointer.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

import Foundation

extension UnsafeMutablePointer where Pointee: FixedWidthInteger {
    /// Zero-filled allocation. Guest-visible state must never start out as heap garbage - it made boots
    /// nondeterministic. Uses calloc, so large blocks (RAM) are zeroed lazily by the OS.
    static func zeroed(count: Int) -> Self {
        calloc(count, MemoryLayout<Pointee>.stride)!.bindMemory(to: Pointee.self, capacity: count)
    }
}
