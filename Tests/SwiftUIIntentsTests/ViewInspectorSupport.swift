import SwiftUI
import ViewInspector
@testable import SwiftUIIntents

@MainActor
func waitUntil(
    timeoutNanoseconds: UInt64 = 1_000_000_000,
    pollNanoseconds: UInt64 = 20_000_000,
    condition: @escaping @MainActor () -> Bool
) async -> Bool {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while !condition() {
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            return false
        }
        try? await Task.sleep(nanoseconds: pollNanoseconds)
    }

    return true
}
