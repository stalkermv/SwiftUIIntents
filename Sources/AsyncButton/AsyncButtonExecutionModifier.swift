//
//  AsyncButtonExecutionModifier.swift
//  CustomComponents
//
//  Created by Valeriy Malishevskyi on 13.05.2025.
//

import SwiftUI

struct AsyncButtonExecutionModifier: ViewModifier {
    let executionID: UUID?
    let options: AsyncButtonOptions
    @Binding var isDisabled: Bool
    let action: () async -> Void
    
    @StateObject private var execution = AsyncButtonExecution()
    
    func body(content: Content) -> some View {
        content.onChange(of: executionID) { newValue in
            if newValue != nil {
                performAction()
            }
        }
        .onChange(of: execution.task) { newTask in
            if newTask != nil, !options.contains(.enabledDuringExecution) {
                isDisabled = true
            } else {
                isDisabled = false
            }
        }
        .environment(\.isLoading, execution.isLoading)
    }
    
    private func performAction() {
        execution.start(options: options, action)
    }
}
