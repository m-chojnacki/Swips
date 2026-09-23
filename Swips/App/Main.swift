//
//  Main.swift
//  Swips
//
//  SPDX-License-Identifier: MIT
//

import Foundation
import SwiftUI

@main
enum Main {
    static func main() {
        do {
            if let options = try ProfileOptions(arguments: CommandLine.arguments) {
                exit(try Profiler(options: options).run())
            }
        } catch ProfileError.help {
            print(ProfileOptions.usage)
            exit(0)
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            exit(2)
        }

        SwipsApp.main()
    }
}
