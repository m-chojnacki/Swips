//
//  KeyMonitor.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

#if os(macOS)
    import Cocoa

    /// macOS global key event monitor that translates NSEvent key codes to PS/2 scancodes.
    final class KeyMonitor {
        typealias KeyCode = UInt16

        private let handle: Any?

        private init(handle: Any?) {
            self.handle = handle
        }

        deinit {
            if let handle { NSEvent.removeMonitor(handle) }
        }

        /// Installs a local event monitor for key-down, key-up, and modifier-key events.
        /// Returns the monitor object; keep it alive for as long as monitoring is needed.
        static func install(
            pressed: ((KeyCode) -> Void)?,
            released: ((KeyCode) -> Void)?,
        ) -> KeyMonitor {
            let handle = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
                switch event.type {
                case .keyDown:
                    pressed?(event.keyCode)

                case .keyUp:
                    released?(event.keyCode)

                case .flagsChanged:
                    /// Modifier keys don't have separate down/up events - infer state from flags.
                    func handle(for flag: NSEvent.ModifierFlags) {
                        if event.modifierFlags.contains(flag) { pressed?(event.keyCode) }
                        else { released?(event.keyCode) }
                    }

                    switch event.keyCode {
                    case 56, 60: handle(for: .shift)
                    case 59: handle(for: .control)
                    case 54, 55: handle(for: .command)
                    case 58, 61: handle(for: .option)
                    case 63: handle(for: .function)
                    case 57: handle(for: .capsLock)
                    default: break
                    }

                default: break
                }

                return nil // consume the event (don't pass it to the focused view)
            }

            return KeyMonitor(handle: handle)
        }
    }
#endif
