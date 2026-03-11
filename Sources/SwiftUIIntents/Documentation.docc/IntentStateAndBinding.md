# Intent State and Binding

Keep execution state in SwiftUI without building your own task coordinator.

## Store the latest result

Use ``IntentState`` when a view needs to keep the latest successful output from
an intent.

```swift
struct RefreshProfileIntent: Intent {
    let id: UUID

    func perform(context: Context) async throws -> String {
        try await API.shared.loadProfileName(id: id)
    }
}

struct ProfileHeader: View {
    let id: UUID
    @IntentState private var profileName: String?

    init(id: UUID) {
        self.id = id
        self._profileName = IntentState(RefreshProfileIntent(id: id))
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text(profileName ?? "Unknown")

            IntentButton($profileName) {
                Text($profileName.isExecuting ? "Refreshing..." : "Refresh")
            }
        }
    }
}
```

## Drive custom UI from the binding

``IntentBinding`` exposes the current intent, execution status, and a `perform()`
method that captures the active SwiftUI environment and runs the intent inside a
service context.

This is useful when you want a custom control instead of ``IntentButton``:

```swift
struct RetryButton: View {
    let binding: IntentBinding<EmptyIntentResult>

    var body: some View {
        Button(binding.isExecuting ? "Retrying..." : "Retry") {
            Task {
                await binding.perform()
            }
        }
        .disabled(binding.isExecuting || binding.intent == nil)
    }
}
```

## When to choose each type

- Use ``IntentButton`` for the default button-driven flow.
- Use ``IntentState`` when the view should own the latest result.
- Use ``IntentBinding`` when you need a custom presentation or trigger.
