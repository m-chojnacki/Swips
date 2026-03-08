//
//  BlockDevice.swift
//  Swips
//
//  Created by Marcin Chojnacki on 22.09.2021.
//  Copyright © 2021 Marcin Chojnacki. All rights reserved.
//
//  SPDX-License-Identifier: MIT
//

import Foundation

// Register map (word-aligned offsets, read and write share addresses):
//   0x00  r   Capacity in 512-byte sectors
//   0x00  w   DMA destination address in RAM
//   0x04  r   Transfer done flag (read clears it)
//   0x04  w   Transfer length in bytes
//   0x08  w   Start sector (high 32 bits of byte offset ÷ 512)
//   0x0C  w   Sector offset within the start sector
//   0x10  w   Command: 0 = read, 1 = write (triggers the transfer)

/// Simple sector-oriented block device backed by a host file (macOS only).
final class BlockDevice: Addressable {
    var size: Word {
        0x14
    }

    // MARK: - State

    private var dmaAddress: Word = 0
    private var txLength: Word = 0
    private var startSector: Word = 0
    private var sectorOffset: Word = 0

    private(set) var transferDone = false

    /// Weak reference to RAM - set by PhysicalBus after init.
    var ram: Addressable!

    // MARK: - Host file (macOS only)

    #if os(macOS)
        private let fileHandle: FileHandle
        private let taskQueue = SerialQueue(name: Bundle.main.objectName("blockdevice"))
        let fileSize: UInt64

        init() {
            fileHandle = FileHandle(forUpdatingAtPath: Bundle.main.runtimePath(of: "debian.img"))!
            fileSize = try! fileHandle.seekToEnd()
            assert(fileSize % 4096 == 0, "Disk image size must be a multiple of 4096 bytes")
        }
    #else
        let fileSize: UInt64 = 4096 * 100

        init() {}
    #endif

    // MARK: - Addressable

    func readByte(from _: Word) -> Byte {
        fatalError("BlockDevice: byte access not supported")
    }

    func writeByte(to _: Word, _: Byte) {
        fatalError("BlockDevice: byte access not supported")
    }

    func readHalfword(from _: Word) -> Halfword {
        fatalError("BlockDevice: halfword access not supported")
    }

    func writeHalfword(to _: Word, _: Halfword) {
        fatalError("BlockDevice: halfword access not supported")
    }

    func readWord(from address: Word) -> Word {
        switch address {
        case 0x00:
            return Word(fileSize >> 9) // capacity in sectors (÷ 512)
        case 0x04:
            if transferDone { transferDone = false; return 1 }
            return 0
        default:
            return 0
        }
    }

    func writeWord(to address: Word, _ value: Word) {
        switch address {
        case 0x00: dmaAddress = value
        case 0x04: txLength = value
        case 0x08: startSector = value
        case 0x0C: sectorOffset = value
        case 0x10:
            let write = value != 0
            let a = dmaAddress; let l = txLength
            let s = startSector; let o = sectorOffset
            #if os(macOS)
                taskQueue.execute { [weak self] in
                    self?.performTransfer(dmaAddress: a, length: l,
                                          startSector: s, sectorOffset: o, write: write)
                }
            #endif
        default: break
        }
    }

    // MARK: - Async I/O

    #if os(macOS)
        private func performTransfer(dmaAddress: Word, length: Word,
                                     startSector: Word, sectorOffset: Word, write: Bool)
        {
            let byteOffset = (UInt64(startSector) << 9) &+ UInt64(sectorOffset)

            if write {
                var data = Data(count: Int(length))
                for i in 0 ..< length {
                    data[Int(i)] = ram.readByte(from: dmaAddress &+ i)
                }
                try! fileHandle.seek(toOffset: byteOffset)
                fileHandle.write(data)
            } else {
                try! fileHandle.seek(toOffset: byteOffset)
                let data = fileHandle.readData(ofLength: Int(length))
                for i in 0 ..< length {
                    ram.writeByte(to: dmaAddress &+ i, data[Int(i)])
                }
            }

            transferDone = true
        }
    #endif
}

// MARK: - Serial task queue

/// A background thread that processes one task at a time.
private final class SerialQueue {
    private let condition = NSCondition()
    private var thread: Thread!
    private var pending: (() -> Void)?

    init(name: String, qos: QualityOfService = .userInitiated) {
        thread = Thread { [condition, weak self] in
            while !Thread.current.isCancelled {
                condition.lock()
                while self?.pending == nil {
                    condition.wait()
                }
                self?.pending?()
                self?.pending = nil
                condition.unlock()
            }
        }
        thread.name = name
        thread.qualityOfService = qos
        thread.start()
    }

    func execute(_ task: @escaping () -> Void) {
        condition.lock()
        pending = task
        condition.signal()
        condition.unlock()
    }
}
