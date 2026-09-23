//
//  KeyboardScript.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

/// Turns text into a queue of macOS key code press/release events for `PS2Keyboard`.
struct KeyboardScript {
    struct Event {
        let keyCode: Halfword
        let pressed: Bool
    }

    private(set) var events: [Event] = []

    private static let shiftKey: Halfword = 56

    private static let unshifted: [Character: Halfword] = [
        "a": 0, "b": 11, "c": 8, "d": 2, "e": 14, "f": 3, "g": 5, "h": 4, "i": 34, "j": 38, "k": 40, "l": 37,
        "m": 46, "n": 45, "o": 31, "p": 35, "q": 12, "r": 15, "s": 1, "t": 17, "u": 32, "v": 9, "w": 13, "x": 7,
        "y": 16, "z": 6, "0": 29, "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        " ": 49, "\n": 36, "\t": 48, "/": 44, "-": 27, ".": 47, "=": 24, ",": 43, ";": 41, "'": 39, "`": 50,
        "[": 33, "]": 30, "\\": 42,
    ]

    private static let shifted: [Character: Character] = [
        "_": "-", "+": "=", "\"": "'", ":": ";", "<": ",", ">": ".", "?": "/", "|": "\\", "~": "`", "{": "[",
        "}": "]", "!": "1", "@": "2", "#": "3", "$": "4", "%": "5", "^": "6", "&": "7", "*": "8", "(": "9",
        ")": "0",
    ]

    init(typing text: String) throws {
        for character in text {
            if let key = Self.unshifted[character] {
                events += [Event(keyCode: key, pressed: true), Event(keyCode: key, pressed: false)]
            } else if let base = Self.shifted[character] ?? (character.isUppercase ? Character(character.lowercased()) : nil),
                      let key = Self.unshifted[base]
            {
                events += [
                    Event(keyCode: Self.shiftKey, pressed: true),
                    Event(keyCode: key, pressed: true), Event(keyCode: key, pressed: false),
                    Event(keyCode: Self.shiftKey, pressed: false),
                ]
            } else {
                throw ProfileError.usage("can't type \(character.debugDescription)")
            }
        }
    }

    mutating func popFirst() -> Event? {
        events.isEmpty ? nil : events.removeFirst()
    }
}
