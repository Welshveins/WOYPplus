import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var ctx

    @State private var hasEntered = false

    var body: some View {
        NavigationStack {
            if hasEntered {
                TodayView()
            } else {
                WelcomeView {
                    hasEntered = true
                }
            }
        }
        .task {
            await ExtrasSeeder.seedAndAutofillIfNeeded(ctx: ctx)
        }
    }
}
