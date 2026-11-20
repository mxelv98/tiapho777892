import SwiftUI
import UniformTypeIdentifiers

/// Portal view — v5.0 skin: the same start screen and logic, redrawn with
/// the iPhone touch from the approved mockups (frosted header, task card,
/// projects as rounded cards). All store calls are unchanged.
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
                Button { showImporter = true } label: {
                    Label("Import file", systemImage: "square.and.arrow.down")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Tia.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Text("Portal view").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(14)
            .background(Tia.paneHeader)
            HStack(spacing: 10) {
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
                .tiaCard()
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
                        Text("Tia Phone — a training replica of the TIA Portal V16 interface.\nIt does not connect to real PLCs and does not replace TIA Portal.")
                            .font(.system(size: 12.5))
                    } else {
                        HStack {
                            Text("Recent projects").font(.system(size: 15, weight: .semibold))
                            Spacer()
                            Text("\(store.recents.count) projects").font(.system(size: 11.5)).foregroundColor(.secondary)
                        }
                        if !importNote.isEmpty {
                            Text(importNote).font(.system(size: 11.5)).foregroundColor(Tia.accent)
                        }
                        if store.recents.isEmpty {
                            Text("No projects yet.").foregroundColor(.secondary)
                        }
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(store.recents, id: \.self) { name in
                                projectCard(name)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
        }
        .background(Tia.pane)
        .sheet(isPresented: $showCreate) { EmptyView() }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result, let name = store.importProject(from: url) {
                importNote = "Imported \(name) — tap Open to start it."
                selected = "open"
            } else {
                importNote = "That file is not a Tia Phone project."
            }
        }
    }

    private func projectCard(_ name: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Tia.selection)
                    .frame(width: 42, height: 42)
                    .overlay(Image(systemName: "doc.richtext").font(.system(size: 19)).foregroundColor(Tia.accent))
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 13.5, weight: .semibold)).lineLimit(1)
                    Text("Documents/Projects").font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
            }
            HStack(spacing: 8) {
                Button { store.open(name: name) } label: {
                    Text("Open").font(.system(size: 12, weight: .semibold)).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Tia.accent).clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                if let p = store.loadProject(name: name), let url = store.exportURL(p) {
                    ShareLink(item: url) { Image(systemName: "square.and.arrow.up").font(.system(size: 13)) }
                        .foregroundColor(Tia.accent)
                }
                Button(role: .destructive) { store.delete(name: name) } label: {
                    Image(systemName: "trash").font(.system(size: 13))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .tiaCard()
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
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(selected == key ? Tia.selection : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
