import SwiftUI

struct ContentView: View {
    @Binding var showUnclassifiedOnly: Bool

    var body: some View {
        NavigationStack {
            ScreenshotListView(showUnclassifiedOnly: $showUnclassifiedOnly)
        }
    }
}

#Preview {
    ContentView(showUnclassifiedOnly: .constant(false))
        .modelContainer(for: [Screenshot.self, UserSettings.self], inMemory: true)
}
