//
//  TerminalView.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import SwiftTerm
import SwiftUI

#if os(macOS)
    struct TerminalView: NSViewRepresentable {
        let io: TerminalIO

        func makeNSView(context _: Context) -> SwiftTerm.TerminalView {
            let view = io.terminalView
            view.terminalDelegate = view
            view.hideScroller()
            return view
        }

        func updateNSView(_: SwiftTerm.TerminalView, context _: Context) {}
    }
#else
    struct TerminalView: UIViewRepresentable {
        let io: TerminalIO

        func makeUIView(context _: Context) -> SwiftTerm.TerminalView {
            let view = io.terminalView
            view.backgroundColor = .black
            view.terminalDelegate = view
            return view
        }

        func updateUIView(_: SwiftTerm.TerminalView, context _: Context) {}
    }
#endif

// MARK: - Custom terminal view subclass

private final class EmulatorTerminalView: SwiftTerm.TerminalView {
    var inputHandler: (([Byte]) -> Void)?

    #if os(macOS)
        override func layout() {
            super.layout()
            // Feed a null byte on layout to initialise the terminal size.
            feed(byteArray: [0])
        }

        func hideScroller() {
            subviews.lazy
                .compactMap { $0 as? NSScroller }
                .first?
                .isHidden = true
        }
    #endif
}

extension EmulatorTerminalView: TerminalViewDelegate {
    func sizeChanged(source _: SwiftTerm.TerminalView, newCols _: Int, newRows _: Int) {}
    func setTerminalTitle(source _: SwiftTerm.TerminalView, title _: String) {}
    func hostCurrentDirectoryUpdate(source _: SwiftTerm.TerminalView, directory _: String?) {}

    func send(source _: SwiftTerm.TerminalView, data: ArraySlice<UInt8>) {
        inputHandler?(Array(data))
    }

    func scrolled(source _: SwiftTerm.TerminalView, position _: Double) {}
    func requestOpenLink(source _: SwiftTerm.TerminalView, link _: String, params _: [String: String]) {}
    func clipboardCopy(source _: SwiftTerm.TerminalView, content _: Data) {}
    func rangeChanged(source _: SwiftTerm.TerminalView, startY _: Int, endY _: Int) {}
}

// MARK: - TerminalIO

/// Thread-safe bridge between the emulator's UART and the terminal UI.
final class TerminalIO {
    fileprivate let terminalView = EmulatorTerminalView()

    /// Set this to forward host keystrokes into the emulator's UART RX buffer.
    var input: (([Byte]) -> Void)? {
        get { terminalView.inputHandler }
        set { terminalView.inputHandler = newValue }
    }

    /// Call this (from any thread) to display bytes in the terminal.
    func output(_ bytes: [Byte]) {
        terminalView.feed(byteArray: ArraySlice(bytes))
    }
}
