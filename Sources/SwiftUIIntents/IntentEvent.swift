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
@MainActor
final class DeliveredIntentEvents {
    private var delivered: Set<UUID> = []
    private var order: [UUID] = []

    /// Returns the events that were not delivered before, in order, and marks them.
    func fresh(_ events: [IntentEvent]) -> [IntentEvent] {
        var result: [IntentEvent] = []
        for event in events where !delivered.contains(event.id) {
            delivered.insert(event.id)
            order.append(event.id)
            result.append(event)
        }
        // Keep the set bounded; events older than this are long out of every trigger's window.
        if order.count > 512 {
            for id in order.prefix(order.count - 256) { delivered.remove(id) }
            order.removeFirst(order.count - 256)
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
