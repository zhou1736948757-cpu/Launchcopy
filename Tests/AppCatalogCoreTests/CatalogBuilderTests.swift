//
//  CatalogBuilderTests.swift
//  AppCatalogCoreTests
//
//  §10.2：排序去重——locale/caseInsensitive/tieBreaker；rootPriorityFirst 去重；keepMultiInstance；
//  相同 canonical URL；重复 bundle ID；无 bundle ID fallback；相同 display name；稳定排序重复执行；
//  validate（无重复 canonical URL / 有序）。
//

import XCTest
import AppCatalogCore

final class CatalogBuilderTests: XCTestCase {

    // MARK: - canonical URL 去重（规则 1：同一 canonical URL = 同一对象）

    func testDedupeSameCanonicalURL() throws {
        let low = TestSupport.makeRecord("com.example.app", displayName: "Old", url: "/Applications/X.app", root: 1)
        let high = TestSupport.makeRecord("com.example.app", displayName: "New", url: "/Applications/X.app", root: 0)
        let snapshot = try TestSupport.snapshot([low, high])
        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(snapshot.records[0].displayName, "New")   // 高优先级 root（0）胜出
    }

    func testDedupeSameCanonicalURLIndependentOfInputOrder() throws {
        let a = TestSupport.makeRecord("com.example.app", displayName: "A", url: "/Applications/X.app", root: 1)
        let b = TestSupport.makeRecord("com.example.app", displayName: "B", url: "/Applications/X.app", root: 1)
        let s1 = try TestSupport.snapshot([a, b])
        let s2 = try TestSupport.snapshot([b, a])
        XCTAssertEqual(s1.records, s2.records)   // 同键胜者由 displayName 决定，与输入顺序无关
    }

    // MARK: - bundleID 去重（规则 3）

    func testRootPriorityFirstDedupesDuplicateBundleID() throws {
        let system = TestSupport.makeRecord("com.example.app", displayName: "X", url: "/Applications/X.app", root: 0)
        let user = TestSupport.makeRecord("com.example.app", displayName: "X", url: "/Users/mac/Applications/X.app", root: 1)
        let snapshot = try TestSupport.snapshot([user, system])   // 输入顺序故意颠倒
        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(snapshot.records[0].canonicalURL.path, "/Applications/X.app")
        XCTAssertEqual(snapshot.records[0].sourceRootPriority, 0)
    }

    func testRootPriorityFirstTieBreakerCanonicalPathAscending() throws {
        let z = TestSupport.makeRecord("com.example.app", displayName: "X", url: "/z/X.app", root: 0)
        let a = TestSupport.makeRecord("com.example.app", displayName: "X", url: "/a/X.app", root: 0)
        let snapshot = try TestSupport.snapshot([z, a])
        XCTAssertEqual(snapshot.records.count, 1)
        XCTAssertEqual(snapshot.records[0].canonicalURL.path, "/a/X.app")   // canonical path 字典序
    }

    func testKeepMultiInstanceRetainsBoth() throws {
        let system = TestSupport.makeRecord("com.example.app", displayName: "X", url: "/Applications/X.app", root: 0)
        let user = TestSupport.makeRecord("com.example.app", displayName: "X", url: "/Users/mac/Applications/X.app", root: 1)
        let policy = CatalogPolicy(duplicateResolution: .keepMultiInstance)
        let snapshot = try TestSupport.snapshot([system, user], policy: policy)
        XCTAssertEqual(snapshot.records.count, 2)
        // 稳定多实例：AppID 相同（同一 bundleID），canonicalURL 区分
        XCTAssertEqual(snapshot.records[0].id, snapshot.records[1].id)
        XCTAssertNotEqual(snapshot.records[0].canonicalURL, snapshot.records[1].canonicalURL)
    }

    func testNilBundleIDRecordsNeverCollide() throws {
        let a = TestSupport.makeRecord(nil, displayName: "Notes", url: "/Applications/Notes.app")
        let b = TestSupport.makeRecord(nil, displayName: "Notes", url: "/System/Applications/Notes.app")
        let snapshot = try TestSupport.snapshot([a, b])
        XCTAssertEqual(snapshot.records.count, 2)   // 身份 = canonical URL，互不冲突
    }

