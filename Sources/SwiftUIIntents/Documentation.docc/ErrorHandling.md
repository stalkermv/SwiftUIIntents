# Error Handling

Choose between state-based and event-based error observation.

## Observe error state changes

``IntentButton/onChangeIntentError(_:)`` behaves like `onChange`.
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

## Observe every failure event

``IntentButton/onReceiveIntentError(_:)`` emits every failure, even when
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
