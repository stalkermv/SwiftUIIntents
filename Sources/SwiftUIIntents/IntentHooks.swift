//
//  IntentHooks.swift
//  SwiftUIIntents
//

import Foundation
import SwiftUI

/// Remembers which intents currently have a reported error, so a hook can tell a
/// run that clears an error from one that never failed.
@MainActor
final class ReportedErrors {
    var identifiers: Set<String> = []
}

extension View {
    /// Observes the value an intent of type `I` produces.
    ///
    /// The handler runs once for every finished run, with the result and the
    /// intent's ``Intent/identifier``, which tells apart several intents of the same
    /// type, for example one per list row.
    public func onChangeIntentValue<I: Intent>(
        of type: I.Type,
        _ handler: @escaping (I.PerformResult, String) -> Void
    ) -> some View {
        modifier(IntentEventHook { event in
            guard event.intentType == ObjectIdentifier(I.self),
                  case .value(let value) = event.kind,
                  let result = value as? I.PerformResult
            else { return }
            handler(result, event.identifier)
        })
    }

    /// Observes the phase of every intent run below this view.
    public func onChangeIntentPhase(_ handler: @escaping (IntentPhase) -> Void) -> some View {
        modifier(IntentEventHook { event in
            if case .phase(let phase) = event.kind {
                handler(phase)
            }
        })
    }

    /// Observes the phase of the runs of an intent of type `I`.
    public func onChangeIntentPhase<I: Intent>(
        of type: I.Type,
        _ handler: @escaping (IntentPhase, String) -> Void
    ) -> some View {
        modifier(IntentEventHook { event in
            guard event.intentType == ObjectIdentifier(I.self),
                  case .phase(let phase) = event.kind
            else { return }
            handler(phase, event.identifier)
        })
    }

    /// Observes the progress of an intent of type `I`.
    ///
    /// The handler receives the intent's `Progress` object once, when the run
    /// starts; read it, or observe it, for the fractions.
    public func onChangeIntentProgress<I: ProgressReportingIntent>(
        of type: I.Type,
        _ handler: @escaping (Progress, String) -> Void
    ) -> some View {
        modifier(IntentEventHook { event in
            guard event.intentType == ObjectIdentifier(I.self),
                  case .progress(let progress) = event.kind
            else { return }
            handler(progress, event.identifier)
        })
    }

    /// Observes the error state of an intent of type `I`.
    ///
    /// Like ``onChangeIntentError(_:)`` the handler receives `nil` when an error
    /// that was reported is cleared by the next run, and never on its own when
    /// nothing has failed.
    public func onChangeIntentError<I: Intent>(
        of type: I.Type,
        _ handler: @escaping (Error?, String) -> Void
    ) -> some View {
        modifier(IntentErrorOfTypeHook<I>(handler: handler))
    }

    /// Receives every error of type `E`, including repeated occurrences, already
    /// cast to `E`.
    public func onReceiveIntentError<E: Error>(
        of type: E.Type,
        _ handler: @escaping (E) -> Void
    ) -> some View {
        modifier(IntentEventHook { event in
            if case .error(let error) = event.kind, let typed = error as? E {
                handler(typed)
            }
        })
    }
}

private struct IntentErrorOfTypeHook<I: Intent>: ViewModifier {
    let handler: (Error?, String) -> Void
    @State private var reported = ReportedErrors()

    func body(content: Content) -> some View {
        content.modifier(IntentEventHook { event in
            guard event.intentType == ObjectIdentifier(I.self) else { return }

            switch event.kind {
            case .error(let error):
                reported.identifiers.insert(event.identifier)
                handler(error, event.identifier)
            case .phase(.running):
                if reported.identifiers.remove(event.identifier) != nil {
                    handler(nil, event.identifier)
                }
            default:
                break
            }
        })
    }
}
