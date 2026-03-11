# ``SwiftUIIntents``

Model async SwiftUI actions as typed intents with explicit context and predictable state.

## Overview

`SwiftUIIntents` lets you describe user actions as reusable `Intent` types and execute
them from buttons, state changes, or your own `IntentBinding`.

Use the package when you want:

- typed action results instead of unstructured callbacks
- environment access inside intents without prop drilling
- reusable error handling for repeated failures
- composition of sequential and concurrent intent flows

```swift
struct SaveIntent: Intent {
    typealias PerformResult = EmptyIntentResult

    let text: String

    func perform(context: Context) async throws -> EmptyIntentResult {
        try await DraftService.shared.save(text, locale: context.locale)
        return EmptyIntentResult()
    }
}

struct ComposerView: View {
    @State private var text = ""

    var body: some View {
        IntentButton(SaveIntent(text: text)) {
            Text("Save")
        }
        .onReceiveIntentError { error in
            print(error.localizedDescription)
        }
    }
}
```

## Topics

### Essentials

- ``Intent``
- ``IntentState``
- ``IntentBinding``
- ``IntentButton``
- ``IntentContext``

### Error Handling

- ``IntentButton/onChangeIntentError(_:)``
- ``IntentButton/onReceiveIntentError(_:)``

### Composition

- ``SwiftUIIntents/Intent/combined(with:)``
- ``SwiftUIIntents/Intent/combined(simultaneously:)``

### Guides

- <doc:GettingStarted>
- <doc:IntentStateAndBinding>
- <doc:IntentComposition>
- <doc:ErrorHandling>
