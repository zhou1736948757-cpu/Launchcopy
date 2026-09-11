# T-targeted-timer-mode-terra

## Role
Read-only explorer (Terra).

## Objective
Inspect Timer cadence/tolerance, RunLoop common modes, driver start/stop lifecycle, Timer restart/first-tick behavior, continuous timestamps, and dt handling for possible 20–53 ms frame hitches.

## Scope
`Sources/PagingUI/PagingFrameDriver.swift`, `Sources/PagingUI/PagingSurface.swift`, related app argument/launch and profiling code, and relevant tests/docs under this project only.

## Forbidden
Do not read or modify `/Users/mac/Projects/LaunchBetter/`, `/Users/mac/Projects/BuhoReverseNotes/`, or any reverse-engineering evidence. Do not modify `Sources/PagingCore/` or any file. Do not equate waiting-like with wake-up/scheduler root cause.

## Deliverable
Report concrete paths/line references, measured vs inferred mechanisms, minimal Timer A/B and mode-boundary experiment design, and verification recommendations without changing PagingCore.
