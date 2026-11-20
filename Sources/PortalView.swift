import SwiftUI
import UniformTypeIdentifiers

/// TIA Portal "Portal view" — the start screen, laid out like the real one:
/// task list on the left, first steps + recent projects in the middle.
struct PortalView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var showCreate = false
    @State private var newName = ""
    @State private var selected: String? = "open"
    @State private var showImporter = false
    @State private var importNote = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Wordmark(large: true)
                Spacer()
                Text("Portal view").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Tia.pane)
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start").font(.system(size: 12, weight: .semibold)).padding(.bottom, 4)
                    portalTask("Create new project", "plus.square", "create")
                    portalTask("Open existing project", "folder", "open")
                    portalTask("Migrate project", "arrow.triangle.2.circlepath", "migrate")
                    portalTask("Close portal", "xmark.square", "close")
                    Divider().padding(.vertical, 6)
                    Text("Learn").font(.system(size: 12, weight: .semibold)).padding(.bottom, 4)
                    portalTask("First steps", "list.number", "steps")
                    portalTask("Installed software", "info.circle", "about")
                    Spacer()
                }
                .padding(10)
                .frame(width: 210, alignment: .leading)
                .background(Tia.pane)
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    if selected == "create" {
                        Text("Create new project").font(.system(size: 15, weight: .semibold))
                        HStack {
                            Text("Name:").frame(width: 60, alignment: .leading)
                            TextField("Project name", text: $newName).textFieldStyle(.roundedBorder).frame(maxWidth: 280)
                        }
                        HStack {
                            Text("Path:").frame(width: 60, alignment: .leading)
                            Text("Documents/Projects").foregroundColor(.secondary)
                        }
                        HStack {
                            Button("Create") {
                                let n = newName.trimmingCharacters(in: .whitespaces)
                                if !n.isEmpty { store.create(name: n) }
                            }.disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            Button("Cancel") { selected = "open" }
                        }
                        Text("A new project is created with one device: PLC_1 (CPU 1214C DC/DC/DC) and an empty Main (OB1).")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    } else if selected == "steps" {
                        Text("First steps").font(.system(size: 15, weight: .semibold))
                        ForEach(["Rotate your phone to landscape — the project view is laid out like the PC, and portrait keeps the tree and task cards behind the Tree / Tasks buttons",
                                 "1  Create a project and add the CPU from the catalog",
                                 "2  Declare your inputs and outputs in the tag table",
                                 "3  Program Main (OB1) in the LAD editor",
                                 "4  Compile and read the diagnostics in the inspector window",
                                 "5  Start PLCSIM, download, switch to RUN and test with the inputs"], id: \.self) {
                            Text($0).font(.system(size: 12.5))
                        }
                        Text("Open the SortingStation demo project to see a complete example.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    } else if selected == "about" {
                        Text("Installed software").font(.system(size: 15, weight: .semibold))
                        Text("Tia Phone 1.0 — a training replica of the TIA Portal V16 interface.\nIt does not connect to real PLCs and does not replace TIA Portal.")
                            .font(.system(size: 12.5))
                    } else {
                        Text("Open existing project").font(.system(size: 15, weight: .semibold))
                        HStack {
                            Text("Recent projects").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                            Spacer()
                            Button { showImporter = true } label: {
                                Label("Import file", systemImage: "square.and.arrow.down").font(.system(size: 12))
                            }
                        }
                        if !importNote.isEmpty {
                            Text(importNote).font(.system(size: 11.5)).foregroundColor(Tia.accent)
                        }
                        if store.recents.isEmpty {
                            Text("No projects yet.").foregroundColor(.secondary)
                        }
                        ForEach(store.recents, id: \.self) { name in
                            HStack {
                                Image(systemName: "doc.richtext").foregroundColor(Tia.accent)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(name).font(.system(size: 13, weight: .medium))
                                    Text("Documents/Projects/\(name)").font(.system(size: 10.5)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if let p = store.loadProject(name: name), let url = store.exportURL(p) {
                                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                                        .foregroundColor(Tia.accent)
                                }
                                Button("Open") { store.open(name: name) }
                                Button(role: .destructive) { store.delete(name: name) } label: { Image(systemName: "trash") }
                            }
                            .padding(8)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Tia.border, lineWidth: 0.7))
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
        }
        .background(Tia.pane)
        .sheet(isPresented: $showCreate) { EmptyView() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result, let name = store.importProject(from: url) {
                importNote = "Imported \(name) — tap Open to start it."
            } else {
                importNote = "That file is not a Tia Phone project."
            }
        }
    }

    private func portalTask(_ title: String, _ icon: String, _ key: String) -> some View {
        Button {
            selected = key
            if key == "close" { selected = "open" }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).frame(width: 18).foregroundColor(Tia.accent)
                Text(title).font(.system(size: 12.5))
                Spacer()
            }
            .padding(.vertical, 5).padding(.horizontal, 6)
            .background(selected == key ? Tia.selection : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
