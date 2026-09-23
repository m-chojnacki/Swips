//
//  CP0Clock.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

/// The CP0 registers that change on every step - Random and Count - derived on demand from a tick counter
/// instead of being updated every step. The run loop only has to bump `ticks` and compare it against
/// `nextTimerTick`, the precomputed tick at which Count reaches Compare.
struct CP0Clock {
    /// Steps executed so far; each step ticks once before its instruction runs.
    var ticks: UInt64 = 0

    private(set) var nextTimerTick: UInt64 = 0

    private var randomAnchor: Word = 63
    private var randomAnchorTick: UInt64 = 0

    private var countAnchor: Word = 0
    private var countAnchorTick: UInt64 = 0

    init(compare: Word) {
        rescheduleTimer(compare: compare)
    }

    // MARK: - Random

    /// Random decrements every tick and wraps from 7 back to 63, keeping TLB entries 0–7 wired.
    var random: Word {
        let elapsed = ticks &- randomAnchorTick
        var untilWrap = UInt64(randomAnchor &- 7)
        if untilWrap == 0 { untilWrap = 1 << 32 }
        if elapsed < untilWrap {
            return randomAnchor &- Word(truncatingIfNeeded: elapsed)
        }
        return 63 - Word((elapsed - untilWrap) % 56)
    }

    mutating func setRandom(_ value: Word) {
        randomAnchor = value
        randomAnchorTick = ticks
    }

    // MARK: - Count / Compare

    /// Count advances on every 11th tick.
    var count: Word {
        countAnchor &+ Word(truncatingIfNeeded: ticks / 11 &- countAnchorTick / 11)
    }

    mutating func setCount(_ value: Word, compare: Word) {
        countAnchor = value
        countAnchorTick = ticks
        rescheduleTimer(compare: compare)
    }

    /// The timer fires when an increment makes Count equal Compare, so an equal pair waits for a full wrap.
    mutating func rescheduleTimer(compare: Word) {
        var increments = UInt64(compare &- count)
        if increments == 0 { increments = 1 << 32 }
        nextTimerTick = (ticks / 11 + increments) * 11
    }

    mutating func timerFired() {
        nextTimerTick += 11 << 32
    }
}
