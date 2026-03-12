import SwiftUI

@main
struct DriveMosaicApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Scan Folder...") {
                    chooseFolder()
                }
                .keyboardShortcut("o")
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder to scan"

        if panel.runModal() == .OK, let url = panel.url {
            appState.scan(path: url.path)
        }
    }
}
