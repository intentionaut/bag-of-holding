import BagCore
import SwiftUI

@main
struct BagOfHoldingApp: App {
    @StateObject private var bag = Bag.standard

    var body: some Scene {
        MenuBarExtra {
            BagView(bag: bag)
        } label: {
            Image(nsImage: PouchIcon.image)
        }
        .menuBarExtraStyle(.window)
    }
}
