# Error Handling

Choose between state-based and event-based error observation.

## Observe error state changes

``SwiftUICore/View/onChangeIntentError(_:)`` behaves like `onChange`.
It is useful when you care about transitions of the observed error value.

```swift
IntentButton(DeleteIntent(id: id)) {
    Text("Delete")
}
.onChangeIntentError { error in
    guard let error else { return }
    print("Observed a changed error state: \(error.localizedDescription)")
}
```

If the same error payload happens twice in a row, this modifier does not fire
again until the stored error state changes.

The handler is not called with `nil` when the view appears with nothing to
report. It receives `nil` only when a previously reported error is cleared, for
example when the intent runs again.

## Observe every failure event

``SwiftUICore/View/onReceiveIntentError(_:)`` emits every failure, even when
the error payload is equal to the previous one.

```swift
IntentButton(DeleteIntent(id: id)) {
    Text("Delete")
}
.onReceiveIntentError { error in
    print("Show an alert every time deletion fails: \(error.localizedDescription)")
}
```

Use this variant for alerts, toasts, banners, and any UX where repeating the
same error should still be visible to the user.

## Cancellation is not a failure

When an intent is cancelled, for example because its view disappears or a
newer run replaces it, the cancellation is not reported as an error. Neither
modifier fires and the state returns to idle. Other errors are logged with
`os.Logger` and published to both modifiers.

## Filter by intent or by error type

```swift
.onChangeIntentError(of: DeleteIntent.self) { error, identifier in … }
.onReceiveIntentError(of: NetworkError.self) { networkError in … }
```

The first receives the error of one intent type, with the intent's `identifier` so
a list of fifty rows can tell them apart. The second receives only errors of one
type and hands them over already cast.

## Several intents in one view

When several buttons in the same view hierarchy report errors, an idle sibling
never clears the error of a sibling that has failed.
