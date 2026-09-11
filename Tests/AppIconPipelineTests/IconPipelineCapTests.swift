// AppIconPipelineTests — 图标尺寸上限（用户指定：最大 256×256）
// 加载后统一缩略：>256 等比缩到 ≤256×256（保持宽高比）；≤256 原样不变；
// 缓存 cost 按缩略后最大 rep 自动计（estimatedCost 无需改）。
// 全部程序生成图像 + fake loader；零文件系统、零真实资源。

import AppKit
import XCTest
@testable import AppIconPipeline

final class IconPipelineCapTests: XCTestCase {
    /// 最大 rep 像素尺寸（测试辅助；与生产 estimatedCost 同口径：多 rep 取面积最大）。
    private func maxRepSize(_ image: NSImage) -> (width: Int, height: Int) {
        var best = (width: 0, height: 0)
        for rep in image.representations {
            let w = max(1, rep.pixelsWide)
            let h = max(1, rep.pixelsHigh)
            if w * h > best.width * best.height {
                best = (width: w, height: h)
            }
        }
        return best
    }

    /// 1024×1024 → 写回/加载结果最大 rep = 256×256（≤ 上限）；
    /// 缓存命中返回同一缩略图（不重载）。
    func testLargeIconCappedTo256() {
        let loader = FakeLoader(image: makeIconImage(pixelWidth: 1024, pixelHeight: 1024))
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let first = expectation(description: "first delivery")
        let delivered = ValueBox<NSImage?>(nil)
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("expected success") }
            delivered.set(image)
            first.fulfill()
        }
        wait(for: [first], timeout: 3)
        let size = maxRepSize(delivered.value!)
        XCTAssertEqual(size.width, 256)
        XCTAssertEqual(size.height, 256)
        XCTAssertLessThanOrEqual(size.width, IconPipeline.maxIconPixelDimension)
        XCTAssertLessThanOrEqual(size.height, IconPipeline.maxIconPixelDimension)

        // 缓存命中：同一缩略图实例，不重载
        let second = expectation(description: "cache hit delivery")
        let hitImage = ValueBox<NSImage?>(nil)
        pipeline.request(key: makeKey(1), generation: 2) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("expected success") }
            hitImage.set(image)
            second.fulfill()
        }
        wait(for: [second], timeout: 3)
        XCTAssertEqual(loader.loadCount, 1, "cache hit must not reload")
        XCTAssertTrue(hitImage.value! === delivered.value!, "cache hit returns the same capped image")

        pipeline.shutdown()
    }

    /// 128×128 → 原样不变：同一 NSImage 实例透传，最大 rep 128×128。
    func testSmallIconUnchanged() {
        let original = makeIconImage(pixelWidth: 128, pixelHeight: 128)
        let loader = FakeLoader(image: original)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e = expectation(description: "delivery")
        let delivered = ValueBox<NSImage?>(nil)
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("expected success") }
            delivered.set(image)
            e.fulfill()
        }
        wait(for: [e], timeout: 3)
        XCTAssertTrue(delivered.value! === original, "≤256 image must pass through unchanged")
        let size = maxRepSize(delivered.value!)
        XCTAssertEqual(size.width, 128)
        XCTAssertEqual(size.height, 128)

        pipeline.shutdown()
    }

    /// 等比缩放：1024×512 → 256×128；512×1024 → 128×256（宽高比保持）。
    func testAspectRatioPreserved() {
        let wide = makeIconImage(pixelWidth: 1024, pixelHeight: 512)
        let loader = FakeLoader(image: wide)
        let pipeline = IconPipeline(loader: loader, limits: .init())

        let e1 = expectation(description: "wide delivery")
        let wideImage = ValueBox<NSImage?>(nil)
        pipeline.request(key: makeKey(1), generation: 1) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("expected success") }
            wideImage.set(image)
            e1.fulfill()
        }
        wait(for: [e1], timeout: 3)
        var size = maxRepSize(wideImage.value!)
        XCTAssertEqual(size.width, 256)
        XCTAssertEqual(size.height, 128)

        let tall = makeIconImage(pixelWidth: 512, pixelHeight: 1024)
        let loader2 = FakeLoader(image: tall)
        let pipeline2 = IconPipeline(loader: loader2, limits: .init())

        let e2 = expectation(description: "tall delivery")
        let tallImage = ValueBox<NSImage?>(nil)
        pipeline2.request(key: makeKey(2), generation: 1) { _, _, result in
            guard case .success(let image) = result else { return XCTFail("expected success") }
            tallImage.set(image)
            e2.fulfill()
        }
        wait(for: [e2], timeout: 3)
        size = maxRepSize(tallImage.value!)
        XCTAssertEqual(size.width, 128)
        XCTAssertEqual(size.height, 256)

        pipeline.shutdown()
        pipeline2.shutdown()
    }

    /// 缓存 cost 按缩略后尺寸计：maxCost=600_000 容得下 2 个 256×256（262144×2=524288）
    /// 但容不下 2 个 1024×1024（4MB×2）→ 0 驱逐 + 双命中（不重载）。
    func testCacheCostReflectsCappedSize() {
        let loader = FakeLoader(image: makeIconImage(pixelWidth: 1024, pixelHeight: 1024))
        let pipeline = IconPipeline(loader: loader,
                                    limits: .init(maxCount: 8, maxCost: 600_000))

        for n in 1...2 {
            let e = expectation(description: "k\(n)")
            pipeline.request(key: makeKey(n), generation: UInt64(n)) { _, _, result in
                guard case .success = result else { return XCTFail("expected success") }
                e.fulfill()
            }
            wait(for: [e], timeout: 3)
        }
        XCTAssertEqual(pipeline.stats.evictions, 0, "two capped 256×256 entries fit in 600_000")

        for n in 1...2 {
            let e = expectation(description: "k\(n) hit")
            pipeline.request(key: makeKey(n), generation: UInt64(n + 10)) { _, _, _ in e.fulfill() }
            wait(for: [e], timeout: 3)
        }
        XCTAssertEqual(loader.loadCount, 2, "both keys still cached")
        XCTAssertEqual(pipeline.stats.cacheHits, 2)

        pipeline.shutdown()
    }

    /// 直接辅助边界：300×200（仅宽超限）→ 256×171（等比，高不超限）。
    func testHelperCapsNonSquareBelowLimit() {
        let image = makeIconImage(pixelWidth: 300, pixelHeight: 200)
        let capped = IconPipeline.cappedImage(image)
        let size = maxRepSize(capped)
        XCTAssertEqual(size.width, 256)
        XCTAssertEqual(size.height, 171)
        XCTAssertLessThanOrEqual(size.width, IconPipeline.maxIconPixelDimension)
        XCTAssertLessThanOrEqual(size.height, IconPipeline.maxIconPixelDimension)
    }
}
