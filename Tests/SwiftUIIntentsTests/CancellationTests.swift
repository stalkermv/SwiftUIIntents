import SwiftUI
import Testing
@_spi(Testing) @testable import SwiftUIIntents

// MARK: - Fixtures

@MainActor
private final class Probe {
    var started: [String] = []
    var finished: [String] = []
    var cancelled: [String] = []
}

/// Sleeps for `delay` and records whether the run started, finished or was cancelled.
@MainActor
private func probeRun(_ probe: Probe, _ label: String, _ delay: Duration) async throws -> String {
    probe.started.append(label)
    do {
        try await Task.sleep(for: delay)
    } catch {
        probe.cancelled.append(label)
        throw error
    }
    probe.finished.append(label)
    return label
}

private struct ProbeIntent: Intent {
    let probe: Probe
    let label: String
    var delay: Duration = .seconds(30)

    func perform(context: Context) async throws -> String {
        try await probeRun(probe, label, delay)
    }

    var identifier: String { label }
}

private struct ProbeLongIntent: LongRunningIntent {
    let probe: Probe
    let label: String
    var delay: Duration = .seconds(30)

    func perform(context: Context) async throws -> String {
        try await probeRun(probe, label, delay)
    }

    var identifier: String { label }
}

@MainActor
private func makeContext() -> IntentContextContainer {
    IntentContextContainer(environment: EnvironmentValues())
}

@MainActor
private func waitFor(_ timeout: Duration = .seconds(20), _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}

/// Gives a run that should not happen time to show up.
private func settle() async {
    try? await Task.sleep(for: .milliseconds(200))
}

// MARK: - Task owner

@MainActor
@Suite("Task owner teardown")
struct TaskOwnerTeardownTests {
    @Test("Releasing the owner cancels the run in flight and every queued run")
    func releaseCancelsQueuedRuns() async {
        let probe = Probe()
        var host: IntentRunHost<String>? = IntentRunHost<String>()
        let env = EnvironmentValues()

        host?.start(ProbeIntent(probe: probe, label: "a"), environment: env, policy: .queue)
        host?.start(ProbeIntent(probe: probe, label: "b", delay: .milliseconds(10)), environment: env, policy: .queue)
        host?.start(ProbeIntent(probe: probe, label: "c", delay: .milliseconds(10)), environment: env, policy: .queue)
        #expect(await waitFor { probe.started == ["a"] })

        host = nil
        #expect(await waitFor { probe.cancelled == ["a"] })
        await settle()

        #expect(probe.started == ["a"], "queued runs must not start after teardown")
        #expect(probe.finished.isEmpty)
    }

    @Test("cancel() stops the run in flight and drops the queued ones")
    func cancelDropsQueuedRuns() async {
        let owner = IntentTaskOwner()
        let probe = Probe()

        owner.start(policy: .queue) { _ = try? await probeRun(probe, "a", .seconds(30)) }
        owner.start(policy: .queue) { _ = try? await probeRun(probe, "b", .milliseconds(10)) }
        #expect(await waitFor { probe.started == ["a"] })

        owner.cancel()
        #expect(await waitFor { !owner.isRunning })
        await settle()

        #expect(probe.started == ["a"])
        #expect(probe.cancelled == ["a"])
    }

    @Test("A queued run still starts after the previous one finishes")
    func queueStillRunsInOrder() async {
        let owner = IntentTaskOwner()
        let probe = Probe()

        owner.start(policy: .queue) { _ = try? await probeRun(probe, "a", .milliseconds(30)) }
        owner.start(policy: .queue) { _ = try? await probeRun(probe, "b", .milliseconds(10)) }

        #expect(await waitFor { probe.finished == ["a", "b"] })
        #expect(await waitFor { !owner.isRunning })
    }
}

// MARK: - Supersession

@MainActor
@Suite("Superseded runs")
struct SupersessionTests {
    @Test("cancelAndRestart cancels a long-running run it replaces")
    func restartCancelsLongRunning() async {
        let probe = Probe()
        let host = IntentRunHost<String>()
        let env = EnvironmentValues()

        host.start(ProbeLongIntent(probe: probe, label: "old"), environment: env, policy: .cancelAndRestart)
        #expect(await waitFor { probe.started == ["old"] })
        host.start(ProbeLongIntent(probe: probe, label: "new", delay: .milliseconds(20)), environment: env, policy: .cancelAndRestart)

        #expect(await waitFor { probe.finished == ["new"] })
        #expect(await waitFor { probe.cancelled == ["old"] })
        #expect(await waitFor { host.executor.phase == .finished })
        #expect(await waitFor { !LongRunningIntentRegistry.shared.activeIdentifiers.contains("old") })
    }

