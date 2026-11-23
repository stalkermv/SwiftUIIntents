# Changelog

All notable changes to `SwiftUIIntents` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0-beta.4] - 2026-11-23

### Fixed
- `IntentState` no longer discards its execution state when the parent view is rebuilt; the executor now lives in SwiftUI-owned storage
- The intent seen by a button or binding can no longer be stale, because it now travels with the binding instead of being synced into the executor asynchronously
- `_TestingIntentExecutor` now installs the intent context, so intents that read `@IntentContext` no longer trap under test
- A cancelled intent is no longer reported as a failure, so leaving a screen while an intent runs does not surface an error
- An idle sibling no longer erases a failing sibling's error before it reaches `onChangeIntentError` or `onReceiveIntentError`

### Changed
- `IntentBinding.intent` is now a stored `let` property instead of a computed `var`; it is read-only in both forms, so source compatibility is unaffected
- Intent execution failures are logged with `os.Logger` instead of being printed to standard output
- Signpost intervals carry the intent identifier, so separate intents can be told apart in Instruments

## [1.0.0-beta.3] - 2026-05-05

### Added
- `IntentPicker`, a `Picker` that commits a selection by running an intent, with optimistic selection and pending-request handling
- Overloads on `IntentBinding` for performing a supplied intent instance

## [1.0.0-beta.2] - 2026-04-30

### Added
- `_TestingIntentExecutor` (`@_spi(Testing)`) for running an intent in tests with a given environment

## [1.0.0-beta.1] - 2026-03-11

### Added
- Source-first Swift Package distribution under the MIT license
- DocC documentation and GitHub Pages publishing workflow
- `onReceiveIntentError(_:)` for repeatable error-event observation
- Regression tests for executor, intent composition, and error semantics

### Changed
- Replaced the local `AsyncButton` target with the `CustomComponents` package dependency
- Expanded README and public API documentation
- Switched release automation from XCFramework publishing to source-package releases

### Removed
- Binary-only publication assets and proprietary licensing artifacts
