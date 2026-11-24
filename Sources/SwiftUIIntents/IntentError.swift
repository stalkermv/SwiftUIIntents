//
//  IntentError.swift
//  SwiftUIIntents
//
//  Created by Valeriy Malishevskyi on 29.04.2025.
//

import Foundation
import SwiftUI

enum IntentError: Error {
    case noIntent
}

struct IntentErrorEvent: Equatable {
    let id: UUID
    let error: Error
    
    init(id: UUID = UUID(), error: Error) {
        self.id = id
        self.error = error
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension View {
    /// Observes changes to the current intent error state.
    ///
    /// This modifier behaves like SwiftUI's `onChange`: the handler runs only when
    /// the observed error value changes. Repeating the same error payload will not
    /// trigger the handler again until the underlying error state changes.
    ///
    /// The handler is not called with `nil` when the view appears with nothing to
    /// report. It receives `nil` only when a previously reported error is cleared,
    /// for example when the intent runs again.
    public func onChangeIntentError(_ handler: @escaping (Error?) -> Void) -> some View {
        modifier(IntentErrorChangeModifier(handler: handler))
    }
    
    /// Receives every emitted intent failure event, including repeated occurrences
    /// of the same error payload.
    public func onReceiveIntentError(_ handler: @escaping (Error) -> Void) -> some View {
        self.onPreferenceChange(IntentErrorEventPreferenceKey.self) { event in
            guard let event else {
                return
            }
            handler(event.error)
        }
    }
}

struct IntentErrorChangeModifier: ViewModifier {
    let handler: (Error?) -> Void

    /// Whether an error has been reported and not yet cleared.
    ///
    /// The preference starts out as `nil`, and `onPreferenceChange` reports that
    /// first value when the view appears. A `nil` is only worth delivering when
    /// it clears an error that was reported before.
    @State private var hasReportedError = false

    func body(content: Content) -> some View {
        content.onPreferenceChange(IntentErrorPreferenceKey.self) { container in
            if let container {
                hasReportedError = true
                handler(container.error)
            } else if hasReportedError {
                hasReportedError = false
                handler(nil)
            }
        }
    }
}

struct IntentErrorPreferenceKey: PreferenceKey {
    
    /// A failure worth reporting.
    ///
    /// The stored error is non-optional, so an "empty" container cannot exist.
    /// A child with nothing to report gets `nil` back from the failable
    /// initialiser and publishes `nil`, which `reduce` knows to ignore — instead
    /// of publishing a non-`nil` wrapper around a `nil` error that would erase a
    /// failing sibling.
    struct EquatableError: Equatable {
        let error: Error
        
        init?(_ error: Error?) {
            guard let error else { return nil }
            self.error = error
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.error.localizedDescription == rhs.error.localizedDescription
        }
    }
    
    static let defaultValue: EquatableError? = nil
    
    static func reduce(value: inout EquatableError?, nextValue: () -> EquatableError?) {
        // A child with nothing to report must not erase a sibling that has.
        value = nextValue() ?? value
    }
}

struct IntentErrorEventPreferenceKey: PreferenceKey {
    static let defaultValue: IntentErrorEvent? = nil
    
    static func reduce(value: inout IntentErrorEvent?, nextValue: () -> IntentErrorEvent?) {
        // A child with nothing to report must not erase a sibling that has.
        value = nextValue() ?? value
    }
}
