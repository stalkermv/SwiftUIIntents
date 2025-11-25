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

extension View {
    public func onChangeIntentError(_ handler: @escaping (Error?) -> Void) -> some View {
        self.onPreferenceChange(IntentErrorPreferenceKey.self) { container in
            handler(container?.error)
        }
    }
}

struct IntentErrorPreferenceKey: PreferenceKey {
    
    struct EquatableError: Equatable {
        let error: Error?
        
        init(_ error: Error?) {
            self.error = error
        }
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            return lhs.error?.localizedDescription == rhs.error?.localizedDescription
        }
    }
    
    static let defaultValue: EquatableError? = nil
    
    static func reduce(value: inout EquatableError?, nextValue: () -> EquatableError?) {
        value = nextValue()
    }
}
