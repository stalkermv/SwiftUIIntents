import SwiftUI
import Testing
@_spi(Testing) @testable import SwiftUIIntents

// MARK: - Fixtures

@MainActor
private final class Counter {
    var runs = 0
    var finished = 0
    var reasons: [IntentCancellationReason] = []
    var values: [String] = []
}

private struct StepIntent: Intent {
    let counter: Counter
    let label: String
    var delay: Duration = .milliseconds(150)

    func perform(context: Context) async throws -> String {
        counter.runs += 1
        try await Task.sleep(for: delay)
        counter.finished += 1
        return label
    }

    var identifier: String { label }
}

private struct SlowLongIntent: LongRunningIntent {
    let counter: Counter

    func perform(context: Context) async throws -> String {
        counter.runs += 1
        try await Task.sleep(for: .milliseconds(200))
        counter.finished += 1
        return "long"
    }
}

private struct CleanupIntent: CancellableIntent {
    let counter: Counter

    func perform(context: Context) async throws -> String {
        let counter = counter
        return try await withIntentCancellationHandler {
            try await Task.sleep(for: .seconds(5))
            return "never"
        } onCancel: { reason in
            Task { @MainActor in counter.reasons.append(reason) }
        }
    }
}

private struct ReportingIntent: ProgressReportingIntent {
    let progress = Progress(totalUnitCount: 10)

    func perform(context: Context) async throws -> String {
        progress.completedUnitCount = 10
        return "reported"
    }
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

// MARK: - Handle, phases and cancellation

@MainActor
struct HandleAndPhaseTests {
    @Test("A handle that never ran cancels nothing")
    func idleHandleIsInert() {
        let handle = IntentHandle<StepIntent>()
        handle.cancel()
    }

    @Test("A run moves through running to finished and reports its value")
    func phasesOfASuccessfulRun() async {
        let counter = Counter()
        let executor = IntentExecutor<String>()
        await executor.perform(StepIntent(counter: counter, label: "ok", delay: .milliseconds(1)), context: makeContext())

        #expect(executor.phase == .finished)
        let phases = executor.events.compactMap { event -> IntentPhase? in
            if case .phase(let phase) = event.kind { return phase } else { return nil }
        }
        #expect(phases == [.running, .finished])
        let values = executor.events.compactMap { event -> String? in
            if case .value(let value) = event.kind { return value as? String } else { return nil }
        }
        #expect(values == ["ok"])
    }

    @Test("A handle cancels the run in flight and the phase is cancelled, not failed")
    func handleCancelsRun() async {
        let counter = Counter()
        let executor = IntentExecutor<String>()
        let handle = IntentHandle<StepIntent>()
        let intent = StepIntent(counter: counter, label: "slow", delay: .seconds(5))

        let task = Task { @MainActor in
            await executor.perform(intent, context: makeContext(), handle: handle)
        }
        #expect(await waitFor { executor.phase == .running })

        handle.cancel()
        await task.value

        #expect(executor.phase == .cancelled)
        #expect(executor.state.error == nil)
        #expect(counter.finished == 0)
    }

    @Test("The cancellation reason is user-cancelled for a handle and view-disappeared otherwise")
    func cancellationReasons() async {
        let counter = Counter()
        let handle = IntentHandle<CleanupIntent>()
        let executor = IntentExecutor<String>()

        let byHandle = Task { @MainActor in
            await executor.perform(CleanupIntent(counter: counter), context: makeContext(), handle: handle)
        }
        #expect(await waitFor { executor.phase == .running })
        try? await Task.sleep(for: .milliseconds(50))
        handle.cancel()
        await byHandle.value
        #expect(await waitFor { counter.reasons.count == 1 })

        let other = IntentExecutor<String>()
        let byView = Task { @MainActor in
            await other.perform(CleanupIntent(counter: counter), context: makeContext())
        }
        #expect(await waitFor { other.phase == .running })
        try? await Task.sleep(for: .milliseconds(50))
        byView.cancel()
        await byView.value
        #expect(await waitFor { counter.reasons.count == 2 })

        #expect(counter.reasons == [.userCancelled, .viewDisappeared])
    }

