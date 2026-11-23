import Combine
import SwiftUI
import Testing
import ViewInspector
@_spi(Testing) @testable import SwiftUIIntents

@MainActor
struct SwiftUIIntentsTests {
    @Test("IntentExecutor stores successful results")
    func executorStoresSuccess() async throws {
        let executor = IntentExecutor<String>()
        await executor.perform(ConstantIntent(value: "done"), context: makeContext())

        guard case .success(let value) = executor.state else {
            Issue.record("Expected success state")
            return
        }

        #expect(value == "done")
        #expect(executor.latestErrorEvent == nil)
    }

    @Test("IntentExecutor stores failures and emits unique error events")
    func executorEmitsUniqueErrorEvents() async throws {
        let executor = IntentExecutor<String>()
        let intent: any Intent<String> = FailingIntent()

        await executor.perform(intent, context: makeContext())
        guard let firstEvent = executor.latestErrorEvent else {
            Issue.record("Expected first error event")
            return
        }

        guard case .failure(let firstError) = executor.state else {
            Issue.record("Expected failure state after first run")
            return
        }

        #expect(firstError.localizedDescription == SampleError.sameMessage.localizedDescription)

        await executor.perform(intent, context: makeContext())
        guard let secondEvent = executor.latestErrorEvent else {
            Issue.record("Expected second error event")
            return
        }

        guard case .failure(let secondError) = executor.state else {
            Issue.record("Expected failure state after second run")
            return
        }

        #expect(secondError.localizedDescription == SampleError.sameMessage.localizedDescription)
        #expect(firstEvent.id != secondEvent.id)
    }

    @Test("IntentExecutor installs the intent context for the intent it performs")
    func executorInstallsIntentContext() async throws {
        // Exercises `IntentExecutor.perform(_:context:)` directly. Installing the
        // context used to live one level up in `IntentBinding.perform(_:)`, so
        // anything reaching the executor another way — every executor test in
        // this file, and any future caller — trapped inside `@IntentContext` and
        // took the whole test process down with it instead of failing one test.
        let executor = IntentExecutor<String>()
        var environment = EnvironmentValues()
        environment.locale = Locale(identifier: "uk_UA")
        let context = IntentContextContainer(environment: environment)

        await executor.perform(ContextAwareIntent(), context: context)

        guard case .success(let value) = executor.state else {
            Issue.record("Expected success state, got \(executor.state)")
            return
        }

        #expect(value == "uk_UA")
    }

    @Test("IntentBinding performs intents with service context")
    func intentBindingPerformsWithServiceContext() async throws {
        let executor = IntentExecutor<String>()
        var environment = EnvironmentValues()
        environment.locale = Locale(identifier: "uk_UA")
        let binding = IntentBinding(
            executor: executor,
            intent: ContextAwareIntent(),
            environment: environment
        )

        await binding.perform()

        guard case .success(let value) = executor.state else {
            Issue.record("Expected success state")
            return
        }

        #expect(value == "uk_UA")
    }

    @Test("IntentBinding can perform a supplied dynamic intent")
    func intentBindingPerformsSuppliedIntent() async throws {
        let executor = IntentExecutor<String>()
        let binding = IntentBinding<String>(
            executor: executor,
            intent: nil,
            environment: EnvironmentValues()
        )

        await binding.perform(ConstantIntent(value: "dynamic"))

        guard case .success(let value) = executor.state else {
            Issue.record("Expected success state")
            return
        }

        #expect(value == "dynamic")
    }

