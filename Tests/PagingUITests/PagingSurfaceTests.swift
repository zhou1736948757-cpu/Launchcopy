//
//  PagingSurfaceTests.swift
//  PagingUITests
//
//  §7.3 UI 正确性：页面 frame 与 page width 一致、resize 重新对齐、
//  当前页可访问性描述更新、页面不重叠错误层级、pageCount 变化页码合法、
//  teardown 后无活跃动画驱动器；§3.I 页面内容正确性。
//

import AppKit
import XCTest
@testable import PagingCore
@testable import PagingUI

final class PagingSurfaceTests: XCTestCase {

    // MARK: - 页面 frame 与 page width 一致

    func testPageFramesMatchPageWidth() {
        let surface = makeSurface(pageCount: 5)
        XCTAssertEqual(surface.core.pageWidth, 1000, accuracy: 1e-9)

        // 半径 3：center 0 → 范围 [0,3]（page 4 不在预算内，不 live）。
        for index in 0..<4 {
            let host = surface.hostForPage(index)
            XCTAssertNotNil(host, "page \(index) should be live")
            XCTAssertEqual(host?.frame.width ?? 0, 1000, accuracy: 0.001)
            XCTAssertEqual(host?.frame.minX ?? -1, CGFloat(index) * 1000, accuracy: 0.001)
        }
        XCTAssertNil(surface.hostForPage(4), "page 4 超出半径预算")
        // 容器随 visualOffset 平移：page 0 左缘在屏幕 x=0。
        XCTAssertEqual(surface.pageContainer.frame.minX, 0, accuracy: 0.001)
        XCTAssertEqual(surface.pageContainer.frame.width, 4 * 1000, accuracy: 0.001)
    }

    // MARK: - resize 后重新对齐

    func testResizeRealignsAllPages() {
        let surface = makeSurface(pageCount: 5)
        surface.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        let layoutsBefore = surface.layoutPerformedCount
        surface.layout()

        XCTAssertEqual(surface.core.pageWidth, 800, accuracy: 1e-9)
        XCTAssertEqual(surface.layoutPerformedCount, layoutsBefore + 1, "resize 事件驱动单次布局")
        for index in 0..<4 {
            let host = surface.hostForPage(index)
            XCTAssertEqual(host?.frame.width ?? 0, 800, accuracy: 0.001)
            XCTAssertEqual(host?.frame.minX ?? -1, CGFloat(index) * 800, accuracy: 0.001)
        }
        XCTAssertEqual(surface.pageContainer.frame.width, 4 * 800, accuracy: 0.001)
        XCTAssertEqual(surface.pageContainer.frame.minX, -surface.core.visualOffset * 800, accuracy: 0.001)
    }

    func testResizeSameWidthDoesNotRelayout() {
        let surface = makeSurface(pageCount: 5)
        let layoutsBefore = surface.layoutPerformedCount
        surface.frame = NSRect(x: 10, y: 10, width: 1000, height: 700) // 宽度不变
        surface.layout()
        XCTAssertEqual(surface.layoutPerformedCount, layoutsBefore, "宽度未变不触发布局风暴")
    }

    // MARK: - 高度 resize 边缘（Reviewer E M-4：仅高度变化时 live host 必须重新对齐）

    func testHeightOnlyResizeReframesHosts() {
        let surface = makeSurface(pageCount: 5)
        // 初始 1000×700：host 高度应随 bounds 高度。
        XCTAssertEqual(surface.hostForPage(0)?.frame.height ?? -1, 700, accuracy: 0.001)
        XCTAssertEqual(surface.hostForPage(0)?.frame.width ?? -1, 1000, accuracy: 0.001)

        let layoutsBefore = surface.layoutPerformedCount
        let pageWidthBefore = surface.core.pageWidth
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 800) // 仅高度变化
        surface.layout()

