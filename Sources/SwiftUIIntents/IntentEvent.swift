//
//  IntentEvent.swift
//  SwiftUIIntents
//

import Foundation
import SwiftUI

/// Something that happened to a run, delivered to the `onChangeIntent…` and
/// `onReceiveIntent…` hooks through a preference.
struct IntentEvent: Equatable {
    enum Kind {
        case phase(IntentPhase)
        case error(Error)
        case value(Any)
        case progress(Progress)
    }

    let id = UUID()
    /// The executor that emitted the event.
    let source: UUID
    /// The event's position among its executor's events, counting from 1.
    let sequence: Int
    /// The intent's type, so a hook can filter by `of:`.
    let intentType: ObjectIdentifier
    /// The intent instance's identifier, for telling apart intents of one type.
    let identifier: String
    let kind: Kind

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

/// Collects the events of every trigger below a hook. Reduction appends, so a
/// trigger with nothing to report never erases a sibling's events.
struct IntentEventPreferenceKey: PreferenceKey {
    // Events carry non-Sendable payloads (errors, results, Progress) on purpose;
    // the empty default is immutable.
    nonisolated(unsafe) static let defaultValue: [IntentEvent] = []

    static func reduce(value: inout [IntentEvent], nextValue: () -> [IntentEvent]) {
        value.append(contentsOf: nextValue())
    }
}

/// Remembers which events a hook has already delivered.
///
/// An executor numbers its events in order and publishes its most recent ones
/// again on every update, so the hook keeps, for each executor, the number of the
/// last event it delivered. An event at or below that number was delivered
/// already, however many events other executors published in between.
@MainActor
final class DeliveredIntentEvents {
    private var lastDelivered: [UUID: Int] = [:]

    /// Returns the events that were not delivered before, in order, and marks them.
    func fresh(_ events: [IntentEvent]) -> [IntentEvent] {
        var result: [IntentEvent] = []
        for event in events where event.sequence > lastDelivered[event.source, default: 0] {
            lastDelivered[event.source] = event.sequence
            result.append(event)
        }
        // An executor whose events are no longer published has left the view
        // tree. Forget it once there are many, so the record stays bounded
        // while every executor that still publishes keeps its entry.
        if lastDelivered.count > 256 {
            let publishing = Set(events.map(\.source))
            lastDelivered = lastDelivered.filter { publishing.contains($0.key) }
        }
        return result
    }
}

struct IntentEventHook: ViewModifier {
    let handle: @MainActor (IntentEvent) -> Void
    @State private var delivered = DeliveredIntentEvents()

    func body(content: Content) -> some View {
        content.onPreferenceChange(IntentEventPreferenceKey.self) { events in
            for event in delivered.fresh(events) {
                handle(event)
            }
        }
    }
}