    @Test("IntentPicker overloads compile")
    func intentPickerOverloadsCompile() {
        let selection = "automatic"

        _ = IntentPicker(selection, { _ in ConstantIntent(value: "done") }, label: Text("Mode")) {
            Text("Automatic").tag("automatic")
        }

        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            _ = IntentPicker(selection, { _ in ConstantIntent(value: "done") }, label: Text("Mode")) {
                Text("Automatic").tag("automatic")
            } currentValueLabel: {
                Text("Automatic")
            }
        }
    }

    @Test("Repeated equal errors stay equal for change-based observation")
    func changeBasedErrorObservationCoalescesEqualErrors() {
        let first = IntentErrorPreferenceKey.EquatableError(SampleError.sameMessage)
        let second = IntentErrorPreferenceKey.EquatableError(SampleError.sameMessage)

        #expect(first == second)
    }

    @Test("Event-based error observation treats repeated equal errors as distinct events")
    func eventBasedErrorObservationKeepsRepeatedErrorsDistinct() {
        let first = IntentErrorEvent(error: SampleError.sameMessage)
        let second = IntentErrorEvent(error: SampleError.sameMessage)

        #expect(first != second)
        #expect(first.error.localizedDescription == second.error.localizedDescription)
    }

    @Test("Combined intent executes sequentially")
    func combinedIntentExecutesSequentially() async throws {
        let intent = ConstantIntent(value: "first").combined(with: ConstantIntent(value: "second"))
        let result = try await _TestingIntentExecutor(intent, environment: EnvironmentValues()).run()

        #expect(result.0 == "first")
        #expect(result.1 == "second")
    }

    @Test("Simultaneous combined intent executes concurrently")
    func simultaneousCombinedIntentExecutesConcurrently() async throws {
        let intent = ConstantIntent(value: "left").combined(simultaneously: ConstantIntent(value: "right"))
        let result = try await _TestingIntentExecutor(intent, environment: EnvironmentValues()).run()

        #expect(result.0 == "left")
        #expect(result.1 == "right")
    }

    @Test("onReceiveIntentError emits every repeated failure")
    func receiveIntentErrorEmitsEveryRepeatedFailure() async throws {
        let recorder = ErrorRecorder()
        let model = ErrorPreferenceModel()
        let view = ErrorObservationHarness(model: model, recorder: recorder)

        ViewHosting.host(view: view)
        defer { ViewHosting.expel() }

        model.emitSameError()
        let firstEmissionArrived = await waitUntil {
            recorder.receivedErrors.count == 1
        }

        #expect(firstEmissionArrived)
        #expect(recorder.receivedErrors == [SampleError.sameMessage.localizedDescription])

        model.emitSameError()
        let secondEmissionArrived = await waitUntil {
            recorder.receivedErrors.count == 2
        }

        #expect(secondEmissionArrived)
        #expect(
            recorder.receivedErrors
                == [
                    SampleError.sameMessage.localizedDescription,
                    SampleError.sameMessage.localizedDescription
                ]
        )
        #expect(recorder.changedErrors == [SampleError.sameMessage.localizedDescription])
    }

    @Test("onChange(of:trigger:) executes when observed input changes")
    func onChangeTriggerExecutesIntent() async throws {
        let model = TriggerModel()
        let recorder = TriggerRecorder()
        let view = TriggerHarness(model: model, recorder: recorder)

        ViewHosting.host(view: view)
        defer { ViewHosting.expel() }

        let initialExecutionArrived = await waitUntil {
            recorder.count == 1
        }

        #expect(initialExecutionArrived)

        model.value = 1

        let secondExecutionArrived = await waitUntil {
            recorder.count == 2
        }

        #expect(secondExecutionArrived)
    }

    private func makeContext() -> IntentContextContainer {
        IntentContextContainer(environment: EnvironmentValues())
    }
}

@MainActor
private final class ErrorRecorder {
    var changedErrors: [String] = []
    var receivedErrors: [String] = []
}

@MainActor
private struct ErrorObservationHarness: View {
    @ObservedObject var model: ErrorPreferenceModel
    let recorder: ErrorRecorder

