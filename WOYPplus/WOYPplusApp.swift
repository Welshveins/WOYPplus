import SwiftUI
import SwiftData

@main
struct WOYPplusApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Day.self,
            Entry.self,
            Recipe.self,
            RecipeIngredient.self,
            ExtrasPreset.self
        ])
    }
}
