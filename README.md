# SwiftUIIntents

[![Tests](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/tests.yml/badge.svg)](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/tests.yml)
[![Documentation](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/documentation.yml/badge.svg)](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/documentation.yml)
[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B%20%7C%20macOS%2014%2B%20%7C%20tvOS%2017%2B%20%7C%20watchOS%2010%2B-lightgrey.svg)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Typed async intents for SwiftUI views, buttons, and state-driven workflows.

- Model user actions as reusable intent types
- Run intents from buttons, pickers, toggles, `.task`, `.refreshable`, `.onSubmit` and more
- Keep environment access explicit through `IntentContext`
- Observe errors, results, phases and progress with `onChangeIntent…` and `onReceiveIntent…` hooks
- Cancel a run with a handle, or let a `LongRunningIntent` outlive its view
- Commit a `Picker` selection by running an intent with `IntentPicker`

## Requirements

- Swift 6.1 or later
- iOS 17, macOS 14, tvOS 17, or watchOS 10 and later

## Installation

Add `SwiftUIIntents` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stalkermv/SwiftUIIntents.git", from: "2.0.0-beta.1")
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SwiftUIIntents", package: "SwiftUIIntents")
        ]
    )
]
```

## Quick Start

```swift
import SwiftUI
import SwiftUIIntents

struct SaveDraftIntent: Intent {
    let message: String

    func perform(context: Context) async throws {
        try await DraftService.shared.save(message, locale: context.locale)
    }
}

struct ComposerView: View {
    @State private var message = ""

    var body: some View {
        IntentButton(SaveDraftIntent(message: message)) {
            Text("Save Draft")
        }
        .onReceiveIntentError { error in
            print("Show every failure event: \(error.localizedDescription)")
        }
    }
}
```

The current release is a pre-release (`2.0.0-beta.1`). Swift Package Manager only
resolves a pre-release when the requirement names one, which is why the snippet above
does not use `from: "1.0.0"`.

## Triggers

Every trigger runs an intent from a view and cancels the run when the view is removed.

| Trigger | Use |
|---|---|
| `IntentButton(intent) { label }` | Run an intent when the button is pressed |
| `IntentPicker(selection, { intent($0) }) { … }` | Commit a picker change by running an intent |
| `IntentToggle(isOn:, { intent($0) }) { label }` | Commit a toggle change by running an intent |
| `.onChange(of: value, initial: false, trigger: intent)` | Run when a value changes; a new value cancels the run in flight |
| `.task(intent)`, `.task(id: id, intent)` | Run when the view appears (and when `id` changes) |
| `.refreshable(intent)` | Run on pull to refresh (not on tvOS) |
| `.onSubmit(of: .text, intent)` | Run when the user submits; a second submit is ignored while one runs |
| `.onOpenURL { url in Intent(url: url) }` | Build an intent from the URL the app is asked to open |
| `.onContinueUserActivity("type") { activity in … }` | Build an intent from a user activity |
| `.fileImporter(…) { result in … }`, `.fileExporter(…) { result in … }` | Build an intent from the picker result (iOS, macOS, visionOS) |
| `.onDisappear(intent)` | Run a `LongRunningIntent` when the view disappears |

The overloads that take an intent sit next to SwiftUI's closure forms, so
`.onSubmit { … }` and `.onSubmit(of: .text, SaveIntent())` both work.

`IntentButton` and `IntentPicker` disable themselves while the intent runs. Neither draws a
progress indicator: while an intent runs, `isLoading` is `true` in the environment, and your
label or `ButtonStyle` draws whatever it wants.

## Reading what happened

Every observation is a modifier on a view above the trigger:

```swift
.onChangeIntentError { error in … }                         // error, or nil when it is cleared
.onReceiveIntentError { error in … }                        // every failure, even equal ones
.onChangeIntentValue(of: LoadDraftIntent.self) { draft, identifier in … }
.onChangeIntentPhase(of: UploadIntent.self) { phase, identifier in … }
.onChangeIntentProgress(of: UploadIntent.self) { progress, identifier in … }
.onChangeIntentError(of: DeleteIntent.self) { error, identifier in … }
.onReceiveIntentError(of: NetworkError.self) { networkError in … }
```

`identifier` tells apart several intents of the same type, for example one per list row.
Override `identifier` on the intent to set it.

`onChangeIntentError` is not called with `nil` when the view appears; it receives `nil` only
when an error that was reported is cleared.

## Cancelling a run

```swift
@State private var upload = IntentHandle<UploadIntent>()