    var body: some View {
        Text("Run")
        .preference(key: IntentErrorPreferenceKey.self, value: model.changeError)
        .preference(key: IntentErrorEventPreferenceKey.self, value: model.errorEvent)
        .onChangeIntentError { error in
            if let error {
                recorder.changedErrors.append(error.localizedDescription)
            }
        }
        .onReceiveIntentError { error in
            recorder.receivedErrors.append(error.localizedDescription)
        }
    }
}

@MainActor
private final class ErrorPreferenceModel: ObservableObject {
    @Published private(set) var changeError: IntentErrorPreferenceKey.EquatableError?
    @Published private(set) var errorEvent: IntentErrorEvent?

    func emitSameError() {
        changeError = .init(SampleError.sameMessage)
        errorEvent = .init(error: SampleError.sameMessage)
    }
}

@MainActor
private final class TriggerRecorder {
    var count = 0

    func increment() {
        count += 1
    }
}

@MainActor
private final class TriggerModel: ObservableObject {
    @Published var value = 0
}

@MainActor
private struct TriggerHarness: View {
    @ObservedObject var model: TriggerModel
    let recorder: TriggerRecorder

    var body: some View {
        Text("Trigger \(model.value)")
            .onChange(of: model.value, trigger: CountingIntent(recorder: recorder))
    }
}

private struct ConstantIntent: Intent {
    let value: String

    func perform(context: Context) async throws -> String {
        value
    }
}

private struct FailingIntent: Intent {
    func perform(context: Context) async throws -> String {
        throw SampleError.sameMessage
    }
}

private struct ContextAwareIntent: Intent {
    @IntentContext private var intentContext

    func perform(context _: Context) async throws -> String {
        intentContext.locale.identifier
    }
}

private struct CountingIntent: Intent {
    let recorder: TriggerRecorder

    func perform(context _: Context) async throws -> String {
        recorder.increment()
        return "done"
    }
}

private enum SampleError: LocalizedError, Sendable {
    case sameMessage

    var errorDescription: String? {
        "The operation failed."
    }
}

@MainActor
private final class RenderCounter {
    var bodyEvaluations = 0
}

@MainActor
private final class RenderTick: ObservableObject {
    @Published var value = 0
}

@MainActor
private struct RenderProbe: View {
    @ObservedObject var tick: RenderTick
    let counter: RenderCounter

    var body: some View {
        counter.bodyEvaluations += 1
        return Text("tick \(tick.value)")
    }
}

@MainActor
struct HostedViewHarnessTests {
    @Test("Hosting re-evaluates body when observed state changes")
    func harnessReRenders() async throws {
        let tick = RenderTick()
        let counter = RenderCounter()

        await withHostedView(RenderProbe(tick: tick, counter: counter)) { handle in
            let initial = counter.bodyEvaluations
            #expect(initial >= 1, "the view should have rendered at least once when mounted")

            tick.value = 1
            await handle.render()

            #expect(
                counter.bodyEvaluations > initial,
                "changing observed state must re-evaluate body; got \(counter.bodyEvaluations) vs \(initial)"
            )
        }
    }
}

@MainActor
struct TestingExecutorContextTests {
    @Test("_TestingIntentExecutor supplies @IntentContext")
    func testingExecutorSuppliesContext() async throws {
        var environment = EnvironmentValues()
        environment.locale = Locale(identifier: "uk_UA")

        let executor = _TestingIntentExecutor(ContextAwareIntent(), environment: environment)
        let result = try await executor.run()

        #expect(result == "uk_UA")
    }
}

private struct SlowIntent: Intent {
    /// Signalled on entry, immediately before the long sleep, so a test can
    /// cancel at a moment when the intent is *known* to be running instead of
    /// guessing with a wall-clock sleep.
    let didStart: AsyncStream<Void>.Continuation

    func perform(context: Context) async throws -> String {
        didStart.yield()
        didStart.finish()
        try await Task.sleep(nanoseconds: 5_000_000_000)
        return "never"
    }
}