    @Test("A progress-reporting intent hands over its Progress object")
    func progressEvent() async {
        let executor = IntentExecutor<String>()
        let intent = ReportingIntent()
        await executor.perform(intent, context: makeContext())

        let progress = executor.events.compactMap { event -> Progress? in
            if case .progress(let progress) = event.kind { return progress } else { return nil }
        }
        #expect(progress.count == 1)
        #expect(progress.first === intent.progress)
    }
}

// MARK: - Long-running intents

@MainActor
struct LongRunningTests {
    @Test("A plain intent is cancelled with the task that runs it")
    func plainIntentIsCancelled() async {
        let counter = Counter()
        let executor = IntentExecutor<String>()
        let task = Task { @MainActor in
            await executor.perform(StepIntent(counter: counter, label: "plain", delay: .milliseconds(300)), context: makeContext())
        }
        #expect(await waitFor { counter.runs == 1 })
        task.cancel()
        await task.value

        #expect(counter.finished == 0)
        #expect(executor.phase == .cancelled)
    }

    @Test("A long-running intent finishes after the task that runs it is cancelled")
    func longRunningSurvives() async {
        let counter = Counter()
        let executor = IntentExecutor<String>()
        let task = Task { @MainActor in
            await executor.perform(SlowLongIntent(counter: counter), context: makeContext())
        }
        #expect(await waitFor { counter.runs == 1 })
        #expect(LongRunningIntentRegistry.shared.activeIdentifiers.contains("SlowLongIntent"))

        task.cancel()
        await task.value

        #expect(counter.finished == 1)
        #expect(executor.phase == .finished)
        #expect(LongRunningIntentRegistry.shared.activeIdentifiers.isEmpty)
    }

    @Test("A handle still cancels a long-running intent")
    func handleCancelsLongRunning() async {
        let counter = Counter()
        let executor = IntentExecutor<String>()
        let handle = IntentHandle<SlowLongIntent>()
        let task = Task { @MainActor in
            await executor.perform(SlowLongIntent(counter: counter), context: makeContext(), handle: handle)
        }
        #expect(await waitFor { counter.runs == 1 })
        task.cancel()      // the view goes away: the run is not cancelled
        handle.cancel()    // the user cancels: it is
        await task.value

        #expect(counter.finished == 0)
        #expect(executor.phase == .cancelled)
    }
}

// MARK: - Re-entry policies

@MainActor
struct ReentryPolicyTests {
    @Test("ignore drops a trigger while a run is in flight")
    func ignorePolicy() async {
        let counter = Counter()
        let host = IntentRunHost<String>()
        let env = EnvironmentValues()

        host.start(StepIntent(counter: counter, label: "a"), environment: env, policy: .ignore)
        host.start(StepIntent(counter: counter, label: "b"), environment: env, policy: .ignore)
        #expect(await waitFor { counter.finished == 1 })
        try? await Task.sleep(for: .milliseconds(100))

        #expect(counter.runs == 1)
    }

    @Test("cancelAndRestart cancels the run in flight and runs the new one")
    func restartPolicy() async {
        let counter = Counter()
        let host = IntentRunHost<String>()
        let env = EnvironmentValues()

        host.start(StepIntent(counter: counter, label: "a", delay: .seconds(5)), environment: env, policy: .cancelAndRestart)
        #expect(await waitFor { counter.runs == 1 })
        host.start(StepIntent(counter: counter, label: "b", delay: .milliseconds(20)), environment: env, policy: .cancelAndRestart)
        #expect(await waitFor { counter.finished == 1 })

        #expect(counter.runs == 2)
        #expect(await waitFor { host.executor.phase == .finished })
    }

    @Test("queue runs the second after the first")
    func queuePolicy() async {
        let counter = Counter()
        let host = IntentRunHost<String>()
        let env = EnvironmentValues()

        host.start(StepIntent(counter: counter, label: "a", delay: .milliseconds(80)), environment: env, policy: .queue)
        host.start(StepIntent(counter: counter, label: "b", delay: .milliseconds(80)), environment: env, policy: .queue)
        #expect(await waitFor { counter.finished == 2 })

        #expect(counter.runs == 2)
    }

