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

    @Test("IntentPicker overloads compile")
    func intentPickerOverloadsCompile() {
        let selection = "automatic"

        _ = IntentPicker(selection, { _ in ConstantIntent(value: "done") }, label: Text("Mode")) {
            Text("Automatic").tag("automatic")
        }

        if #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *) {
            _ = IntentPicker(selection, { _ in ConstantIntent(value: "done") }) {
                Text("Automatic").tag("automatic")
            } label: {
                Text("Mode")
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

    @Test("onChange(of:initial:trigger:) runs on appear only with initial, and again on change")
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
            .onChange(of: model.value, initial: true, trigger: CountingIntent(recorder: recorder))
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
private final class ReRenderTick: ObservableObject {
    @Published var value = 0
}

@MainActor
private struct TriggerLifetimeParent: View {
    @ObservedObject var tick: ReRenderTick
    let recorder: TriggerRecorder

    var body: some View {
        // The child is rebuilt on every evaluation of this body, the real-world
        // shape. Its trigger state has to live in SwiftUI storage, not in the value.
        Text("tick \(tick.value)")
            .onChange(of: "stable", initial: true, trigger: CountingIntent(recorder: recorder))
    }
}

@MainActor
struct TriggerLifetimeTests {
    @Test("A trigger keeps its state when the parent rebuilds it")
    func triggerStateSurvivesParentRebuild() async throws {
        let tick = ReRenderTick()
        let recorder = TriggerRecorder()

        await withHostedView(TriggerLifetimeParent(tick: tick, recorder: recorder)) { handle in
            let ranOnce = await renderUntil(handle) { recorder.count == 1 }
            #expect(ranOnce, "the trigger never ran on appear with initial: true")

            for i in 1...3 {
                tick.value = i
                await handle.render()
            }

            // If the trigger's state were rebuilt with the view, `initial: true`
            // would run the intent again after each rebuild.
            #expect(recorder.count == 1, "the intent ran \(recorder.count) times across rebuilds")
        }
    }
}

@MainActor
private final class ButtonErrorRecorder {
    var changedErrors: [String] = []
    var receivedErrors: [String] = []
}

/// A failing trigger next to an idle `IntentButton`, the shape the sibling-erasure
/// defect appears in. The idle button publishes nothing to either preference key
/// and must not erase its sibling's failure as SwiftUI folds the two children.
@MainActor
private struct TwoTriggerHarness: View {
    let recorder: ButtonErrorRecorder

    var body: some View {
        HStack {
            Text("fail")
                .onChange(of: "stable", initial: true, trigger: FailingIntent())
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
    @Test("A failing trigger reports its error past an idle IntentButton sibling")
    func failingTriggerReportsErrorPastIdleSibling() async throws {
        let recorder = ButtonErrorRecorder()

        await withHostedView(TwoTriggerHarness(recorder: recorder)) { handle in
            let arrived = await renderUntil(handle) {
                !recorder.changedErrors.isEmpty && !recorder.receivedErrors.isEmpty
            }

            #expect(arrived, "the failing trigger's error never reached the handlers on the container")
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

private final class RawErrorRecorder {
    /// Every value `onChangeIntentError` delivered; a delivered `nil` is "nil".
    var calls: [String] = []
}

private struct ToggledIntent: Intent {
    let fails: Bool

    func perform(context: Context) async throws -> String {
        if fails {
            throw SampleError.sameMessage
        }
        return "ok"
    }
}

private struct ErrorTriggerHarness: View {
    let tick: Int
    let failsFirst: Bool
    let recorder: RawErrorRecorder

    var body: some View {
        Text("run")
            .onChange(of: tick, initial: true, trigger: ToggledIntent(fails: failsFirst && tick == 0))
            .onChangeIntentError { error in
                recorder.calls.append(error?.localizedDescription ?? "nil")
            }
    }
}

@MainActor
private final class TickModel: ObservableObject {
    @Published var tick = 0
}

private struct ErrorTriggerParent: View {
    @ObservedObject var model: TickModel
    let failsFirst: Bool
    let recorder: RawErrorRecorder

    var body: some View {
        ErrorTriggerHarness(tick: model.tick, failsFirst: failsFirst, recorder: recorder)
    }
}

@MainActor
struct ChangeIntentErrorTests {
    @Test("onChangeIntentError is not called with nil when the view appears")
    func noNilOnAppear() async {
        let model = TickModel()
        let recorder = RawErrorRecorder()

        await withHostedView(ErrorTriggerParent(model: model, failsFirst: false, recorder: recorder)) { handle in
            await handle.render()
            await handle.render()
            #expect(recorder.calls.isEmpty, "the handler ran on appear with \(recorder.calls)")
        }
    }

    @Test("onChangeIntentError reports an error and then reports it cleared")
    func reportsErrorThenClear() async {
        let model = TickModel()
        let recorder = RawErrorRecorder()

        await withHostedView(ErrorTriggerParent(model: model, failsFirst: true, recorder: recorder)) { handle in
            let failed = await renderUntil(handle) { !recorder.calls.isEmpty }
            #expect(failed)
            #expect(recorder.calls == [SampleError.sameMessage.localizedDescription])

            model.tick = 1
            let cleared = await renderUntil(handle) { recorder.calls.count == 2 }
            #expect(cleared)
            #expect(recorder.calls == [SampleError.sameMessage.localizedDescription, "nil"])
        }
    }
}
