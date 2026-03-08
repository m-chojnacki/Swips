//
//  MouseMonitor.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

#if os(macOS)
    import Cocoa

    /// macOS local mouse event monitor - forwards delta movement and button state to the PS/2 mouse.
    final class MouseMonitor {
        private let handle: Any?

        private init(handle: Any?) {
            self.handle = handle
        }

        deinit {
            if let handle { NSEvent.removeMonitor(handle) }
        }

        /// Installs a local monitor for mouse-move and button events.
        /// `moved` receives (deltaX, deltaY, leftButton, rightButton).
        static func install(
            moved: ((SignedHalfword, SignedHalfword, Bool, Bool) -> Void)?,
        ) -> MouseMonitor {
            let leftEvents: Set<NSEvent.EventType> = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
            let rightEvents: Set<NSEvent.EventType> = [.rightMouseDown, .rightMouseDragged, .rightMouseUp]

            let matchedEvents: NSEvent.EventTypeMask = [
                .mouseMoved,
                .leftMouseDown, .leftMouseDragged, .leftMouseUp,
                .rightMouseDown, .rightMouseDragged, .rightMouseUp,
                .otherMouseDown, .otherMouseDragged, .otherMouseUp,
            ]

            let handle = NSEvent.addLocalMonitorForEvents(matching: matchedEvents) { event in
                let left = leftEvents.contains(event.type)
                let right = rightEvents.contains(event.type)
                moved?(SignedHalfword(event.deltaX), SignedHalfword(-event.deltaY), left, right)
                return event
            }

            return MouseMonitor(handle: handle)
        }
    }
#endif
