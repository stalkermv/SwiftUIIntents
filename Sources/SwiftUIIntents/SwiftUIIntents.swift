import SwiftUI

private struct MyIntent: Intent {
    
    func perform(context: Context) async throws {
        print("Performing MyIntent")
        try await Task.sleep(for: .seconds(5))
        print("MyIntent completed")
    }
}

private struct MyValuedIntent: Intent {
    
    func perform(context: Context) async throws -> String {
        print("Performing MyIntent")
        try await Task.sleep(for: .seconds(5))
        print("MyIntent completed")
        
        return "Hello, world!"
    }
}

private struct PreviewView: View {
    private var intent = MyIntent()
    @IntentState(MyValuedIntent()) var intentState: String?
    
    var body: some View {
        IntentButton(MyIntent()) {
            Text("Perform MyIntent")
        }
        
        Text(" \(intentState ?? "nil")")
            .padding()
        
        IntentButton($intentState) {
            Text("Perform MyIntent")
        }
        
    }
}

#Preview {
    PreviewView()
}
