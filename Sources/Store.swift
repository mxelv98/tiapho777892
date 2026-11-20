import Foundation

final class ProjectStore: ObservableObject {
    @Published var project: TiaProject? = nil
    @Published var recents: [String] = []        // project names, most recent first

    private let dir: URL
    private let recentsKey = "tiaphone.recents"

    init() {
        dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Projects", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
        if !fileExists("SortingStation") { save(TiaProject.demoProject()) }
        if !recents.contains("SortingStation") { recents.insert("SortingStation", at: 0); persistRecents() }
    }

    private func fileURL(_ name: String) -> URL { dir.appendingPathComponent(name + ".tiaphone.json") }
    private func fileExists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: fileURL(name).path) }
    private func persistRecents() { UserDefaults.standard.set(recents, forKey: recentsKey) }

    func save(_ p: TiaProject) {
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: fileURL(p.name)) }
    }

    func open(name: String) {
        guard let data = try? Data(contentsOf: fileURL(name)),
              let p = try? JSONDecoder().decode(TiaProject.self, from: data) else { return }
        project = p
        touch(name)
    }

    func create(name: String) {
        let p = TiaProject.newProject(name: name)
        save(p)
        project = p
        touch(name)
    }

    func close(saveFirst: Bool = true) {
        if saveFirst, let p = project { save(p) }
        project = nil
    }

    func touch(_ name: String) {
        recents.removeAll { $0 == name }
        recents.insert(name, at: 0)
        persistRecents()
    }

    func updateHmi(_ h: HmiDevice) {
        guard var p = project else { return }
        p.hmi = h
        project = p
        save(p)
    }

    func updateWatch(_ w: [String]) {
        guard var p = project else { return }
        p.watchTags = w
        project = p
        save(p)
    }

    func updateDevice(_ d: PlcDevice) {
        guard var p = project, let i = p.devices.firstIndex(where: { $0.id == d.id }) else { return }
        p.devices[i] = d
        project = p
        save(p)
    }

    func delete(name: String) {
        try? FileManager.default.removeItem(at: fileURL(name))
        recents.removeAll { $0 == name }
        persistRecents()
    }

    func exportURL(_ p: TiaProject) -> URL? {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(p) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(p.name + ".tiaphone.json")
        try? data.write(to: url)
        return url
    }
}
