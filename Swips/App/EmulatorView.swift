//
//  EmulatorView.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import SwiftUI

struct EmulatorView: View {
    @ObservedObject private var viewModel = EmulatorViewModel()

    @State private var selectedTab = EmulatorTab.uart0
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?

    var body: some View {
        tabContent
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 480)
        #else
        .ignoresSafeArea()
        #endif
        .overlay(
            Text(viewModel.mipsSpeed)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
                .padding(),
            alignment: .bottomTrailing,
        )
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("", selection: $selectedTab) {
                    ForEach(EmulatorTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        #if os(macOS)
        .presentedWindowToolbarStyle(UnifiedCompactWindowToolbarStyle())
        #endif
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .uart0:
            TerminalView(io: viewModel.uart0IO)

        case .uart1:
            TerminalView(io: viewModel.uart1IO)

        case .framebuffer:
            #if os(macOS)
                FramebufferView(pixels: viewModel.pixelBuffer)
                    .onAppear {
                        keyMonitor = KeyMonitor.install(
                            pressed: viewModel.onKeyboardPressed,
                            released: viewModel.onKeyboardReleased,
                        )
                        mouseMonitor = MouseMonitor.install(
                            moved: viewModel.onMouseMoved,
                        )
                    }
                    .onDisappear {
                        keyMonitor = nil
                        mouseMonitor = nil
                    }
            #else
                FramebufferView(pixels: viewModel.pixelBuffer)
            #endif
        }
    }
}

// MARK: - Tab definition

enum EmulatorTab: Int, Identifiable, CaseIterable {
    case uart0
    case uart1
    case framebuffer

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .uart0: "UART 0"
        case .uart1: "UART 1"
        case .framebuffer: "Framebuffer"
        }
    }
}