IntentButton(UploadIntent(file: file), handle: upload) { Text("Upload") }
Button("Cancel") { upload.cancel() }
```

A cancelled run is not an error. Its phase is `.cancelled`.

## Intents that outlive the view

An intent marked `LongRunningIntent` is not cancelled when its view goes away; it runs until
it finishes, and the handle can still cancel it. Use it for mutations that must not be
interrupted, such as saving a draft in `onDisappear`.

```swift
struct SaveDraft: LongRunningIntent {
    func perform(context: Context) async throws { … }
}

.onDisappear(SaveDraft(text: text))
```

After the view is gone no hook reports the run: the work finishes, but a failure is only
written to the log. A long-running intent lives as long as the process; it does not ask the
system for background time.

Two more markers exist: `CancellableIntent` (a cleanup hook with the reason for the
cancellation) and `ProgressReportingIntent` (publishes a `Progress`).

## Other types

`Intent`
: Defines a unit of asynchronous work with a typed result.

`IntentContext`
: Reads the current SwiftUI environment snapshot while an intent is executing.

`EmptyIntent`
: An intent that does nothing. Useful in previews and as a placeholder.

`DismissIntent`
: Dismisses the sheet, popover or pushed screen the button is in, like `@Environment(\.dismiss)`.

## What is covered

- ✅ `IntentButton`, `IntentPicker`, `IntentToggle`, `onChange(of:initial:trigger:)`, `task`, `refreshable`, `onSubmit`, `onOpenURL`, `onContinueUserActivity`, `fileImporter`, `fileExporter`, `onDisappear` (long-running only)
- ✅ Error, value, phase and progress hooks; `IntentHandle`; the three markers; sequential and concurrent composition; `@IntentContext`
- 🚧 Not yet: `onDelete` / `onMove`, `onReceive`, `onKeyPress`, macOS commands, `Slider` and `Stepper`, `DatePicker` and `ColorPicker`, `onLongPressGesture`
- ❌ Not planned: `onAppear` (use `task`), `onTapGesture` (use `IntentButton`), `onHover`, `onDrop`, scroll and geometry observers, running an intent from code that has no view, a report to the screen after a view is gone, retry and queueing of intents across launches, Siri and App Intents

## Migrating from 1.x

| 1.x | 2.0 |
|---|---|
| `@IntentState var x` | Removed. Observe the result with `.onChangeIntentValue(of:)` |
| `IntentButton($binding) { … }` | `IntentButton(MyIntent(…)) { … }` |
| `IntentButton(role: .destructive, intent) { … }` | `IntentButton(intent, role: .destructive) { … }`; the intent comes first |
| `IntentBinding`, `IntentButtonWrapper` | Removed |
| `typealias PerformResult = EmptyIntentResult` and `return EmptyIntentResult()` | Delete both lines; the result is `Void` |
| `onChange(of:trigger:)` ran on appear | Add `initial: true` to keep that |
| `IntentPicker` had eight initializers | Three; label closure, label value, and a current-value label |

## Documentation

DocC documentation lives in the package and can be browsed in Xcode or built locally:

- Published docs: https://stalkermv.github.io/SwiftUIIntents/documentation/swiftuiintents

```bash
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target SwiftUIIntents \
  --output-path ./docs \
  --transform-for-static-hosting \
  --hosting-base-path SwiftUIIntents
```

## Development

Run the test suite:

```bash
swift test
```

Compile-check for Apple platforms:

```bash
xcodebuild -workspace .swiftpm/xcode/package.xcworkspace -scheme SwiftUIIntents -destination 'generic/platform=iOS Simulator' build
```

## Release

Release tags follow plain semver without a `v` prefix, for example `2.0.0-beta.1`. Pre-releases use the `-beta.N` suffix.

The repository includes:

- CI for `swift build`, `swift test`, Apple platform compile checks, and DocC validation
- GitHub Pages deployment for DocC
- Source release automation on semver tags, including pre-release tags

## License

`SwiftUIIntents` is available under the MIT license. See [LICENSE](LICENSE).
