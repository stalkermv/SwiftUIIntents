# Long-Running Intents

Let an intent finish after the view that started it has gone.

## Overview

By default an intent is cancelled when its view is removed, like SwiftUI's
`.task`. Mark an intent with ``LongRunningIntent`` when its work must not be
interrupted:

```swift
struct SaveDraft: LongRunningIntent {
    let text: String

    func perform(context: Context) async throws {
        try await drafts.save(text)
    }
}

.onDisappear(SaveDraft(text: text))
```

A long-running run is kept in an app-scoped registry until it finishes. It
keeps its ``IntentContext``, so `@IntentContext` works inside the intent.
``IntentHandle/cancel()`` can still stop it.

## What it does not do

After the view is gone no hook reports the run, because the hooks need a
mounted view. The work finishes, the report does not; a failure is written to
the log. Observe your own model if a screen needs the outcome later.

A long-running intent lives as long as the process. It does not ask the system
for background time.

`onDisappear(_:)` accepts only a long-running intent: a plain intent would be
cancelled together with the view, so it does not compile.

## Related markers

``CancellableIntent`` adds a cleanup hook with the reason for the cancellation,
and ``ProgressReportingIntent`` publishes a `Progress`.
