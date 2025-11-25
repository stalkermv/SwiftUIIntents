//
//  AsyncButtonExecution.swift
//  CustomComponents
//
//  Created by Valeriy Malishevskyi on 13.05.2025.
//

import SwiftUI

@MainActor final class AsyncButtonExecution: ObservableObject {
    @Published private(set) var task: Task<Void, Error>?
    @Published private(set) var isLoading = false
    private var options: AsyncButtonOptions = []
    
    func start(options: AsyncButtonOptions, _ action: @escaping () async -> Void) {
        self.options = options
        self.task?.cancel()
        self.task = Task { [weak self] in
            let loadingIndicatorTask = Task { [weak self] in
                try await Task.sleep(nanoseconds: 200_000_000)
                try Task.checkCancellation()
                
                if !options.contains(.loadingIndicatorHidden) {
                    self?.isLoading = true
                }
            }
            
            await action()
            
            try Task.checkCancellation()
            
            // Cancel loading indicator task
            loadingIndicatorTask.cancel()
            
            if !options.contains(.loadingIndicatorHidden) {
                self?.isLoading = false
            }

            self?.task = nil
        }
    }
    
    deinit {
        MainActor.assumeIsolated {
            guard !options.contains(.detachesTask) else { return }
            task?.cancel()
        }
    }
}
