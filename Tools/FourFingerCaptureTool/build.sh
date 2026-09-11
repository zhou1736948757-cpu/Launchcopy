#!/bin/bash
# 四指采集工具构建脚本（T-G-P6；独立脚本，不动 Package.swift）
set -euo pipefail
cd "$(dirname "$0")/../.."
swiftc -O \
  Sources/PagingPrototypeApp/PinchRecognizer.swift \
  Sources/PagingPrototypeApp/TouchProvider.swift \
  Sources/PagingPrototypeApp/MultitouchSupportBackend.swift \
  Sources/PagingPrototypeApp/FourFingerCaptureStats.swift \
  Tools/FourFingerCaptureTool/main.swift \
  -o /tmp/fourfinger-capture-tool
echo "built: /tmp/fourfinger-capture-tool"
