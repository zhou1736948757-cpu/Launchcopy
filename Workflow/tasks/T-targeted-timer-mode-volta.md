# T-targeted-timer-mode-volta

## Role
Read-only explorer (Volta).

## Objective
Independently audit existing telemetry/frame/runloop profilers and launch arguments to determine what additional anonymous measurements are needed to distinguish timer cadence, runloop mode boundaries, callback work, and post-callback system work.

## Scope
`Sources/PagingTelemetry/`, `Sources/PagingUI/RunLoopProfileRecorder.swift`, `FrameProfileRecorder.swift`, `PagingTelemetryBridge.swift`, `PagingPrototypeApp/` launch/arguments, `Tools/`, relevant tests/docs under this project only.

## Forbidden
Do not read or modify `/Users/mac/Projects/LaunchBetter/`, `/Users/mac/Projects/BuhoReverseNotes/`, or reverse-engineering evidence. Do not modify any file or `Sources/PagingCore/`. Do not claim a root cause without evidence.

## Deliverable
List current blind spots, propose the smallest privacy-safe probe schema and controlled A/B matrix, identify exact integration points, and state what each result would and would not prove.
