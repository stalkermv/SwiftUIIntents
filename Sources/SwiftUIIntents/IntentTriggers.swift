//
//  IntentTriggers.swift
//  SwiftUIIntents
//

import SwiftUI
import UniformTypeIdentifiers

/// The state every view-owned trigger needs: an executor, and an owner for the
/// task when SwiftUI does not own it.
@MainActor
final class IntentRunHost<Result: Sendable> {
    let executor = IntentExecutor<Result>()
    let owner = IntentTaskOwner()

    func start(
        _ intent: any Intent<Result>,
        environment: EnvironmentValues,
        policy: IntentReentryPolicy,
        handle: (any IntentRunBinding)? = nil
    ) {
        let context = IntentContextContainer(environment: environment)
        owner.start(policy: policy) { [executor] in
            await executor.perform(intent, context: context, handle: handle)
        }
    }
}

// MARK: - SwiftUI-owned tasks

extension View {
    /// Runs an intent when the view appears, and cancels the run when the view
    /// goes away.
    ///
    /// ```swift
    /// List(items) { … }
    ///     .task(LoadItemsIntent())
    /// ```
    public func task<I: Intent>(
        _ intent: I?,
        handle: IntentHandle<I>? = nil
    ) -> some View {
        task(id: 0, intent, handle: handle)
    }

    /// Runs an intent when the view appears and again whenever `id` changes.
    ///
    /// A new `id` cancels the run in flight, like SwiftUI's `task(id:)`.
    public func task<ID: Equatable, I: Intent>(
        id: ID,
        _ intent: I?,
        handle: IntentHandle<I>? = nil
    ) -> some View {
        modifier(TaskIntentModifier(id: id, intent: intent, handle: handle))
    }

    /// Runs an intent when the user pulls to refresh.
    ///
    /// SwiftUI owns the task, shows the refresh indicator for as long as the
    /// intent runs, and cancels the run if the view goes away.
    @available(tvOS, unavailable)
    public func refreshable<I: Intent>(
        _ intent: I?,
        handle: IntentHandle<I>? = nil
    ) -> some View {
        modifier(RefreshableIntentModifier(intent: intent, handle: handle))
    }
}

private struct TaskIntentModifier<ID: Equatable, I: Intent>: ViewModifier {
    let id: ID
    let intent: I?
    let handle: IntentHandle<I>?

    @State private var executor = IntentExecutor<I.PerformResult>()
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        content
            .task(id: id) {
                guard let intent else {
                    return
                }

                await executor.perform(
                    intent,
                    context: IntentContextContainer(environment: environment),
                    handle: handle
                )
            }
            .intentReporting(executor)
    }
}

@available(tvOS, unavailable)
private struct RefreshableIntentModifier<I: Intent>: ViewModifier {
    let intent: I?
    let handle: IntentHandle<I>?

    @State private var executor = IntentExecutor<I.PerformResult>()
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        content
            .refreshable {
                guard let intent else {
                    return
                }

                await executor.perform(
                    intent,
                    context: IntentContextContainer(environment: environment),
                    handle: handle
                )
            }
            .intentReporting(executor)
    }
}

// MARK: - Callbacks that run without an async closure

extension View {
    /// Runs an intent when the user submits, for example by pressing Return in a
    /// text field or in a search field.
    ///
    /// ```swift
    /// TextField("Title", text: $title)
    ///     .onSubmit(of: .text, SaveTitleIntent(title: title))
    /// ```
    ///
    /// - Parameters:
    ///   - triggers: What counts as a submission; the default is `.text`.
    ///   - policy: What to do when the user submits again while the intent is still
    ///     running. The default, `.ignore`, waits for the run to finish.
    ///   - intent: The intent to run.
    ///
    /// The run is cancelled when the view is removed, not when it only disappears
    /// behind a pushed screen.
    public func onSubmit<I: Intent>(
        of triggers: SubmitTriggers = .text,
        policy: IntentReentryPolicy = .ignore,
        _ intent: I?
    ) -> some View {
        modifier(OnSubmitIntentModifier(triggers: triggers, policy: policy, intent: intent))
    }

