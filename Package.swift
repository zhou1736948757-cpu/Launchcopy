// swift-tools-version: 5.9
// PagingPrototype — Phase 1A / 1B
// Main 独占维护：任何 Worker 不得修改本文件；需要新增 target/依赖时报告给 Main 整合。

import PackageDescription

let package = Package(
    name: "PagingPrototype",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // 纯逻辑分页状态机：不依赖 AppKit / Core Animation / 窗口 / 真实触控板事件
        .target(name: "PagingCore"),

        // 可开关 JSONL telemetry（默认关闭）
        .target(name: "PagingTelemetry"),

        // AppKit 视图、页面承载、输入处理、settle 动画与中断
        .target(
            name: "PagingUI",
            dependencies: ["PagingCore"]
        ),

        // App 入口：窗口、命令行参数、退出/重开/resize
        .executableTarget(
            name: "PagingPrototypeApp",
            dependencies: ["PagingCore", "PagingTelemetry", "PagingUI", "AppCatalogCore", "MacAppCatalog", "AppIconPipeline", "AppGridUI"]
        ),

        // Phase 1B：纯 Foundation domain：稳定身份、快照、diff、排序去重 policy、分页计划、锚点重映射、fixtures
        .target(name: "AppCatalogCore"),

        // Phase 1B：macOS 只读扫描适配器（受限根枚举、Bundle metadata、规范化、失败分类、latest-wins refresh）
        .target(
            name: "MacAppCatalog",
            dependencies: ["AppCatalogCore"]
        ),

        // Phase 1B：异步图标管道（有界内存缓存、in-flight 合并、取消、复用防串图；图标仅运行时读取）
        .target(
            name: "AppIconPipeline",
            dependencies: ["AppCatalogCore"]
        ),

        // Phase 1B：真实内容网格 UI（只依赖领域/管道/承载 seam；不依赖 MacAppCatalog，装配层注入）
        .target(
            name: "AppGridUI",
            dependencies: ["AppCatalogCore", "AppIconPipeline", "PagingUI"]
        ),

        .testTarget(
            name: "PagingCoreTests",
            dependencies: ["PagingCore"]
        ),
        .testTarget(
            name: "PagingTelemetryTests",
            dependencies: ["PagingTelemetry"]
        ),
        .testTarget(
            name: "PagingUITests",
            dependencies: ["PagingUI", "PagingPrototypeApp"]
        ),

        // Phase 1B 测试 targets（§10.1：每 target executed > 0）
        .testTarget(
            name: "AppCatalogCoreTests",
            dependencies: ["AppCatalogCore"]
        ),
        .testTarget(
            name: "MacAppCatalogTests",
            dependencies: ["MacAppCatalog", "AppCatalogCore"]
        ),
        .testTarget(
            name: "AppIconPipelineTests",
            dependencies: ["AppIconPipeline", "AppCatalogCore"]
        ),
        .testTarget(
            name: "AppGridUITests",
            dependencies: ["AppGridUI", "PagingUI", "AppCatalogCore", "AppIconPipeline"]
        ),
    ]
)