    // MARK: - 排序（locale / caseInsensitive / tieBreaker）

    func testSortCaseInsensitiveByDisplayName() throws {
        let banana = TestSupport.makeRecord("com.example.b", displayName: "Banana", url: "/Applications/Banana.app")
        let apple = TestSupport.makeRecord("com.example.a", displayName: "apple", url: "/Applications/apple.app")
        // 注：en_US_POSIX（C-locale）不折叠大小写，caseInsensitive 需用常规 locale（如 en_US）
        let policy = CatalogPolicy(ordering: CatalogOrdering(locale: Locale(identifier: "en_US")))
        let snapshot = try TestSupport.snapshot([banana, apple], policy: policy)
        XCTAssertEqual(snapshot.records.map(\.displayName), ["apple", "Banana"])
    }

    func testSortCaseSensitiveKeepsByteOrder() throws {
        let lower = TestSupport.makeRecord("com.example.l", displayName: "alpha", url: "/Applications/alpha.app")
        let upper = TestSupport.makeRecord("com.example.u", displayName: "Alpha", url: "/Applications/Alpha.app")
        // 无 caseInsensitive：大小写敏感比较（en_US_POSIX 字面序 'A'(0x41) < 'a'(0x61)）
        let policy = CatalogPolicy(ordering: CatalogOrdering(locale: Locale(identifier: "en_US_POSIX"), caseInsensitive: false))
        let snapshot = try TestSupport.snapshot([lower, upper], policy: policy)
        XCTAssertEqual(snapshot.records.map(\.displayName), ["Alpha", "alpha"])
    }

    func testSortLocaleInjectionAffectsOrder() throws {
        let zed = TestSupport.makeRecord("com.example.z", displayName: "z", url: "/Applications/z.app")
        let umlaut = TestSupport.makeRecord("com.example.ae", displayName: "ä", url: "/Applications/ae.app")
        // de_DE 字典序：ä ≈ a 家族 → 在 z 之前
        let de = CatalogPolicy(ordering: CatalogOrdering(locale: Locale(identifier: "de_DE")))
        let snapDE = try TestSupport.snapshot([zed, umlaut], policy: de)
        XCTAssertEqual(snapDE.records.map(\.displayName), ["ä", "z"])
        // sv_SE 瑞典语序：å/ä/ö 排在 z 之后 → z 在前
        let sv = CatalogPolicy(ordering: CatalogOrdering(locale: Locale(identifier: "sv_SE")))
        let snapSV = try TestSupport.snapshot([zed, umlaut], policy: sv)
        XCTAssertEqual(snapSV.records.map(\.displayName), ["z", "ä"])
    }

    func testSortTieBreakerCanonicalURLAscending() throws {
        let z = TestSupport.makeRecord("com.example.n1", displayName: "Notes", url: "/z/Notes.app")
        let a = TestSupport.makeRecord("com.example.n2", displayName: "Notes", url: "/a/Notes.app")
        let snapshot = try TestSupport.snapshot([z, a])
        XCTAssertEqual(snapshot.records.map { $0.canonicalURL.path }, ["/a/Notes.app", "/z/Notes.app"])
    }

    func testSameDisplayNameDifferentAppsBothKept() throws {
        let one = TestSupport.makeRecord("com.example.one", displayName: "Notes", url: "/Applications/Notes.app")
        let two = TestSupport.makeRecord("com.example.two", displayName: "Notes", url: "/Applications/Notes2.app")
        let snapshot = try TestSupport.snapshot([two, one])
        XCTAssertEqual(snapshot.records.count, 2)   // displayName 不参与身份 → 不去重
    }

    // MARK: - 确定性

