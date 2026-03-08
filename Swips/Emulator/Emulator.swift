//
//  Emulator.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

final class Emulator {
    private(set) var cpu = EmulatorState()

    var onSpeedUpdate: (@MainActor (Double) -> Void)?

    init() {
        configureInterrupts()
    }

    private func configureInterrupts() {
        cpu.bus.physical.uart0.interrupt = { [weak self] pending in
            self?.cpu.bus.cp0.setInterrupt(bit: 4, pending: pending)
        }

        cpu.bus.physical.uart1.interrupt = { [weak self] pending in
            self?.cpu.bus.cp0.setInterrupt(bit: 5, pending: pending)
        }

        cpu.bus.physical.ps2Keyboard.interrupt = { [weak self] pending in
            self?.cpu.bus.cp0.setInterrupt(bit: 3, pending: pending)
        }

        cpu.bus.physical.ps2Mouse.interrupt = { [weak self] pending in
            self?.cpu.bus.cp0.setInterrupt(bit: 2, pending: pending)
        }
    }

    func scheduleEmulatorLoop() {
        let thread = Thread { [self] in
            runEmulatorLoop(&cpu) { [weak self] speed in
                Task {
                    await self?.onSpeedUpdate?(speed)
                }
            }
        }

        thread.name = Bundle.main.objectName("cpu")
        thread.qualityOfService = .userInitiated
        thread.start()
    }
}
