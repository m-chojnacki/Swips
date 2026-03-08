//
//  Bundle.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

extension Bundle {
    func objectName(_ name: String) -> String {
        if let bundleIdentifier {
            "\(bundleIdentifier).\(name)"
        } else {
            name
        }
    }

    /// Returns the path to a bundled file named `file`.
    func runtimePath(of file: String) -> String {
        #if os(macOS)
            bundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("runtime")
                .appendingPathComponent(file)
                .path
        #else
            path(forResource: file, ofType: nil)!
        #endif
    }
}
