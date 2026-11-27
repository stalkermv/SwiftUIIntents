# ``SwiftUIIntents``

Model async SwiftUI actions as typed intents with explicit context and predictable state.

## Overview

`SwiftUIIntents` lets you describe user actions as reusable `Intent` types and execute
them from buttons, pickers, toggles, `.task`, `.refreshable`, `.onSubmit` and more.

Use the package when you want:

- typed action results instead of unstructured callbacks
- environment access inside intents without prop drilling
- hooks for errors, results, phases and progress
- cancellation with a handle, and intents that outlive their view
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
- ``IntentContext``
- ``EmptyIntent``
- ``DismissIntent``
- ``IntentPhase``
- ``IntentHandle``

### Triggers

- ``IntentButton``
- ``IntentPicker``
- ``IntentCustomPicker``
- ``IntentToggle``
- ``IntentReentryPolicy``
- ``SwiftUICore/View/onChange(of:initial:trigger:handle:)``
- ``SwiftUICore/View/task(_:handle:)``
- ``SwiftUICore/View/task(id:_:handle:)``
- ``SwiftUICore/View/onSubmit(of:policy:_:)``
- ``SwiftUICore/View/onOpenURL(policy:_:)``
- ``SwiftUICore/View/onDisappear(_:)``

### Reading what happened

- ``SwiftUICore/View/onChangeIntentError(_:)``
- ``SwiftUICore/View/onReceiveIntentError(_:)``
- ``SwiftUICore/View/onChangeIntentValue(of:_:)``
- ``SwiftUICore/View/onChangeIntentPhase(of:_:)``
- ``SwiftUICore/View/onChangeIntentProgress(of:_:)``

### Capabilities

- ``CancellableIntent``
- ``ProgressReportingIntent``
- ``LongRunningIntent``
- ``IntentCancellationReason``

### Composition

- ``Intent/combined(with:)``
- ``Intent/combined(simultaneously:)``
- ``CombinedIntent``
- ``SimultaneousCombinedIntent``

### Guides

- <doc:GettingStarted>
- <doc:TriggersAndHooks>
- <doc:LongRunningIntents>
- <doc:IntentComposition>
- <doc:ErrorHandling>
