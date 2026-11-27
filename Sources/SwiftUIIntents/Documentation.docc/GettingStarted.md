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

## Read the result

Observe what an intent produces with a hook on a view above the trigger:

```swift
IntentButton(LoadProfileIntent(userID: user.id)) {
    Text("Reload")
}
.onChangeIntentValue(of: LoadProfileIntent.self) { name, _ in
    profileName = name
}
```

The button disables itself while the intent runs and sets `isLoading` in the
environment, so the label or the `ButtonStyle` can draw a progress indicator.

## Trigger from state changes

Use ``SwiftUICore/View/onChange(of:initial:trigger:handle:)`` to run an intent when an
equatable value changes.

```swift
Text("Search")
    .onChange(of: query, trigger: RefreshSearchIntent(query: query))   // add initial: true to run on appear
```

The intent runs each time the value changes, and on appear when you pass
`initial: true`. A
new value cancels the run that is still in flight and starts a new one, so a
slower, older run cannot overwrite the result of a newer one. A cancelled run is
not reported as an error.
