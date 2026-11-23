# SwiftUIIntents

[![Tests](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/tests.yml/badge.svg)](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/tests.yml)
[![Documentation](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/documentation.yml/badge.svg)](https://github.com/stalkermv/SwiftUIIntents/actions/workflows/documentation.yml)
[![Swift 6.1+](https://img.shields.io/badge/Swift-6.1+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/platform-iOS%2017%2B%20%7C%20macOS%2015%2B%20%7C%20tvOS%2017%2B%20%7C%20watchOS%2011%2B-lightgrey.svg)](https://developer.apple.com/swift/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

Typed async intents for SwiftUI views, buttons, and state-driven workflows.

- Model user actions as reusable intent types
- Execute intents from buttons or state changes
- Keep environment access explicit through `IntentContext`
- Observe intent failures as state changes or as repeatable error events
- Commit a `Picker` selection by running an intent with `IntentPicker`

## Requirements

- Swift 6.1 or later
- iOS 17, macOS 15, tvOS 17, or watchOS 11 and later

## Installation

Add `SwiftUIIntents` to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/stalkermv/SwiftUIIntents.git", from: "1.0.0-beta.4")
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
    typealias PerformResult = EmptyIntentResult

    let message: String

    func perform(context: Context) async throws -> EmptyIntentResult {
        try await DraftService.shared.save(message, locale: context.locale)
        return EmptyIntentResult()
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

The current release is a pre-release (`1.0.0-beta.4`). Swift Package Manager only
resolves a pre-release when the requirement names one, which is why the snippet above
does not use `from: "1.0.0"`.

## Core APIs

`Intent`
: Defines a unit of asynchronous work with a typed result.

`IntentState`
: Stores an executor in SwiftUI state and exposes its latest result through a property wrapper.

`IntentButton`
: Executes an intent from a SwiftUI button and passes an `IntentBinding` into the label content.

`IntentContext`
: Reads the current SwiftUI environment snapshot while an intent is executing.

`IntentPicker`
: A `Picker` that commits the user's selection by running an intent. It shows the new selection right away and returns to your source-of-truth value when the intent finishes.

`EmptyIntent`
: An intent that does nothing. Useful in previews and as a placeholder.

## IntentPicker

```swift
IntentPicker(theme, { SetThemeIntent(theme: $0) }) {
    Text("Light").tag(Theme.light)
    Text("Dark").tag(Theme.dark)
} label: {
    Text("Theme")
}
```

`theme` is the current value from your own state. When the user picks another value, the picker runs `SetThemeIntent` and is disabled until it finishes.

## Error Handling

Use `onChangeIntentError(_:)` when you want change-based observation:

```swift
.onChangeIntentError { error in
    if let error {
        print("Only runs when the observed error state changes")
    }
}
```

Use `onReceiveIntentError(_:)` when repeated equal failures must be surfaced every time:

```swift
.onReceiveIntentError { error in
    print("Runs for every emitted failure event: \(error.localizedDescription)")
}
```

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

Release tags follow plain semver without a `v` prefix, for example `1.0.0-beta.4`. Pre-releases use the `-beta.N` suffix.

The repository includes:

- CI for `swift build`, `swift test`, Apple platform compile checks, and DocC validation
- GitHub Pages deployment for DocC
- Source release automation on semver tags, including pre-release tags

## License

`SwiftUIIntents` is available under the MIT license. See [LICENSE](LICENSE).
