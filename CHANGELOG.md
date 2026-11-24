# Changelog

All notable changes to `SwiftUIIntents` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [2.0.0-beta.1] - 2026-11-24

2.0 is a breaking release. The README has a migration table from 1.x.

### Breaking
- `IntentState`, `IntentBinding` and `IntentButtonWrapper` are removed. `IntentButton(intent) { … }` replaces `IntentButton($binding) { … }`, and the result is read with `onChangeIntentValue(of:)`
- `Intent` has one requirement, `perform(context:) async throws -> PerformResult`. An intent without a result implements it without a return value and its result is `Void`
- `onChange(of:trigger:)` no longer runs when the view appears. It is now `onChange(of:initial:trigger:handle:)` with `initial: false`, like SwiftUI; pass `initial: true` for the old behaviour
- `IntentPicker` has three initializers instead of eight: label closure, label value, and a current-value label
- The minimum platforms are iOS 17, macOS 14, tvOS 17 and watchOS 10 (macOS and watchOS were 15 and 11); depends on CustomComponents `2.0.0-beta.5`

### Added
- Triggers that take an intent: `task(_:)`, `task(id:_:)`, `refreshable(_:)` (not tvOS), `onSubmit(of:policy:_:)`, and builders for `onOpenURL`, `onContinueUserActivity`, `fileImporter` and `fileExporter`
- `IntentToggle`, which commits a toggle change by running an intent
- `IntentReentryPolicy` (`ignore`, `cancelAndRestart`, `queue`) for triggers that can fire again while a run is in flight
- Hooks: `onChangeIntentValue(of:)`, `onChangeIntentPhase`, `onChangeIntentProgress(of:)`, `onChangeIntentError(of:)` and `onReceiveIntentError(of:)`; the `of:` forms pass the intent's `identifier`
- `IntentPhase` (`idle`, `running`, `failed`, `cancelled`, `finished`)
- `IntentHandle`, which cancels the run of one trigger
- Markers: `CancellableIntent` with `withIntentCancellationHandler`, `ProgressReportingIntent`, and `LongRunningIntent`, whose runs outlive their view; `onDisappear(_:)` accepts only a long-running intent

### Changed
- Every trigger runs through one executor that owns the run task, the phase and the events; a run that is superseded can no longer overwrite the newer run's state

### Documentation
- New guides for triggers and hooks and for long-running intents; the README lists what is covered, planned and not planned

## [1.0.0-beta.5] - 2026-11-24

### Added
- `DismissIntent`, a built-in intent that dismisses the sheet, popover or pushed screen the triggering view is in

### Fixed
- `onChangeIntentError(_:)` no longer calls its handler with `nil` when the view appears; it receives `nil` only when an error that was reported before is cleared

### Breaking
- `EmptyIntentResult` is removed. An intent without a result implements `perform(context:) async throws` and its `PerformResult` is `Void`. To migrate, delete `typealias PerformResult = EmptyIntentResult` and `return EmptyIntentResult()`, and use `Void` where you wrote `EmptyIntentResult`, for example `IntentBinding<Void>`

### Documentation
- `onChange(of:trigger:)` documents that a new value cancels the run in flight and that a cancelled run is not reported as an error

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
