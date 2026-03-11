# Changelog

All notable changes to `SwiftUIIntents` are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

## [1.0.0] - 2026-03-11

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
