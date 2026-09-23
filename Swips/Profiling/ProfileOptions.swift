//
//  ProfileOptions.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Command line options for the headless profiling mode:
///
///     Swips.app/Contents/MacOS/Swips --profile [--duration 45] [--instructions 5G]
///         [--json out.json] [--baseline previous.json] [--screenshot fb.png] [--dump-ram ram.bin]
struct ProfileOptions {
    var duration: Double = 45
    var instructionLimit: Int?
    var jsonPath: String?
    var baselinePath: String?
    var screenshotPath: String?
    var ramDumpPath: String?
    var framesDirectory: String?

    /// Typed on the PS/2 keyboard once the boot shell goes idle - hands off to systemd for a realistic workload.
    var typedInput: String? = "exec /sbin/init\n"

    static let usage = """
    usage: Swips --profile [options]
      --duration <seconds>      wall-clock budget (default 45)
      --instructions <count>    stop after this many steps; accepts K/M/G suffixes
      --json <path>             write the report as JSON
      --baseline <path>         compare speed and state fingerprints against an earlier JSON report
      --screenshot <path>       save the final framebuffer as PNG
      --dump-ram <path>         write guest RAM to a file when done
      --frames <dir>            save a framebuffer PNG every 5 seconds
      --type <text>             keys to type once the boot shell is idle, \\n for Return (default "exec /sbin/init\\n")
      --no-type                 don't type anything; the guest idles at the shell prompt
    """

    /// Returns nil unless `--profile` is present, so the app launches normally.
    init?(arguments: [String]) throws {
        guard arguments.contains("--profile") else { return nil }

        var iterator = arguments.dropFirst().makeIterator()
        func value(for flag: String) throws -> String {
            guard let value = iterator.next() else { throw ProfileError.usage("missing value for \(flag)") }
            return value
        }

        while let argument = iterator.next() {
            switch argument {
            case "--profile":
                break
            case "--help", "-h":
                throw ProfileError.help
            case "--duration":
                let text = try value(for: argument)
                guard let seconds = Double(text), seconds > 0 else { throw ProfileError.usage("bad duration \(text)") }
                duration = seconds
            case "--instructions":
                let text = try value(for: argument)
                guard let count = Self.parseCount(text) else { throw ProfileError.usage("bad instruction count \(text)") }
                instructionLimit = count
            case "--json":
                jsonPath = try value(for: argument)
            case "--baseline":
                baselinePath = try value(for: argument)
            case "--screenshot":
                screenshotPath = try value(for: argument)
            case "--dump-ram":
                ramDumpPath = try value(for: argument)
            case "--frames":
                framesDirectory = try value(for: argument)
            case "--type":
                typedInput = try value(for: argument).replacingOccurrences(of: "\\n", with: "\n")
            case "--no-type":
                typedInput = nil
            case let other where other.hasPrefix("-NS") || other.hasPrefix("-Apple"):
                // Xcode injects user-default overrides such as -NSDocumentRevisionsDebugMode YES.
                _ = iterator.next()
            default:
                throw ProfileError.usage("unknown option \(argument)")
            }
        }
    }

    private static func parseCount(_ text: String) -> Int? {
        let multipliers: [Character: Double] = ["K": 1e3, "M": 1e6, "G": 1e9]
        var digits = Substring(text.uppercased())
        var multiplier = 1.0
        if let last = digits.last, let m = multipliers[last] {
            multiplier = m
            digits = digits.dropLast()
        }
        guard let number = Double(digits), number > 0 else { return nil }
        return Int(number * multiplier)
    }
}

enum ProfileError: Error, CustomStringConvertible {
    case usage(String)
    case help

    var description: String {
        switch self {
        case let .usage(message): "\(message)\n\(ProfileOptions.usage)"
        case .help: ProfileOptions.usage
        }
    }
}
