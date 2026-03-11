# Intent Composition

Compose multiple async actions into one typed workflow.

## Sequential composition

Use ``Intent/combined(with:)`` when the second action should start only after
the first one completes.

```swift
let intent = LoadUserIntent(id: id)
    .combined(with: LoadPermissionsIntent(id: id))
```

The resulting intent returns a tuple with both typed results.

## Concurrent composition

Use ``Intent/combined(simultaneously:)`` when both actions are independent and
can run in parallel.

```swift
let intent = LoadFeedIntent()
    .combined(simultaneously: LoadRecommendationsIntent())
```

This keeps a single trigger point while still allowing the work to run
concurrently.

## Trigger composition from SwiftUI

Composed intents work anywhere a normal intent works:

```swift
struct FeedScreen: View {
    @IntentState private var payload: (Feed, [Recommendation])?

    init() {
        _payload = IntentState(
            LoadFeedIntent()
                .combined(simultaneously: LoadRecommendationsIntent())
        )
    }

    var body: some View {
        IntentButton($payload) {
            Text($payload.isExecuting ? "Loading..." : "Reload")
        }
    }
}
```

## Design guidance

- Use sequential composition when ordering matters.
- Use concurrent composition when the actions are independent.
- Keep composed intents small and domain-specific instead of building one giant workflow type.
