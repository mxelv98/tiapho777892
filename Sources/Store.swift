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
        if !fileExists("MotorOnOff") { save(TiaProject.motorProject()) }
        if !recents.contains("MotorOnOff") { recents.append("MotorOnOff"); persistRecents() }
        if !fileExists("PidLab") { save(TiaProject.pidProject()) }
        if !recents.contains("PidLab") { recents.append("PidLab"); persistRecents() }
        if !fileExists("MixingPlant") { save(TiaProject.plantProject()) }
        if !recents.contains("MixingPlant") { recents.append("MixingPlant"); persistRecents() }
    }

    private func fileURL(_ name: String) -> URL { dir.appendingPathComponent(name + ".tiaphone.json") }
    private func fileExists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: fileURL(name).path) }
    private func persistRecents() { UserDefaults.standard.set(recents, forKey: recentsKey) }

    func save(_ p: TiaProject) {
        if let data = try? JSONEncoder().encode(p) { try? data.write(to: fileURL(p.name)) }
    }

    func open(name: String) {
        guard let data = try? Data(contentsOf: fileURL(name)),
              var p = try? JSONDecoder().decode(TiaProject.self, from: data) else { return }
        // v3 migration: HMI screens saved by v1/v2 used a 350x230 canvas;
        // the KTP700 canvas is now 800x480 — scale old elements up once.
        if var h = p.hmi {
            let maxX = h.screens.flatMap { $0.elements }.map { $0.x + $0.w }.max() ?? 0
            if maxX > 0 && maxX <= 360 {
                for si in h.screens.indices {
                    for ei in h.screens[si].elements.indices {
                        h.screens[si].elements[ei].x *= 800.0 / 350.0
                        h.screens[si].elements[ei].w *= 800.0 / 350.0
                        h.screens[si].elements[ei].y *= 480.0 / 230.0
                        h.screens[si].elements[ei].h *= 480.0 / 230.0
                    }
                }
                p.hmi = h
            }
        }
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

    /// Decode a saved project without opening it (used for export/share).
    func loadProject(name: String) -> TiaProject? {
        guard let data = try? Data(contentsOf: fileURL(name)) else { return nil }
        return try? JSONDecoder().decode(TiaProject.self, from: data)
    }

    /// Import a project file (.tiaphone.json) picked by the user, so new
    /// projects can be added without rebuilding the app. The project is
    /// saved under its own name; on a name clash the imported copy is
    /// renamed "Name (imported)" so nothing is overwritten. Returns the
    /// final project name, or nil if the file is not a Tia Phone project.
    @discardableResult
    func importProject(from url: URL) -> String? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              var p = try? JSONDecoder().decode(TiaProject.self, from: data),
              !p.devices.isEmpty else { return nil }
        if fileExists(p.name) { p.name = p.name + " (imported)" }
        save(p)
        touch(p.name)
        return p.name
    }
}
