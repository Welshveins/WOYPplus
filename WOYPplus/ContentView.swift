import SwiftUI
import SwiftData

struct ContentView: View {

    @Environment(\.modelContext) private var ctx

    var body: some View {
        NavigationStack {
            TodayView()
        }
        .task {
            await ExtrasSeeder.seedAndAutofillIfNeeded(ctx: ctx)
        }
    }
}
