import SwiftUI

struct ContentView: View {
    @EnvironmentObject var session: SessionStore
    @State private var showingAuthView = false
    
    var body: some View {
        ZStack {
            // Your main content here
            
            // Button to show the authentication view
            Button(action: {
                showingAuthView = true
            }) {
                Text("Show Authentication")
            }
            .sheet(isPresented: $showingAuthView) {
                SheetView(detents: [.medium(), .large()]) {
                    AuthenticationView()
                        .environmentObject(session)
                }
            }
        }
    }
}
