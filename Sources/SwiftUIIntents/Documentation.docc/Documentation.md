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
- pickers that commit a selection by running an intent

```swift
struct SaveIntent: Intent {
    let text: String

    func perform(context: Context) async throws {
        try await DraftService.shared.save(text, locale: context.locale)
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
- ``IntentPicker``
- ``IntentContext``
- ``EmptyIntent``
- ``DismissIntent``

### Error Handling

- ``SwiftUICore/View/onChangeIntentError(_:)``
- ``SwiftUICore/View/onReceiveIntentError(_:)``

### Composition

- ``Intent/combined(with:)``
- ``Intent/combined(simultaneously:)``
- ``CombinedIntent``
- ``SimultaneousCombinedIntent``

### Guides

- <doc:GettingStarted>
- <doc:IntentStateAndBinding>
- <doc:IntentComposition>
- <doc:ErrorHandling>
