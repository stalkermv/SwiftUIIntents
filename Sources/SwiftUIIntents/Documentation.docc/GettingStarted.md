# Getting Started

Build your first intent-driven flow.

## Define an intent

Create a type that conforms to ``Intent``. Implement `perform(context:)` with a
return value, or without one when the intent only has side effects.

```swift
struct LoadProfileIntent: Intent {
    let userID: UUID

    func perform(context: Context) async throws -> String {
        try await API.shared.loadProfileName(id: userID)
    }
}
```

## Execute from a view

Use ``IntentButton`` to trigger the intent from SwiftUI.

```swift
IntentButton(LoadProfileIntent(userID: user.id)) {
    Label("Load Profile", systemImage: "person")
}
```

## Store results in view state

Use ``IntentState`` when the view needs to keep the latest result.

```swift
@IntentState(LoadProfileIntent(userID: user.id)) private var profileName: String?

var body: some View {
    VStack {
        Text(profileName ?? "Unknown")

        IntentButton($profileName) {
            Text($profileName.isExecuting ? "Reloading..." : "Reload")
        }
    }
}
```

## Trigger from state changes

Use ``SwiftUICore/View/onChange(of:trigger:)`` to run an intent when an
equatable value changes.

```swift
Text("Search")
    .onChange(of: query, trigger: RefreshSearchIntent(query: query))
```

The intent runs when the view appears and again each time the value changes. A
new value cancels the run that is still in flight and starts a new one, so a
slower, older run cannot overwrite the result of a newer one. A cancelled run is
not reported as an error.
