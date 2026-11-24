# Triggers and Hooks

Run an intent from a view, and read what happened from the views above it.

## Triggers

Every trigger runs an intent from a view and cancels the run when the view is
removed. ``IntentButton`` and ``IntentPicker`` disable themselves while the
intent runs.

```swift
IntentButton(SaveDraftIntent(message: message)) { Text("Save") }

List(items) { … }
    .task(LoadItemsIntent())
    .refreshable(RefreshItemsIntent())

TextField("Title", text: $title)
    .onSubmit(of: .text, SaveTitleIntent(title: title))
```

``IntentButton`` and the other triggers set `isLoading` in the environment while
the intent runs. They do not draw a progress indicator; the label or the
`ButtonStyle` does.

When SwiftUI hands over a value, pass a closure that builds the intent:

```swift
.onOpenURL { url in OpenLinkIntent(url: url) }
```

The overloads that take an intent sit next to SwiftUI's own closure forms.

### Running again while a run is in flight

`onSubmit` and the payload triggers take an ``IntentReentryPolicy``:
``IntentReentryPolicy/ignore`` waits for the run to finish (the default for
`onSubmit`), ``IntentReentryPolicy/cancelAndRestart`` stops it and starts the
new one, ``IntentReentryPolicy/queue`` runs the new one afterwards.

## Reading what happened

```swift
.onChangeIntentError { error in … }
.onReceiveIntentError { error in … }
.onChangeIntentValue(of: LoadDraftIntent.self) { draft, identifier in … }
.onChangeIntentPhase(of: UploadIntent.self) { phase, identifier in … }
.onChangeIntentProgress(of: UploadIntent.self) { progress, identifier in … }
```

`identifier` is the intent's ``Intent/identifier``. Override it to tell apart
several intents of the same type, for example one per row.

## Cancelling

Pass an ``IntentHandle`` to one trigger and call `cancel()` on it. A cancelled
run has the phase ``IntentPhase/cancelled`` and is not reported as an error.
