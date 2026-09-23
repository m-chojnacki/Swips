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
    var ram: RAM!

    // MARK: - Host file (macOS only)

    #if os(macOS)
        private var fileHandle: FileHandle
        private let taskQueue = SerialQueue(name: Bundle.main.objectName("blockdevice"))
        let fileSize: UInt64

        /// Copy-on-write pages layered over a read-only image; nil when writing through to the image.
        private var overlay: [UInt64: [Byte]]?
        private static let overlayPageSize: UInt64 = 4096

        /// Complete transfers on the CPU thread, so a run is deterministic for a given instruction stream.
        private var synchronous = false

        init() {
            fileHandle = FileHandle(forUpdatingAtPath: Bundle.main.runtimePath(of: "debian.img"))!
            fileSize = try! fileHandle.seekToEnd()
            assert(fileSize % 4096 == 0, "Disk image size must be a multiple of 4096 bytes")
        }

        /// Stops all writes from reaching the host image and makes I/O synchronous.
        /// Used by the profiler so repeated runs start from identical disk state and never dirty the image.
        func enableSnapshotMode() {
            fileHandle = FileHandle(forReadingAtPath: Bundle.main.runtimePath(of: "debian.img"))!
            overlay = [:]
            synchronous = true
        }
    #else
        let fileSize: UInt64 = 4096 * 100

        init() {}

        func enableSnapshotMode() {}
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
                if synchronous {
                    performTransfer(dmaAddress: a, length: l, startSector: s, sectorOffset: o, write: write)
                } else {
                    taskQueue.execute { [weak self] in
                        self?.performTransfer(dmaAddress: a, length: l,
                                              startSector: s, sectorOffset: o, write: write)
                    }
                }
            #endif
        default: break
        }
    }

    // MARK: - Transfers

    #if os(macOS)
        private func performTransfer(dmaAddress: Word, length: Word,
                                     startSector: Word, sectorOffset: Word, write: Bool)
        {
            let byteOffset = (UInt64(startSector) << 9) &+ UInt64(sectorOffset)
            var buffer = [Byte](repeating: 0, count: Int(length))

            if write {
                buffer.withUnsafeMutableBytes { ram.copyOut($0, from: dmaAddress) }
                if overlay != nil {
                    writeOverlay(buffer, at: byteOffset)
                } else {
                    try! fileHandle.seek(toOffset: byteOffset)
                    fileHandle.write(Data(buffer))
                }
            } else {
                if overlay != nil {
                    readOverlay(into: &buffer, at: byteOffset)
                } else {
                    try! fileHandle.seek(toOffset: byteOffset)
                    let data = fileHandle.readData(ofLength: Int(length))
                    buffer.replaceSubrange(0 ..< data.count, with: data)
                }
                buffer.withUnsafeBytes { ram.copyIn($0, at: dmaAddress) }
            }

            transferDone = true
        }

        private func readImagePage(_ page: UInt64) -> [Byte] {
            try! fileHandle.seek(toOffset: page * Self.overlayPageSize)
            var bytes = [Byte](fileHandle.readData(ofLength: Int(Self.overlayPageSize)))
            bytes += [Byte](repeating: 0, count: Int(Self.overlayPageSize) - bytes.count)
            return bytes
        }

        private func readOverlay(into buffer: inout [Byte], at byteOffset: UInt64) {
            var done = 0
            while done < buffer.count {
                let position = byteOffset + UInt64(done)
                let page = position / Self.overlayPageSize
                let inPage = Int(position % Self.overlayPageSize)
                let n = min(buffer.count - done, Int(Self.overlayPageSize) - inPage)
                let source = overlay![page] ?? readImagePage(page)
                buffer.replaceSubrange(done ..< done + n, with: source[inPage ..< inPage + n])
                done += n
            }
        }

        private func writeOverlay(_ buffer: [Byte], at byteOffset: UInt64) {
            var done = 0
            while done < buffer.count {
                let position = byteOffset + UInt64(done)
                let page = position / Self.overlayPageSize
                let inPage = Int(position % Self.overlayPageSize)
                let n = min(buffer.count - done, Int(Self.overlayPageSize) - inPage)
                var target = overlay![page] ?? readImagePage(page)
                target.replaceSubrange(inPage ..< inPage + n, with: buffer[done ..< done + n])
                overlay![page] = target
                done += n
            }
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