        XCTAssertEqual(surface.layoutPerformedCount, layoutsBefore + 1, "高度变化 = 事件驱动单次布局")
        XCTAssertEqual(surface.core.pageWidth, pageWidthBefore, "宽度未变：Core 不 rebase（D6 语义不变）")
        for index in 0..<4 {
            let host = surface.hostForPage(index)
            XCTAssertEqual(host?.frame.height ?? -1, 800, accuracy: 0.001, "host \(index) 高度已刷新")
            XCTAssertEqual(host?.frame.width ?? -1, 1000, accuracy: 0.001)
            XCTAssertEqual(host?.frame.minX ?? -1, CGFloat(index) * 1000, accuracy: 0.001, "host \(index) x 不变")
        }
        XCTAssertEqual(surface.pageContainer.frame.height, 800, accuracy: 0.001)
    }

    func testWidthAndHeightSimultaneousResize() {
        let surface = makeSurface(pageCount: 5)
        surface.frame = NSRect(x: 0, y: 0, width: 800, height: 600) // 宽高同时变化
        surface.layout()

        XCTAssertEqual(surface.core.pageWidth, 800, accuracy: 1e-9)
        for index in 0..<4 {
            let host = surface.hostForPage(index)
            XCTAssertEqual(host?.frame.width ?? -1, 800, accuracy: 0.001)
            XCTAssertEqual(host?.frame.height ?? -1, 600, accuracy: 0.001)
            XCTAssertEqual(host?.frame.minX ?? -1, CGFloat(index) * 800, accuracy: 0.001)
        }
        XCTAssertEqual(surface.pageContainer.frame.width, 4 * 800, accuracy: 0.001)
        XCTAssertEqual(surface.pageContainer.frame.height, 600, accuracy: 0.001)
    }

    func testRepeatedHeightResizeNoLayoutStorm() {
        let surface = makeSurface(pageCount: 5)
        let layoutsBefore = surface.layoutPerformedCount

        // 3 次不同高度：每次恰好一次布局（事件驱动，非每帧）。
        for (i, height) in [760.0, 820.0, 640.0].enumerated() {
            surface.frame = NSRect(x: 0, y: 0, width: 1000, height: CGFloat(height))
            surface.layout()
            XCTAssertEqual(surface.layoutPerformedCount, layoutsBefore + i + 1, "第 \(i + 1) 次高度变化恰好一次布局")
        }

        // 同高度重复 layout()：零额外布局（守卫生效，无风暴）。
        let after = surface.layoutPerformedCount
        for _ in 0..<10 {
            surface.layout()
        }
        XCTAssertEqual(surface.layoutPerformedCount, after, "尺寸未变重复 layout 零成本")
        XCTAssertEqual(surface.hostForPage(0)?.frame.height ?? -1, 640, accuracy: 0.001)
    }

    // MARK: - 当前页可访问性描述更新

    func testAccessibilityDescriptionUpdatesOnCommit() {
        let surface = makeSurface(pageCount: 5)
        XCTAssertEqual(surface.accessibilityDescription, "Page 1 of 5")

        flingForwardOnce(surface)
        XCTAssertEqual(surface.core.committedPage, 1)
        XCTAssertEqual(surface.accessibilityDescription, "Page 2 of 5")
    }

    func testAccessibilityDescriptionTracksTrackingAndSettleTarget() {
        let surface = makeSurface(pageCount: 5)
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 900, at: 0.1) // 甩过中点
        XCTAssertEqual(surface.accessibilityDescription, "Page 2 of 5") // tracking：round(offset)
        gestureEnded(surface, at: 0.1)
        finishPendingGesture(surface, at: 0.1)
        XCTAssertEqual(surface.accessibilityDescription, "Page 2 of 5") // settling：提议目标页
        settleFrames(surface)
        XCTAssertEqual(surface.accessibilityDescription, "Page 2 of 5")
    }

    // MARK: - 页面不重叠错误层级

    func testNoOverlappingPagesOrWrongHierarchy() {
        let surface = makeSurface(pageCount: 5)
        // 页面只挂在容器下；容器是 surface 的唯一内容子视图（另有 lab 叠加层）。
        let contentSubviews = surface.subviews.filter { !($0 is NSTextField) }
        XCTAssertEqual(contentSubviews.count, 1)
        XCTAssertTrue(contentSubviews.first === surface.pageContainer)

        // 半径预算：center 0 → 范围 [0,3]，4 个 live 页面。
        let hosts = (0..<4).compactMap { surface.hostForPage($0) }
        XCTAssertEqual(hosts.count, 4)
        XCTAssertNil(surface.hostForPage(4))
        for host in hosts {
            XCTAssertTrue(host.superview === surface.pageContainer)
        }
        // 相邻页面 frame 连续：无缝隙、无重叠。
        for index in 0..<(hosts.count - 1) {
            let a = surface.hostForPage(index)!
            let b = surface.hostForPage(index + 1)!
            XCTAssertEqual(a.frame.maxX, b.frame.minX, accuracy: 0.001)
        }
    }

    // MARK: - pageCount 变化后页码合法（§3.I）

    func testPageCountReductionKeepsPageNumbersValid() {
        let surface = makeSurface(pageCount: 5)
        flingForwardOnce(surface) // → page 1
        flingForwardOnce(surface, at: 10) // → page 2
        XCTAssertEqual(surface.core.committedPage, 2)

        surface.setPageCount(2)
        XCTAssertEqual(surface.core.committedPage, 1) // clamp
        for index in 0..<2 {
            let host = surface.hostForPage(index)
            XCTAssertNotNil(host)
            XCTAssertEqual(host?.accessibilityLabel() as? String, "Page \(index + 1) of 2")
        }
        XCTAssertNil(surface.hostForPage(2), "越界页不得存在")
        XCTAssertEqual(surface.accessibilityDescription, "Page 2 of 2")
    }

    // MARK: - teardown 后无活跃动画驱动器（§7.3 末条 + §3.I 末条）

    func testTeardownStopsAnimationDriver() {
        let surface = PagingSurface(pageCount: 5, itemsPerPage: 8)
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()
        let driver = surface.frameDriver

        // 开始 settle 并断言 display link 已启动（settle 完成前）。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 400, at: 0.5)
        gestureEnded(surface, at: 0.5)
        finishPendingGesture(surface, at: 0.5)
        XCTAssertEqual(surface.core.state, .settling)
        XCTAssertTrue(driver?.isRunning ?? false, "settle 期间 display link 应运行")
        settleFrames(surface)
        XCTAssertFalse(driver?.isRunning ?? true, "settle 完成后 display link 停止")

        surface.teardown()
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertFalse(driver?.isRunning ?? true, "teardown 停 display link")
        XCTAssertNil(surface.frameDriver)
        XCTAssertTrue(surface.core.isTearingDown)
        XCTAssertFalse(surface.core.isAnimating)

        // teardown 后：advanceFrame 无操作、输入被忽略、无崩溃。
        surface.advanceFrame(deltaTime: 1.0 / 60.0)
        gestureBegan(surface, at: 0)
        XCTAssertEqual(surface.core.state, .idle)
    }

    func testWindowCloseTriggersTeardown() {
        let surface = makeSurface(pageCount: 5)
        XCTAssertFalse(surface.isTearingDown)
        surface.viewDidMoveToWindow() // window == nil → teardown（幂等）
        XCTAssertTrue(surface.isTearingDown)
        XCTAssertTrue(surface.core.isTearingDown)
        surface.viewDidMoveToWindow()
        XCTAssertTrue(surface.isTearingDown)
    }

    // MARK: - §3.I 页面内容正确性

    func testPageContentNeverStale() {
        let surface = makeSurface(pageCount: 20, itemsPerPage: 8)
        XCTAssertEqual(surface.hostForPage(1)?.accessibilityLabel() as? String, "Page 2 of 20")

        // 翻走 6 页（page 1 出范围 → 回收），再翻回。
        for _ in 0..<6 { flingForwardOnce(surface) }
        XCTAssertEqual(surface.core.committedPage, 6)
        XCTAssertNil(surface.hostForPage(1), "range 外页面已回收")

        for _ in 0..<5 { flingBackwardOnce(surface, at: 100) } // 翻回 page 1（时间戳继续单调）
        XCTAssertEqual(surface.core.committedPage, 1)
        let host = surface.hostForPage(1)
        XCTAssertNotNil(host)
        XCTAssertEqual(host?.accessibilityLabel() as? String, "Page 2 of 20", "复用后内容正确，无旧内容残留")
        XCTAssertEqual(host?.preparedItemsPerPage, 8)
    }

    // MARK: - Reduce Motion 接线（D8：--reduce-motion-override + 系统偏好刷新路径）

    func testReduceMotionProviderWiring() {
        let surface = PagingSurface(
            pageCount: 5, itemsPerPage: 8, reduceMotion: false,
            reduceMotionProvider: { true }
        )
        surface.frameDriver = nil
        surface.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        surface.layout()
        XCTAssertFalse(surface.core.reduceMotion)

        surface.refreshReduceMotionFromSystem() // 走 provider（AppDelegate 同款接线）
        XCTAssertTrue(surface.core.reduceMotion)

        // RM 下甩动即刻提交（无 spring 动画）。
        gestureBegan(surface, at: 0)
        gestureChanged(surface, deltaX: 600, at: 0.1)
        gestureEnded(surface, at: 0.1)
        finishPendingGesture(surface, at: 0.1)
        XCTAssertEqual(surface.core.committedPage, 1, "RM：settle 缩短为即刻提交")
        XCTAssertFalse(surface.core.isAnimating)

        surface.setReduceMotion(false)
        XCTAssertFalse(surface.core.reduceMotion)
    }

    // MARK: - 容器连续跟随（§3.D 连续跟随）

    func testContainerFollowsVisualOffsetContinuously() {
        let surface = makeSurface(pageCount: 5)
        gestureBegan(surface, at: 0)
        for (step, delta) in [CGFloat(100), 150, -60, 200].enumerated() {
            gestureChanged(surface, deltaX: delta, at: TimeInterval(step + 1) * 0.1)
            let expected = -surface.core.visualOffset * 1000
            XCTAssertEqual(surface.pageContainer.frame.minX, expected, accuracy: 0.001,
                           "容器始终等于 -visualOffset×width（无阶跃）")
        }
        gestureEnded(surface, at: 1.0)
        finishPendingGesture(surface, at: 1.0)
    }

    // MARK: - legacy 滚轮 fallback（§3.C：不得只靠鼠标滚轮宣称触控板通过，但 fallback 可用）

    func testLegacyScrollFallbackDrivesCore() {
        let surface = makeSurface(pageCount: 5)
        // 传统滚动：滚轮向右（内容右移，scrollingDeltaX > 0）→ 下一页。
        surface.handleScrollInput(phase: [], momentumPhase: [], scrollingDeltaX: 600, scrollingDeltaY: 0,
                                  isDirectionInverted: false, timestamp: 0)
        settleFrames(surface)
        XCTAssertEqual(surface.core.committedPage, 1, "无 phase 鼠标滚轮走 legacy fallback")
    }
}