    func testStableSortRepeatedExecution() throws {
        let records = [
            TestSupport.makeRecord("com.example.c", displayName: "Charlie", url: "/Applications/Charlie.app", root: 1),
            TestSupport.makeRecord("com.example.a", displayName: "alpha", url: "/Applications/alpha.app"),
            TestSupport.makeRecord("com.example.b", displayName: "Bravo", url: "/System/Applications/Bravo.app"),
        ]
        let s1 = try TestSupport.snapshot(records)
        let s2 = try TestSupport.snapshot(records)
        XCTAssertEqual(s1.records, s2.records)
    }

    func testBuildOutputIndependentOfInputOrder() throws {
        let records = [
            TestSupport.makeRecord("com.example.c", displayName: "Charlie", url: "/Applications/Charlie.app", root: 1),
            TestSupport.makeRecord("com.example.a", displayName: "alpha", url: "/Applications/alpha.app"),
            TestSupport.makeRecord("com.example.b", displayName: "Bravo", url: "/System/Applications/Bravo.app"),
        ]
        let s1 = try TestSupport.snapshot(records)
        let s2 = try TestSupport.snapshot(records.reversed())
        XCTAssertEqual(s1.records, s2.records)
    }

    func testEmptyBuildProducesEmptySnapshot() throws {
        let snapshot = try TestSupport.snapshot([])
        XCTAssertEqual(snapshot.records.count, 0)
        XCTAssertEqual(snapshot.revision, CatalogRevision(1))
    }

    // MARK: - validate（无重复 canonical URL / 有序）

    func testValidateAcceptsDefaultBuiltSnapshot() throws {
        let records = [
            TestSupport.makeRecord("com.example.b", displayName: "Bravo", url: "/Applications/Bravo.app"),
            TestSupport.makeRecord("com.example.a", displayName: "alpha", url: "/Applications/alpha.app"),
        ]
        let snapshot = try TestSupport.snapshot(records)
        XCTAssertNoThrow(try CatalogBuilder.validate(snapshot))
    }

    func testValidateAcceptsEmptyAndSingle() throws {
        XCTAssertNoThrow(try CatalogBuilder.validate(CatalogSnapshot(revision: .zero, records: [])))
        let single = try TestSupport.snapshot([TestSupport.makeRecord("com.example.a", displayName: "A", url: "/Applications/A.app")])
        XCTAssertNoThrow(try CatalogBuilder.validate(single))
    }

    func testValidateRejectsDuplicateCanonicalURL() {
        let r = TestSupport.makeRecord("com.example.a", displayName: "A", url: "/Applications/A.app")
        let snapshot = CatalogSnapshot(revision: .zero, records: [r, r])
        XCTAssertThrowsError(try CatalogBuilder.validate(snapshot)) { error in
            XCTAssertEqual(error as? CatalogValidationError, .duplicateCanonicalURL(r.canonicalURL))
        }
    }

    func testValidateRejectsUnsorted() {
        let a = TestSupport.makeRecord("com.example.a", displayName: "alpha", url: "/Applications/alpha.app")
        let b = TestSupport.makeRecord("com.example.b", displayName: "Bravo", url: "/Applications/Bravo.app")
        // 默认排序（caseInsensitive）：alpha 在 Bravo 之前；逆序 → notSorted
        let snapshot = CatalogSnapshot(revision: .zero, records: [b, a])
        XCTAssertThrowsError(try CatalogBuilder.validate(snapshot)) { error in
            XCTAssertEqual(error as? CatalogValidationError, .notSorted)
        }
    }

    func testValidateRejectsUnsortedTieBreaker() {
        let z = TestSupport.makeRecord("com.example.z", displayName: "Notes", url: "/z/Notes.app")
        let a = TestSupport.makeRecord("com.example.a", displayName: "Notes", url: "/a/Notes.app")
        // 同 displayName：URL 必须升序；z 在前 → notSorted
        let snapshot = CatalogSnapshot(revision: .zero, records: [z, a])
        XCTAssertThrowsError(try CatalogBuilder.validate(snapshot)) { error in
            XCTAssertEqual(error as? CatalogValidationError, .notSorted)
        }
    }
}