@MainActor
struct CancellationTests {
    @Test("A cancelled intent is not reported as a failure")
    func cancellationIsNotAFailure() async throws {
        let executor = IntentExecutor<String>()
        let (didStart, didStartContinuation) = AsyncStream<Void>.makeStream()
        let intent: any Intent<String> = SlowIntent(didStart: didStartContinuation)
        let context = IntentContextContainer(environment: EnvironmentValues())

        let task = Task { @MainActor in
            await executor.perform(intent, context: context)
        }

        // Wait for the intent to say it is inside `perform` rather than sleeping
        // for a guessed interval: under load a fixed sleep can elapse before the
        // intent ever starts, and the test would then cancel nothing and pass
        // vacuously. The 5 s sleep below the signal guarantees the intent cannot
        // finish on its own, so the only way out is cancellation.
        var didStartIterator = didStart.makeAsyncIterator()
        let started: Void? = await didStartIterator.next()
        try #require(started != nil, "SlowIntent never entered perform(context:), so nothing was cancelled")

        task.cancel()
        _ = await task.value

        #expect(executor.latestErrorEvent == nil, "cancellation must not emit a user-facing error event")

        // Assert the state positively. A cancelled run must land on `.idle`;
        // `.success("never")` would mean cancellation stopped propagating and
        // the intent ran to completion, and `.failure` would mean cancellation
        // is being reported to the user again.
        guard case .idle = executor.state else {
            Issue.record("a cancelled intent must leave the executor in .idle, got \(executor.state)")
            return
        }
    }
}

@MainActor
struct PreferenceReduceTests {
    @Test("An idle sibling does not erase a failing sibling's error event")
    func idleSiblingPreservesFailure() {
        let failingChild = IntentErrorEvent(error: SampleError.sameMessage)
        let idleChild: IntentErrorEvent? = nil

        var value = IntentErrorEventPreferenceKey.defaultValue
        IntentErrorEventPreferenceKey.reduce(value: &value) { failingChild }
        IntentErrorEventPreferenceKey.reduce(value: &value) { idleChild }

        #expect(value?.id == failingChild.id, "folding [failed, idle] must keep the failure")
    }

    @Test("An idle sibling does not erase a failing sibling's error state")
    func idleSiblingPreservesErrorState() {
        // Build both children the way IntentButton and IntentPicker publish them:
        // `.preference(key: IntentErrorPreferenceKey.self, value: .init(binding.error))`,
        // where `binding.error` is an `Error?`. Folding a hand-written `nil` here
        // would test a value the view tree never emits.
        let failingChildError: Error? = SampleError.sameMessage
        let idleChildError: Error? = nil
        let failing: IntentErrorPreferenceKey.Value = .init(failingChildError)
        let idle: IntentErrorPreferenceKey.Value = .init(idleChildError)

        #expect(failing != nil, "a failing child must publish a value")
        #expect(idle == nil, "an idle child must publish nil, not a wrapper around a nil error")

        var value = IntentErrorPreferenceKey.defaultValue
        IntentErrorPreferenceKey.reduce(value: &value) { failing }
        IntentErrorPreferenceKey.reduce(value: &value) { idle }

        #expect(value?.error != nil, "folding [failed, idle] must keep the failure")
    }

    @Test("A later failure still replaces an earlier one")
    func laterFailureWins() {
        let first = IntentErrorEvent(error: SampleError.sameMessage)
        let second = IntentErrorEvent(error: SampleError.sameMessage)

        var value = IntentErrorEventPreferenceKey.defaultValue
        IntentErrorEventPreferenceKey.reduce(value: &value) { first }
        IntentErrorEventPreferenceKey.reduce(value: &value) { second }

        #expect(value?.id == second.id, "a real later event must still win")
    }
}

@MainActor
private final class ExecutorIdentityRecorder {
    var seen: [ObjectIdentifier] = []
    var latestValues: [String?] = []
}

@MainActor
private final class ReRenderTick: ObservableObject {
    @Published var value = 0
}