    @Test("A new run on the same executor cancels a long-running run in flight, as task(id:) does")
    func newRunCancelsLongRunning() async {
        let probe = Probe()
        let executor = IntentExecutor<String>()

        // Each task stands in for one `task(id:)` body. SwiftUI cancels the old
        // body when the id changes; for a long-running intent that alone does
        // not stop the run, so the new run has to.
        let old = Task { @MainActor in
            await executor.perform(ProbeLongIntent(probe: probe, label: "old"), context: makeContext())
        }
        #expect(await waitFor { probe.started == ["old"] })
        old.cancel()

        let new = Task { @MainActor in
            await executor.perform(ProbeLongIntent(probe: probe, label: "new", delay: .milliseconds(20)), context: makeContext())
        }
        await old.value
        await new.value

        #expect(probe.cancelled == ["old"])
        #expect(probe.finished == ["new"])
        #expect(executor.phase == .finished)
        #expect(executor.state.value == "new")
    }

    @Test("A long-running run still outlives the view when nothing replaces it")
    func teardownLeavesLongRunningAlone() async {
        let probe = Probe()
        let executor = IntentExecutor<String>()

        let task = Task { @MainActor in
            await executor.perform(ProbeLongIntent(probe: probe, label: "save", delay: .milliseconds(150)), context: makeContext())
        }
        #expect(await waitFor { probe.started == ["save"] })
        task.cancel()
        await task.value

        #expect(probe.finished == ["save"])
        #expect(probe.cancelled.isEmpty)
    }
}

// MARK: - Handle binding

@MainActor
@Suite("Handle binding across runs")
struct HandleBindingTests {
    @Test("An old run that finishes late leaves the handle bound to its replacement")
    func lateFinishKeepsReplacementBound() async {
        let probe = Probe()
        let executor = IntentExecutor<String>()
        let handle = IntentHandle<ProbeIntent>()

        let old = Task { @MainActor in
            await executor.perform(ProbeIntent(probe: probe, label: "old"), context: makeContext(), handle: handle)
        }
        #expect(await waitFor { probe.started == ["old"] })

        let new = Task { @MainActor in
            await executor.perform(ProbeIntent(probe: probe, label: "new"), context: makeContext(), handle: handle)
        }
        #expect(await waitFor { probe.started == ["old", "new"] })

        // The old run finishes after the new one has bound the handle.
        old.cancel()
        await old.value

        handle.cancel()
        let stopped = await waitFor(.seconds(5)) { probe.cancelled.contains("new") }
        #expect(stopped, "the handle no longer reached the run in flight")
        await new.value

        #expect(probe.finished.isEmpty)
        #expect(executor.phase == .cancelled)
    }

    @Test("Unbinding an older run does not unbind a newer one")
    func unbindIsScopedToTheRun() {
        let handle = IntentHandle<ProbeIntent>()
        var cancelled: [String] = []
        let first = UUID()
        let second = UUID()

        handle.bind(run: first) { _ in cancelled.append("first") }
        handle.bind(run: second) { _ in cancelled.append("second") }
        handle.unbind(run: first)
        handle.cancel()

        #expect(cancelled == ["second"])

        handle.unbind(run: second)
        handle.cancel()
        #expect(cancelled == ["second"])
    }
}

// MARK: - Event delivery

@MainActor
@Suite("Event delivery")
struct EventDeliveryTests {
    private func events(source: UUID, _ range: ClosedRange<Int>) -> [IntentEvent] {
        range.map {
            IntentEvent(
                source: source,
                sequence: $0,
                intentType: ObjectIdentifier(ProbeIntent.self),
                identifier: "\(source)-\($0)",
                kind: .phase(.running)
            )
        }
    }

    @Test("A quiet executor's events are not delivered again however busy a sibling is")
    func quietSiblingIsNotReplayed() {
        let delivered = DeliveredIntentEvents()
        let quiet = UUID()
        let busy = UUID()
        let quietWindow = events(source: quiet, 1...32)

        #expect(delivered.fresh(quietWindow).count == 32)

        // The busy executor publishes its last 32 events on every update, and
        // the quiet one keeps publishing the same 32.
        var replayed = 0
        var busyDelivered = 0
        for newest in 1...2_000 {
            let window = events(source: busy, max(1, newest - 31)...newest)
            let fresh = delivered.fresh(quietWindow + window)
            replayed += fresh.filter { $0.source == quiet }.count
            busyDelivered += fresh.count
        }

        #expect(replayed == 0)
        #expect(busyDelivered == 2_000)
    }

    @Test("Republished events are delivered once and new ones are delivered in order")
    func deliversEachEventOnce() {
        let delivered = DeliveredIntentEvents()
        let source = UUID()

        #expect(delivered.fresh(events(source: source, 1...3)).map(\.sequence) == [1, 2, 3])
        #expect(delivered.fresh(events(source: source, 1...3)).isEmpty)
        #expect(delivered.fresh(events(source: source, 2...5)).map(\.sequence) == [4, 5])
    }

    @Test("Executors that left the tree are forgotten, live ones are kept")
    func forgetsDepartedExecutors() {
        let delivered = DeliveredIntentEvents()
        let live = UUID()
        let liveWindow = events(source: live, 1...4)
        _ = delivered.fresh(liveWindow)

        for _ in 0..<400 {
            _ = delivered.fresh(liveWindow + events(source: UUID(), 1...1))
        }

        #expect(delivered.fresh(liveWindow).isEmpty)
    }
}
