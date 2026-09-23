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
import QuartzCore

final class Emulator {
    private var cpu = EmulatorState()

    var onSpeedUpdate: (@MainActor (Double) -> Void)?

    /// Steps per batch; UI input is delivered between batches, so this bounds input latency (~15 ms).
    private static let batchSize = 2_000_000

    private let inboxLock = NSLock()
    private var inbox: [(inout EmulatorState) -> Void] = []

    /// Devices the UI wires callbacks into. Captured once so the UI never touches `cpu` while it runs.
    let physical: PhysicalBus

    init() {
        physical = cpu.bus.physical
    }

    /// Runs `action` on the emulator thread between batches. Devices aren't thread-safe, so all
    /// input from the UI has to come through here.
    func send(_ action: @escaping (inout EmulatorState) -> Void) {
        inboxLock.withLock { inbox.append(action) }
    }

    func scheduleEmulatorLoop() {
        let thread = Thread { [self] in
            runEmulatorLoop()
        }

        thread.name = Bundle.main.objectName("cpu")
        thread.qualityOfService = .userInitiated
        thread.start()
    }

    /// Boots the kernel and runs forever, reporting throughput about once a second.
    private func runEmulatorLoop() {
        cpu.boot()

        var reportStart = CACurrentMediaTime()
        var reportSteps = 0

        while true {
            for action in inboxLock.withLock({ inbox.popAll() }) {
                action(&cpu)
            }

            cpu.run(steps: Self.batchSize)
            reportSteps += Self.batchSize

            let elapsed = CACurrentMediaTime() - reportStart
            if elapsed >= 1 {
                let speed = Double(reportSteps) / elapsed / 1e6
                Task { await onSpeedUpdate?(speed) }
                reportStart += elapsed
                reportSteps = 0
            }
        }
    }
}

private extension Array {
    mutating func popAll() -> Self {
        defer { removeAll() }
        return self
    }
}
