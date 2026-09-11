//
//  BufferedJSONLWriter.swift
//  PagingUI
//
//  Serial JSONL writer shared by opt-in diagnostic recorders.
//

import Foundation

/// Owns all diagnostic-file I/O on one serial queue.
///
/// Recorders hand this type already-complete batches from their main-thread hot
/// callbacks. `enqueue(_:)` only schedules work; directory creation, permission
/// changes, file opening, byte encoding, and writes happen on `queue`.
final class BufferedJSONLWriter {

    typealias Sink = (Data) throws -> Void

    private let fileURL: URL
    private let queue: DispatchQueue
    private let sink: Sink?
    private let queueKey = DispatchSpecificKey<UInt8>()

    // Accessed only on `queue`.
    private var handle: FileHandle?
    private var failureCountStorage = 0

    /// A custom sink is used by deterministic unit tests. Production leaves it
    /// nil and writes to `fileURL` with owner-only permissions.
    init(fileURL: URL, queue: DispatchQueue? = nil, sink: Sink? = nil) {
        self.fileURL = fileURL
        self.queue = queue ?? DispatchQueue(label: "PagingUI.BufferedJSONLWriter", qos: .utility)
        self.sink = sink
        self.queue.setSpecific(key: queueKey, value: 1)
    }

    /// Schedules one already-accepted batch without doing filesystem I/O on the
    /// caller's thread. A serial queue preserves enqueue order.
    func enqueue(_ lines: [String]) {
        guard !lines.isEmpty else { return }
        queue.async { [self, lines] in
            write(lines)
        }
    }

    /// Waits for every batch accepted before this call to finish. On the serial
    /// queue this is a barrier marker, so teardown can safely read the file once
    /// this method returns.
    func flush() {
        guard DispatchQueue.getSpecific(key: queueKey) == nil else { return }
        queue.sync {}
    }

    /// Number of failed batches. This query is intentionally outside recorder
    /// hot callbacks and may wait behind an in-flight writer operation.
    var failureCount: Int {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return failureCountStorage
        }
        return queue.sync { failureCountStorage }
    }

    private func write(_ lines: [String]) {
        do {
            var data = Data()
            for line in lines {
                data.append(contentsOf: line.utf8)
                data.append(0x0A)
            }

            if let sink {
                try sink(data)
            } else {
                let handle = try openFileIfNeeded()
                try handle.write(contentsOf: data)
            }
        } catch {
            failureCountStorage += 1
            closeFile()
        }
    }

    private func openFileIfNeeded() throws -> FileHandle {
        if let handle {
            return handle
        }

        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: fileURL.path) {
            _ = fileManager.createFile(
                atPath: fileURL.path,
                contents: nil,
                attributes: [.posixPermissions: NSNumber(value: 0o600)]
            )
        }
        // Existing diagnostic files are also tightened; failure is handled by
        // the caller as one failed batch rather than crashing the app.
        try fileManager.setAttributes(
            [.posixPermissions: NSNumber(value: 0o600)],
            ofItemAtPath: fileURL.path
        )

        let opened = try FileHandle(forWritingTo: fileURL)
        try opened.seekToEnd()
        handle = opened
        return opened
    }

    private func closeFile() {
        if let handle {
            try? handle.close()
        }
        handle = nil
    }
}