// The probe must be RECONSTRUCTED by a parent, not merely re-evaluated.
// C1 lives in `IntentState.init`: `@Bindable` has no SwiftUI storage, so a new
// executor appears each time the enclosing view value is built. If the probe is
// the host's root view and observes the tick itself, SwiftUI re-runs its `body`
// on the existing value, `init` never runs again, and the bug does not appear —
// the test would pass against the very code it is meant to catch.
@MainActor
private struct ExecutorIdentityProbe: View {
    let tick: Int
    let recorder: ExecutorIdentityRecorder
    @IntentState private var result: String?

    init(tick: Int, recorder: ExecutorIdentityRecorder) {
        self.tick = tick
        self.recorder = recorder
        self._result = IntentState(ConstantIntent(value: "done"))
    }

    var body: some View {
        recorder.seen.append($result.executorIdentity)
        recorder.latestValues.append(result)
        return Text("tick \(tick)")
    }
}

@MainActor
private struct ExecutorIdentityParent: View {
    @ObservedObject var tick: ReRenderTick
    let recorder: ExecutorIdentityRecorder

    var body: some View {
        // Rebuilt on every evaluation of this body — the real-world shape.
        ExecutorIdentityProbe(tick: tick.value, recorder: recorder)
    }
}

@MainActor
struct ExecutorLifetimeTests {
    @Test("The executor survives a parent re-render")
    func executorSurvivesReRender() async throws {
        let tick = ReRenderTick()
        let recorder = ExecutorIdentityRecorder()

        await withHostedView(ExecutorIdentityParent(tick: tick, recorder: recorder)) { handle in
            for i in 1...3 {
                tick.value = i
                await handle.render()
            }
        }

        #expect(recorder.seen.count >= 2, "need at least two renders to compare")
        #expect(
            Set(recorder.seen).count == 1,
            "the executor was rebuilt \(Set(recorder.seen).count) times across \(recorder.seen.count) renders"
        )
    }

    @Test("The latest result survives a parent re-render")
    func resultSurvivesReRender() async throws {
        let tick = ReRenderTick()
        let recorder = ExecutorIdentityRecorder()
        let performed = PerformGate()

        await withHostedView(
            ResultSurvivalParent(tick: tick, recorder: recorder, gate: performed)
        ) { handle in
            // Run the intent once, so there is a result to lose.
            await performed.runOnce()
            await handle.render()

            let afterRun = recorder.latestValues.last ?? nil
            #expect(afterRun == "done", "the intent should have produced a result; got \(String(describing: afterRun))")

            // Now make the parent rebuild the child.
            let renderedBefore = recorder.latestValues.count
            tick.value = 1
            await handle.render()

            // Without this the assertion below could re-read the very element the
            // one above already checked and pass having exercised nothing — the
            // guard `executorSurvivesReRender` gets from its `seen.count >= 2`.
            #expect(
                recorder.latestValues.count > renderedBefore,
                "the child was never rebuilt; this test proves nothing"
            )

            // Asserted inside the closure, while the host is still mounted. After
            // `withHostedView` returns the recorder can gain no further entry, so
            // a torn-down host would quietly hide a regression here.
            let afterReRender = recorder.latestValues.last ?? nil
            #expect(
                afterReRender == "done",
                "the result did not survive the parent re-render; got \(String(describing: afterReRender))"
            )
        }
    }
}

/// Lets the test trigger one execution through the binding, which is the
/// supported path — production code never calls `perform` on an intent.
@MainActor
private final class PerformGate {
    var run: (() async -> Void)?

    func runOnce() async {
        await run?()
    }
}

@MainActor
private struct ResultSurvivalProbe: View {
    let tick: Int
    let recorder: ExecutorIdentityRecorder
    let gate: PerformGate
    @IntentState private var result: String?

