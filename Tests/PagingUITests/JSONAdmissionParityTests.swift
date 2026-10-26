import AppGridUI
import Foundation
import XCTest
@testable import PagingPrototypeApp

/// Literal inputs and independent store outcomes; no encoders or inspection oracle.
final class JSONAdmissionParityTests: XCTestCase {
    private struct Case {
        let name: String
        let bytes: Data
        let library: AppLibraryLoadResult
        let activity: LaunchActivityLoadResult

        init(_ name: String, _ json: String,
             _ library: AppLibraryLoadResult, _ activity: LaunchActivityLoadResult) {
            self.init(name, bytes: Data(json.utf8), library, activity)
        }

        init(_ name: String, bytes: Data,
             _ library: AppLibraryLoadResult, _ activity: LaunchActivityLoadResult) {
            self.name = name
            self.bytes = bytes
            self.library = library
            self.activity = activity
        }
    }

    private func assertCases(_ cases: [Case], file: StaticString = #filePath, line: UInt = #line) {
        for item in cases {
            XCTAssertEqual(AppLibraryFileStore.decode(item.bytes), item.library,
                           "Library: \(item.name)", file: file, line: line)
            XCTAssertEqual(LaunchActivityFileStore.decode(item.bytes), item.activity,
                           "Activity: \(item.name)", file: file, line: line)
        }
    }

    func testDuplicateKeysAtRootAndNestedObjectDepths() {
        assertCases([
            Case("duplicate root header", #"{"schemaVersion":1,"schemaVersion":2}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("escaped equivalent root header", #"{"schemaVersion":1,"schema\u0056ersion":2}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("escaped equivalent root body key", #"{"schemaVersion":1,"document":{},"docum\u0065nt":{}}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("escaped nested preference key", #"{"schemaVersion":1,"preferences":{"enabled":true,"enabl\u0065d":false,"categoryOverrides":{}}}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("escaped nested dictionary key", #"{"schemaVersion":1,"preferences":{"enabled":true,"categoryOverrides":{"bundle:a":"music","bundle:\u0061":"video"}}}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("duplicate inside object within array", #"{"schemaVersion":1,"extra":[{"key":0,"k\u0065y":1}]}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("same key in separate sibling objects", #"{"schemaVersion":1,"extra":[{"key":0},{"key":1}]}"#,
                 .corrupt, .corrupt)
        ])
    }

    func testHeaderLikeStringsAndArraysDoNotSupplyRootHeaders() {
        assertCases([
            Case("escaped quotes and braces inside a string", #"{"note":"{\"schemaVersion\":99,\"schemaVersion\":100}"}"#,
                 .corrupt, .corrupt),
            Case("nested object header only", #"{"extra":{"schemaVersion":99}}"#,
                 .corrupt, .corrupt),
            Case("nested array headers only", #"{"extra":[{"schemaVersion":99},{"schemaVersion":100}]}"#,
                 .corrupt, .corrupt),
            Case("root array of header-like strings", #"["schemaVersion",99,"{\"schemaVersion\":100}"]"#,
                 .corrupt, .corrupt),
            Case("supported root with nested future decoys", #"{"schemaVersion":1,"extra":["{\"schemaVersion\":99}",{"schemaVersion":100}]}"#,
                 .corrupt, .corrupt)
        ])
    }

    func testNumericHeadersRetainFutureAndAmbiguousClassifications() {
        assertCases([
            Case("future integer", #"{"schemaVersion":2}"#, .futureVersion, .futureVersion),
            Case("escaped future exponent header", #"{"schema\u0056ersion":1e3}"#,
                 .futureVersion, .futureVersion),
            Case("integer beyond Int range", #"{"schemaVersion":999999999999999999999999999999999999999999999999999999999}"#,
                 .futureVersion, .futureVersion),
            Case("unrepresentable exponent", #"{"schemaVersion":1e999999}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("decimal spelling of supported version", #"{"schemaVersion":1.0}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("exponent spelling of supported version", #"{"schemaVersion":1e0}"#,
                 .ambiguousSchema, .ambiguousSchema),
            Case("zero version", #"{"schemaVersion":0}"#, .ambiguousSchema, .ambiguousSchema),
            Case("negative version", #"{"schemaVersion":-1}"#, .corrupt, .corrupt)
        ])
    }

    func testInvalidMissingAndMalformedHeadersRetainAdmissionOrder() {
        // Lexical admission precedes complete JSON validation. In particular, a
        // future token remains future even when the following body is truncated.
        assertCases([
            Case("missing header", #"{}"#, .corrupt, .corrupt),
            Case("boolean header", #"{"schemaVersion":true}"#, .corrupt, .corrupt),
            Case("string header", #"{"schemaVersion":"1"}"#, .corrupt, .corrupt),
            Case("null header", #"{"schemaVersion":null}"#, .corrupt, .corrupt),
            Case("array header", #"{"schemaVersion":[1]}"#, .corrupt, .corrupt),
            Case("truncated supported body", #"{"schemaVersion":1,"preferences":"#,
                 .corrupt, .corrupt),
            Case("truncated future body", #"{"schemaVersion":2,"note":"unfinished"#,
                 .futureVersion, .futureVersion),
            Case("non UTF-8 bytes", bytes: Data([0xff, 0xfe]), .ambiguousSchema, .ambiguousSchema),
            Case("incomplete UTF-8 scalar", bytes: Data([0x7b, 0xc3]), .ambiguousSchema, .ambiguousSchema)
        ])
    }

    func testValidFeatureEnvelopesAndDistinctBodyShapes() {
        assertCases([
            Case("Library empty preferences", #"{"schemaVersion":1,"preferences":{"enabled":false,"categoryOverrides":{}}}"#,
                 .loaded(.init(enabled: false, categoryOverrides: [:])), .corrupt),
            Case("Library escaped header and header-like identity", #"{"schema\u0056ersion":1,"preferences":{"enabled":true,"categoryOverrides":{"bundle:{\"schemaVersion\":99}":"music"}}}"#,
                 .loaded(.init(enabled: true, categoryOverrides: [#"bundle:{"schemaVersion":99}"#: .music])), .corrupt),
            Case("Activity empty entries", #"{"schemaVersion":1,"document":{"enabled":false,"salt":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","entries":{}}}"#,
                 .corrupt, .loaded(.init(enabled: false,
                     salt: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", entries: [:]))),
            Case("Activity escaped header and populated entry", #"{"schema\u0056ersion":1,"document":{"enabled":true,"salt":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","entries":{"bundle:schemaVersion":{"lastLaunch":0,"dailyCounts":{"11323":3}}}}}"#,
                 .corrupt, .loaded(.init(enabled: true,
                     salt: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                     entries: ["bundle:schemaVersion": .init(lastLaunch: Date(timeIntervalSinceReferenceDate: 0),
                                                           dailyCounts: [11323: 3])]))),
            Case("Library body cannot be an array", #"{"schemaVersion":1,"preferences":[]}"#,
                 .corrupt, .corrupt),
            Case("Activity entries cannot be an array", #"{"schemaVersion":1,"document":{"enabled":false,"salt":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","entries":[]}}"#,
                 .corrupt, .corrupt),
            Case("combined feature envelope is unsupported", #"{"schemaVersion":1,"preferences":{"enabled":false,"categoryOverrides":{}},"document":{"enabled":false,"salt":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","entries":{}}}"#,
                 .corrupt, .corrupt)
        ])
    }
}