    /// Runs the intent that `intent` builds for each URL the app is asked to open.
    ///
    /// ```swift
    /// .onOpenURL { url in OpenLinkIntent(url: url) }
    /// ```
    public func onOpenURL<I: Intent>(
        policy: IntentReentryPolicy = .cancelAndRestart,
        _ intent: @escaping (URL) -> I?
    ) -> some View {
        modifier(PayloadIntentModifier<URL, I.PerformResult>(policy: policy) { host, url, environment, _ in
            guard let built = intent(url) else { return }
            host.start(built, environment: environment, policy: policy)
        } attach: { content, fire in
            AnyView(content.onOpenURL { url in fire(url) })
        })
    }

    /// Runs the intent that `intent` builds when the app continues a user activity.
    public func onContinueUserActivity<I: Intent>(
        _ activityType: String,
        policy: IntentReentryPolicy = .cancelAndRestart,
        _ intent: @escaping (NSUserActivity) -> I?
    ) -> some View {
        modifier(PayloadIntentModifier<NSUserActivity, I.PerformResult>(policy: policy) { host, activity, environment, _ in
            guard let built = intent(activity) else { return }
            host.start(built, environment: environment, policy: policy)
        } attach: { content, fire in
            AnyView(content.onContinueUserActivity(activityType) { activity in fire(activity) })
        })
    }

    #if os(iOS) || os(macOS) || os(visionOS)
    /// Runs the intent that `intent` builds when the user finishes with the file
    /// importer.
    public func fileImporter<I: Intent>(
        isPresented: Binding<Bool>,
        allowedContentTypes: [UTType],
        allowsMultipleSelection: Bool,
        policy: IntentReentryPolicy = .cancelAndRestart,
        onCompletion intent: @escaping (Result<[URL], Error>) -> I?
    ) -> some View {
        modifier(PayloadIntentModifier<Result<[URL], Error>, I.PerformResult>(policy: policy) { host, result, environment, _ in
            guard let built = intent(result) else { return }
            host.start(built, environment: environment, policy: policy)
        } attach: { content, fire in
            AnyView(content.fileImporter(
                isPresented: isPresented,
                allowedContentTypes: allowedContentTypes,
                allowsMultipleSelection: allowsMultipleSelection
            ) { result in fire(result) })
        })
    }

    /// Runs the intent that `intent` builds when the user finishes with the file
    /// exporter.
    public func fileExporter<D: FileDocument, I: Intent>(
        isPresented: Binding<Bool>,
        document: D?,
        contentType: UTType,
        defaultFilename: String? = nil,
        policy: IntentReentryPolicy = .cancelAndRestart,
        onCompletion intent: @escaping (Result<URL, Error>) -> I?
    ) -> some View {
        modifier(PayloadIntentModifier<Result<URL, Error>, I.PerformResult>(policy: policy) { host, result, environment, _ in
            guard let built = intent(result) else { return }
            host.start(built, environment: environment, policy: policy)
        } attach: { content, fire in
            AnyView(content.fileExporter(
                isPresented: isPresented,
                document: document,
                contentType: contentType,
                defaultFilename: defaultFilename
            ) { result in fire(result) })
        })
    }
    #endif
}

private struct OnSubmitIntentModifier<I: Intent>: ViewModifier {
    let triggers: SubmitTriggers
    let policy: IntentReentryPolicy
    let intent: I?

    @State private var host = IntentRunHost<I.PerformResult>()
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        content
            .onSubmit(of: triggers) {
                guard let intent else {
                    return
                }

                host.start(intent, environment: environment, policy: policy)
            }
            .intentReporting(host.executor)
    }
}

