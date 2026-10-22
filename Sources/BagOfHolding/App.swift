import BagCore
import SwiftUI

@main
struct BagOfHoldingApp: App {
    @StateObject private var home = Home()

    var body: some Scene {
        MenuBarExtra {
            if let bag = home.bag {
                BagView(bag: bag, home: home)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Where should the bag live?").font(.headline)
                    Text("Pick a folder, or make one on your Desktop called Bag of Holding. Everything you add is copied there, filed by year and month.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Choose folder…") { home.choose() }.keyboardShortcut(.defaultAction)
                        Spacer()
                        Button("Quit") { NSApp.terminate(nil) }
                    }
                }
                .padding(14).frame(width: 360)
            }
        } label: {
            Image(nsImage: PouchIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}
