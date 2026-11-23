import SwiftUI

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// A handle to a view that is mounted in a real host, so that SwiftUI actually
/// evaluates `body` and re-evaluates it when observed state changes.
///
/// Tests here assert on observable effects — counters, preferences, environment
/// values — never on the shape of the rendered tree. That keeps them independent
/// of view-inspection libraries and of SwiftUI's private layout details.
@MainActor
struct HostedHandle {
    /// How long ``render()`` keeps polling for quiescence before giving up.
    ///
    /// A host that never settles then fails the test on its own assertions
    /// instead of hanging the suite.
    private static let quiescenceTimeout: Duration = .seconds(2)

    private let layout: @MainActor () -> Void
    private let isLayoutPending: @MainActor () -> Bool

    init(
        layout: @escaping @MainActor () -> Void,
        isLayoutPending: @escaping @MainActor () -> Bool
    ) {
        self.layout = layout
        self.isLayoutPending = isLayoutPending
    }

    /// Forces layout passes until the host stops asking for another one.
    ///
    /// SwiftUI delivers invalidations asynchronously: mutating observed state
    /// only *schedules* the update, so a layout pass taken right after the
    /// mutation can run before the host has been marked dirty at all. Rather
    /// than guess at a wall-clock delay, this lays out, hands the main actor
    /// back so the scheduled update can run, and repeats until the host reports
    /// nothing pending — a real post-condition instead of a duration.
    ///
    /// `Task.yield()` still suspends and resumes in a cancelled task, so a
    /// cancelled test gets a genuine drain here rather than a silent no-op.
    func render() async {
        let deadline = ContinuousClock.now + Self.quiescenceTimeout
        var isQuiescent = false

        while !isQuiescent, ContinuousClock.now < deadline {
            layout()
            await Task.yield()
            isQuiescent = !isLayoutPending()
        }

        layout()
    }
}

/// Mounts `view`, runs `body`, and tears the host down afterwards.
@MainActor
func withHostedView<V: View>(
    _ view: V,
    _ body: @MainActor (HostedHandle) async throws -> Void
) async rethrows {
    #if canImport(AppKit)
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
    let window = NSWindow(
        contentRect: host.frame,
        styleMask: [.borderless],
        backing: .buffered,
        defer: false
    )
    window.contentView = host
    let handle = HostedHandle(
        layout: { host.layoutSubtreeIfNeeded() },
        isLayoutPending: { host.needsLayout }
    )
    defer { window.contentView = nil }
    #elseif canImport(UIKit) && !os(watchOS)
    let controller = UIHostingController(rootView: view)
    controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
    let window = UIWindow(frame: controller.view.frame)
    window.rootViewController = controller
    window.isHidden = false
    let handle = HostedHandle(
        layout: { controller.view.layoutIfNeeded() },
        // `UIView` exposes no `needsLayout` of its own — the flag that
        // `setNeedsLayout()` raises lives on the backing layer.
        isLayoutPending: { controller.view.layer.needsLayout() }
    )
    defer { window.isHidden = true }
    #else
    #error("withHostedView mounts its view in an NSWindow or a UIWindow, and watchOS has neither. Tests using it cannot run there.")
    #endif

    await handle.render()
    try await body(handle)
}
