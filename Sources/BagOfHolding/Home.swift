import AppKit
import BagCore

/// The folder you chose for the bag. The sandbox only lets the app in because you picked it;
/// a security-scoped bookmark remembers that choice between launches.
final class Home: ObservableObject {
    @Published private(set) var bag: Bag?
    private var scoped: URL?
    private let key = "bagFolder"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        var stale = false
        if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope,
                              relativeTo: nil, bookmarkDataIsStale: &stale) {
            open(url, remember: stale)
        }
    }

    func choose() {
        let home = URL(fileURLWithPath: String(cString: getpwuid(getuid()).pointee.pw_dir))
        let desktop = home.appendingPathComponent("Desktop", isDirectory: true)
        let usual = desktop.appendingPathComponent("Bag of Holding", isDirectory: true)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Use this folder"
        panel.message = "Choose a folder for the bag, or make one called Bag of Holding. Everything you add is copied here, filed by year and month."
        panel.directoryURL = FileManager.default.fileExists(atPath: usual.path) ? usual : desktop
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url { open(url, remember: true) }
    }

    private func open(_ url: URL, remember: Bool) {
        guard url.startAccessingSecurityScopedResource() else { return }
        scoped?.stopAccessingSecurityScopedResource()
        scoped = url
        if remember, let data = try? url.bookmarkData(options: .withSecurityScope,
                                                      includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: key)
        }
        let bag = Bag(folder: url)
        bag.takeAll(from: .inContainer)   // brings across anything kept before the folder was chosen
        self.bag = bag
    }
}
