//
//  AsyncButton.swift
//  CustomComponents
//
//  Created by Valeriy Malishevskyi on 12.05.2025.
//

import SwiftUI

private struct PreviewButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isLoading) private var isLoading
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                configuration.label
            }
        }
        .padding()
        .background(configuration.isPressed ? Color.gray : Color.blue)
        .opacity(isEnabled ? 1 : 0.5)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

@available(iOS 16.0, *)
private struct PreviewView: View {
    var body: some View {
        NavigationStack {
            NavigationLink(destination: Text("Destination")) {
                Text("Go to Destination")
            }
            
            NavigationLink {
                VStack {
                    AsyncButton(role: .destructive) {
                        do {
                            try await Task.sleep(for: .seconds(3))
                            print("Destructive action completed")
                        } catch {
                            print("Error: \(error)")
                        }
                    } label: {
                        Text("Destructive")
                    }
                    
                    AsyncButton(options: .detachesTask, action: someAction) {
                        Text("Detached")
                    }
                }
            } label: {
                Text("Destructive Navigation")
            }
            
            AsyncButton(options: .loadingIndicatorHidden, action: someAction) {
                Text("No Loading Indicator")
            }
            
            AsyncButton(options: .enabledDuringExecution, action: someAction) {
                Text("Enabled")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .buttonStyle(PreviewButtonStyle())
    }
    
    private func someAction() async {
        do {
            try await Task.sleep(for: .seconds(2))
            print("Action completed")
        } catch {
            print("Error: \(error)")
        }
    }
}

@available(iOS 17.0, macOS 14.0, tvOS 16.0, watchOS 10.0, *)
#Preview(traits: .fixedLayout(width: 400, height: 400)) {
    PreviewView()
}
