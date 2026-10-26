import Foundation

/// Shared lexical admission inspection; not a complete JSON validator.
/// Consumers own size limits, schema classification and domain validation.
enum JSONLexicalInspection {
    /// Foundation readers can select different duplicate values. Track decoded
    /// object keys (including escaped equivalents) before either reader runs.
    static func hasDuplicateObjectKeys(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        var index = 0
        var containers: [Set<String>?] = []
        func whitespace(_ byte: UInt8) -> Bool { [9, 10, 13, 32].contains(byte) }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 34 {
                let start = index
                index += 1
                var escaped = false
                while index < bytes.count {
                    let character = bytes[index]
                    if !escaped && character == 34 { break }
                    if !escaped && character == 92 { escaped = true }
                    else { escaped = false }
                    index += 1
                }
                guard index < bytes.count else { return false }
                let literal = Data(bytes[start...index])
                index += 1
                var cursor = index
                while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < bytes.count, bytes[cursor] == 58,
                      let last = containers.indices.last, containers[last] != nil,
                      let key = try? JSONDecoder().decode(String.self, from: literal) else { continue }
                guard containers[last]?.contains(key) == false else { return true }
                containers[last]?.insert(key)
            } else if byte == 123 { containers.append([]); index += 1 }
            else if byte == 91 { containers.append(nil); index += 1 }
            else if byte == 125 || byte == 93 {
                if !containers.isEmpty { containers.removeLast() }
                index += 1
            } else { index += 1 }
        }
        return false
    }

    /// Inspect all root headers, including escaped spellings, before either
    /// Foundation decoder can choose a conflicting duplicate value. Nested keys
    /// and key-like text inside preference strings are not version declarations.
    static func rootVersionTokens(_ text: String) -> [String] {
        let bytes = Array(text.utf8)
        var index = 0, depth = 0
        var tokens: [String] = []
        func whitespace(_ byte: UInt8) -> Bool { [9, 10, 13, 32].contains(byte) }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 34 {
                let start = index
                index += 1
                var escaped = false
                while index < bytes.count {
                    let character = bytes[index]
                    if !escaped && character == 34 { break }
                    if !escaped && character == 92 { escaped = true }
                    else { escaped = false }
                    index += 1
                }
                guard index < bytes.count else { return tokens }
                let literal = Data(bytes[start...index])
                index += 1
                guard depth == 1,
                      (try? JSONDecoder().decode(String.self, from: literal)) == "schemaVersion" else { continue }
                var cursor = index
                while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < bytes.count, bytes[cursor] == 58 else { continue }
                cursor += 1
                while cursor < bytes.count, whitespace(bytes[cursor]) { cursor += 1 }
                let startOfValue = cursor
                while cursor < bytes.count, !whitespace(bytes[cursor]),
                      ![44, 125, 93].contains(bytes[cursor]) { cursor += 1 }
                tokens.append(String(decoding: bytes[startOfValue..<cursor], as: UTF8.self))
            } else if byte == 123 || byte == 91 { depth += 1; index += 1 }
            else if byte == 125 || byte == 93 { depth -= 1; index += 1 }
            else { index += 1 }
        }
        return tokens
    }
}
