import Combine
import SwiftUI
import Testing
import ViewInspector
@testable import SwiftUIIntents

@MainActor
struct SwiftUIIntentsTests {
    @Test("IntentExecutor stores successful results")
    func executorStoresSuccess() async throws {
        let executor = IntentExecutor<String>(intent: ConstantIntent(value: "done") as (any Intent<String>))

        await executor.perform(context: makeContext())

        guard case .success(let value) = executor.state else {
            Issue.record("Expected success state")
            return
        }

        #expect(value == "done")
        #expect(executor.latestErrorEvent == nil)
    }

    @Test("IntentExecutor stores failures and emits unique error events")
    func executorEmitsUniqueErrorEvents() async throws {
        let executor = IntentExecutor<String>(intent: FailingIntent() as (any Intent<String>))

        await executor.perform(context: makeContext())
        guard let firstEvent = executor.latestErrorEvent else {
            Issue.record("Expected first error event")
            return
        }

        guard case .failure(let firstError) = executor.state else {
            Issue.record("Expected failure state after first run")
            return
        }

        #expect(firstError.localizedDescription == SampleError.sameMessage.localizedDescription)

        await executor.perform(context: makeContext())
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

    @Test("IntentBinding performs intents with service context")
    func intentBindingPerformsWithServiceContext() async throws {
        let executor = IntentExecutor<String>(intent: ContextAwareIntent() as (any Intent<String>))
        var environment = EnvironmentValues()
        environment.locale = Locale(identifier: "uk_UA")
        let binding = IntentBinding(executor: executor, environment: environment)

        await binding.perform()

        guard case .success(let value) = executor.state else {
            Issue.record("Expected success state")
            return
        }

        #expect(value == "uk_UA")
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
        let result = try await intent.perform(context: makeContext())

        #expect(result.0 == "first")
        #expect(result.1 == "second")
    }

    @Test("Simultaneous combined intent executes concurrently")
    func simultaneousCombinedIntentExecutesConcurrently() async throws {
        let intent = ConstantIntent(value: "left").combined(simultaneously: ConstantIntent(value: "right"))
        let result = try await intent.perform(context: makeContext())

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
