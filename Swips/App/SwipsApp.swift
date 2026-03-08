//
//  SwipsApp.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import SwiftUI

@main
struct SwipsApp: App {
    var body: some Scene {
        #if os(macOS)
            Window("Swips", id: "emulator") {
                EmulatorView()
            }
        #else
            WindowGroup {
                NavigationStack {
                    EmulatorView()
                }
            }
        #endif
    }
}