    @Test("Releasing the owner cancels the run")
    func ownerReleaseCancels() async {
        let counter = Counter()
        var host: IntentRunHost<String>? = IntentRunHost<String>()
        host?.start(StepIntent(counter: counter, label: "a", delay: .seconds(5)), environment: EnvironmentValues(), policy: .ignore)
        #expect(await waitFor { counter.runs == 1 })

        host = nil
        try? await Task.sleep(for: .milliseconds(100))

        #expect(counter.finished == 0)
    }
}

// MARK: - Triggers in a hosted view

@MainActor
private final class HookLog {
    var values: [String] = []
    var phases: [IntentPhase] = []
    var errors: [String] = []
    var cleared: [String] = []
}

private struct HookHarness: View {
    let log: HookLog
    let id: Int
    let counter: Counter

    var body: some View {
        Text("host")
            .task(id: id, StepIntent(counter: counter, label: "row-\(id)", delay: .milliseconds(20)))
            .onChangeIntentValue(of: StepIntent.self) { value, identifier in
                log.values.append("\(identifier)=\(value)")
            }
            .onChangeIntentPhase(of: StepIntent.self) { phase, _ in
                log.phases.append(phase)
            }
    }
}

@MainActor
struct HostedTriggerTests {
    @Test("task(_:) runs on appear and the value hook receives the result with the identifier")
    func taskRunsAndReports() async {
        let log = HookLog()
        let counter = Counter()

        await withHostedView(HookHarness(log: log, id: 1, counter: counter)) { handle in
            let arrived = await hostedWait(handle) { log.values == ["row-1=row-1"] }
            #expect(arrived, "values were \(log.values)")
            #expect(counter.runs == 1)
            #expect(log.phases.contains(.running) && log.phases.contains(.finished))
        }
    }

    @Test("Several intents of one type are told apart by identifier")
    func identifiersTellIntentsApart() async {
        let log = HookLog()
        let counter = Counter()

        await withHostedView(
            VStack {
                Text("a").task(StepIntent(counter: counter, label: "first", delay: .milliseconds(10)))
                Text("b").task(StepIntent(counter: counter, label: "second", delay: .milliseconds(10)))
            }
            .onChangeIntentValue(of: StepIntent.self) { _, identifier in
                log.values.append(identifier)
            }
        ) { handle in
            let arrived = await hostedWait(handle) { Set(log.values) == ["first", "second"] }
            #expect(arrived, "identifiers were \(log.values)")
        }
    }
}

@MainActor
private func hostedWait(_ handle: HostedHandle, _ condition: @MainActor () -> Bool) async -> Bool {
    let deadline = ContinuousClock.now + .seconds(20)
    while ContinuousClock.now < deadline {
        if condition() { return true }
        await handle.render()
        try? await Task.sleep(for: .milliseconds(20))
    }
    return condition()
}

// MARK: - Shapes that must compile

@MainActor
struct OverloadShapeTests {
    @Test("The overloads accept an intent value and a builder next to SwiftUI's own")
    func overloadsCompile() {
        let counter = Counter()
        let intent = StepIntent(counter: counter, label: "x")

        _ = Text("x")
            .onSubmit(of: .text, intent)
            .onSubmit { }
            .onSubmit(of: .search, policy: .queue, intent)
            .task(intent)
            .task(id: 1, intent)
            .onOpenURL { url in StepIntent(counter: counter, label: url.absoluteString) }
            .onOpenURL { _ in }
            .onContinueUserActivity("x") { _ in StepIntent(counter: counter, label: "activity") }
            .onDisappear(SlowLongIntent(counter: counter))
            .onDisappear { }

        _ = IntentToggle(isOn: false, { _ in intent }) { Text("Toggle") }
        _ = IntentButton(intent, role: .destructive, mode: .hide, handle: IntentHandle<StepIntent>()) { Text("Run") }
        _ = IntentButton(intent) { Text("Run") }
        _ = Text("x").onChange(of: 1, initial: true, trigger: intent, handle: IntentHandle<StepIntent>())

        #if !os(tvOS)
        _ = Text("x").refreshable(intent)
        #endif
        #if os(iOS) || os(macOS) || os(visionOS)
        _ = Text("x").fileImporter(
            isPresented: .constant(false),
            allowedContentTypes: [],
            allowsMultipleSelection: true
        ) { _ in intent }
        #endif
    }
}