/// The shared shape of the payload overloads: SwiftUI's callback hands over a
/// value, the closure builds an intent from it, and a host runs it.
private struct PayloadIntentModifier<Payload, Result: Sendable>: ViewModifier {
    typealias Fire = @MainActor (IntentRunHost<Result>, Payload, EnvironmentValues, IntentReentryPolicy) -> Void
    typealias Attach = (Content, @escaping (Payload) -> Void) -> AnyView

    let policy: IntentReentryPolicy
    let fire: Fire
    let attach: Attach

    @State private var host = IntentRunHost<Result>()
    @Environment(\.self) private var environment

    init(policy: IntentReentryPolicy, fire: @escaping Fire, attach: @escaping Attach) {
        self.policy = policy
        self.fire = fire
        self.attach = attach
    }

    func body(content: Content) -> some View {
        attach(content) { payload in
            fire(host, payload, environment, policy)
        }
        .intentReporting(host.executor)
    }
}

// MARK: - Long-running intents

extension View {
    /// Runs a long-running intent when the view disappears.
    ///
    /// Only a ``LongRunningIntent`` is accepted, because the view is gone while the
    /// intent runs: a plain intent would be cancelled at once. The work finishes,
    /// but no hook reports it, and a failure is written to the log.
    ///
    /// ```swift
    /// .onDisappear(SaveDraftIntent(text: text))   // SaveDraftIntent: LongRunningIntent
    /// ```
    public func onDisappear<I: LongRunningIntent>(_ intent: I?) -> some View {
        modifier(OnDisappearIntentModifier(intent: intent))
    }
}

private struct OnDisappearIntentModifier<I: LongRunningIntent>: ViewModifier {
    let intent: I?
    @Environment(\.self) private var environment

    func body(content: Content) -> some View {
        content.onDisappear {
            guard let intent else {
                return
            }

            let context = IntentContextContainer(environment: environment)
            let executor = IntentExecutor<I.PerformResult>()
            // Unstructured, so the run is not tied to the view's task.
            Task { @MainActor in
                await executor.perform(intent, context: context)
            }
        }
    }
}

// MARK: - IntentToggle

/// A toggle that commits a change by running an intent.
///
/// Like ``IntentPicker``, it shows the new value at once, runs the intent, and
/// returns to the value you supply as the source of truth when the intent
/// finishes. While the intent runs the toggle is disabled.
///
/// ```swift
/// IntentToggle(isOn: settings.notificationsEnabled, { SetNotificationsIntent(isOn: $0) }) {
///     Text("Notifications")
/// }
/// ```
public struct IntentToggle<I: Intent, Label: View>: View {
    private let isOn: Bool
    private let makeIntent: (Bool) -> I?
    private let label: Label

    @State private var pending: Bool?
    @State private var host = IntentRunHost<I.PerformResult>()
    @Environment(\.self) private var environment

    /// Creates a toggle that runs the intent `intent` builds for the new value.
    ///
    /// - Parameters:
    ///   - isOn: The current value, owned by you.
    ///   - intent: Builds the intent for the value the user chose, or `nil` to ignore the change.
    ///   - label: The toggle's label.
    public init(
        isOn: Bool,
        _ intent: @escaping (Bool) -> I?,
        @ViewBuilder label: () -> Label
    ) {
        self.isOn = isOn
        self.makeIntent = intent
        self.label = label()
    }

    public var body: some View {
        Toggle(isOn: binding) {
            label
        }
        .disabled(pending != nil || host.executor.phase == .running)
        .intentReporting(host.executor)
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { pending ?? isOn },
            set: commit
        )
    }

    private func commit(_ newValue: Bool) {
        guard pending == nil, host.executor.phase != .running else {
            return
        }

        guard newValue != isOn, let intent = makeIntent(newValue) else {
            return
        }

        pending = newValue
        let context = IntentContextContainer(environment: environment)
        host.owner.start(policy: .ignore) { [host] in
            await host.executor.perform(intent, context: context)
            self.pending = nil
        }
    }
}