    init(tick: Int, recorder: ExecutorIdentityRecorder, gate: PerformGate) {
        self.tick = tick
        self.recorder = recorder
        self.gate = gate
        self._result = IntentState(ConstantIntent(value: "done"))
    }

    var body: some View {
        recorder.seen.append($result.executorIdentity)
        recorder.latestValues.append(result)
        let binding = $result
        gate.run = { await binding.perform() }
        return Text("tick \(tick)")
    }
}

@MainActor
private struct ResultSurvivalParent: View {
    @ObservedObject var tick: ReRenderTick
    let recorder: ExecutorIdentityRecorder
    let gate: PerformGate

    var body: some View {
        ResultSurvivalProbe(tick: tick.value, recorder: recorder, gate: gate)
    }
}

@MainActor
private final class ButtonErrorRecorder {
    var changedErrors: [String] = []
    var receivedErrors: [String] = []
}

/// Two `IntentButton`s side by side — the shape the sibling-erasure defect
/// actually appears in, and the one `IntentButtonWrapper.body` is only exercised
/// by when it is really mounted.
///
/// The failing button is built on a binding the test owns, so the test can drive
/// exactly what the button's own action does. The other is never touched: it
/// stays idle, publishes nothing to either preference key, and must not erase
/// its sibling's failure as SwiftUI folds the two children.
@MainActor
private struct TwoButtonHarness: View {
    let failingBinding: IntentBinding<String>
    let recorder: ButtonErrorRecorder

    var body: some View {
        HStack {
            IntentButton(failingBinding) {
                Text("fail")
            }
            IntentButton(ConstantIntent(value: "ok")) {
                Text("idle")
            }
        }
        .onChangeIntentError { error in
            if let error {
                recorder.changedErrors.append(error.localizedDescription)
            }
        }
        .onReceiveIntentError { error in
            recorder.receivedErrors.append(error.localizedDescription)
        }
    }
}

/// Renders until `condition` holds, or the deadline passes.
///
/// Preference delivery is asynchronous: publishing a new value schedules the
/// `onPreferenceChange` callback rather than running it inline, so a test has to
/// keep pumping the host rather than assert straight after the mutation.
@MainActor
private func renderUntil(
    _ handle: HostedHandle,
    timeout: Duration = .seconds(2),
    _ condition: @MainActor () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout

    while ContinuousClock.now < deadline {
        if condition() {
            return true
        }
        await handle.render()
        await Task.yield()
    }

    return condition()
}

@MainActor
struct IntentButtonTests {
    @Test("A failing IntentButton reports its error past an idle sibling")
    func failingButtonReportsErrorPastIdleSibling() async throws {
        let executor = IntentExecutor<String>()
        let binding = IntentBinding<String>(
            executor: executor,
            intent: FailingIntent(),
            environment: EnvironmentValues()
        )
        let recorder = ButtonErrorRecorder()

        await withHostedView(
            TwoButtonHarness(failingBinding: binding, recorder: recorder)
        ) { handle in
            #expect(recorder.changedErrors.isEmpty, "nothing has failed yet")
            #expect(recorder.receivedErrors.isEmpty, "nothing has failed yet")

            // `IntentButtonWrapper`'s action is `await intentBinding.perform()`.
            // Driving the same binding runs precisely that, without reaching
            // inside AsyncButton to synthesise a tap — which the harness
            // deliberately has no way to do.
            await binding.perform()

            let arrived = await renderUntil(handle) {
                !recorder.changedErrors.isEmpty && !recorder.receivedErrors.isEmpty
            }

            #expect(arrived, "the failing button's error never reached the handler on the container")
            #expect(
                recorder.changedErrors == [SampleError.sameMessage.localizedDescription],
                "onChangeIntentError saw \(recorder.changedErrors)"
            )
            #expect(
                recorder.receivedErrors == [SampleError.sameMessage.localizedDescription],
                "onReceiveIntentError saw \(recorder.receivedErrors)"
            )
        }
    }
}
