import SwiftUI
import UniformTypeIdentifiers

/// Portal view — v5.2: PHONE-NATIVE home, designed for the phone only
/// (his order: no shrunken desktop Portal). Portrait-first, one-handed,
/// 44pt targets, big type; landscape simply widens the same layout.
/// The project workspace keeps the TIA training identity — this home is
/// just the front door. Store logic unchanged.
struct PortalView: View {
    @EnvironmentObject var store: ProjectStore
    @State private var showCreate = false
    @State private var newName = ""
    @State private var selected: String? = "open"
    @State private var showImporter = false
    @State private var importNote = ""
    @State private var appeared = false

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > 560
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    brandHeader
                    if selected == "create" {
                        createCard
                    } else if selected == "steps" {
                        infoCard(title: "First steps", lines: stepsLines, footnote: "Open the SortingStation demo project to see a complete example.")
                    } else if selected == "about" {
                        infoCard(title: "Installed software", lines: ["Tia Phone — a training replica of the TIA Portal V16 interface.", "It does not connect to real PLCs and does not replace TIA Portal."], footnote: nil)
                    } else {
                        actionsRow
                        recentHeader
                        if !importNote.isEmpty {
                            Text(importNote).font(.system(size: 12.5)).foregroundColor(Tia.accent)
                        }
                        if store.recents.isEmpty {
                            Text("No projects yet — create your first one above.")
                                .font(.system(size: 13)).foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        } else if wide {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                ForEach(Array(store.recents.enumerated()), id: \.element) { i, name in
                                    projectRow(name).entrance(i, appeared)
                                }
                            }
                        } else {
                            VStack(spacing: 12) {
                                ForEach(Array(store.recents.enumerated()), id: \.element) { i, name in
                                    projectRow(name).entrance(i, appeared)
                                }
                            }
                        }
                        learnRow
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Tia.pane)
        }
        .onAppear { withAnimation(.spring(response: 0.55, dampingFraction: 0.85).delay(0.05)) { appeared = true } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            if case .success(let url) = result, let name = store.importProject(from: url) {
                importNote = "Imported \(name) — tap it to open."
                selected = "open"
            } else {
                importNote = "That file is not a Tia Phone project."
            }
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 12) {
            LogoMark(size: 52)
            VStack(alignment: .leading, spacing: 1) {
                Text("Tia Phone").font(.system(size: 26, weight: .bold)).foregroundColor(Tia.textDark)
                Text("PLC training, in your pocket").font(.system(size: 13)).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.top, 6)
    }

    private var actionsRow: some View {
        VStack(spacing: 12) {
            Button { selected = "create" } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 20))
                    Text("New project").font(.system(size: 16, weight: .semibold))
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.7)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(Tia.accent)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Tia.accent.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(PressableButtonStyle())
            Button { showImporter = true } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.down").font(.system(size: 17)).foregroundColor(Tia.accent)
                    Text("Import a project file").font(.system(size: 15, weight: .medium)).foregroundColor(Tia.textDark)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .tiaCard(radius: 16)
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var recentHeader: some View {
        HStack {
            Text("Recent projects").font(.system(size: 18, weight: .bold)).foregroundColor(Tia.textDark)
            Spacer()
            Text("\(store.recents.count)").font(.system(size: 13)).foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    private var learnRow: some View {
        HStack(spacing: 12) {
            Button { selected = "steps" } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.number").foregroundColor(Tia.accent)
                    Text("First steps").font(.system(size: 14, weight: .medium)).foregroundColor(Tia.textDark)
                }
                .frame(maxWidth: .infinity).frame(height: 46)
                .tiaCard(radius: 14)
            }
            .buttonStyle(PressableButtonStyle())
            Button { selected = "about" } label: {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundColor(Tia.accent)
                    Text("About").font(.system(size: 14, weight: .medium)).foregroundColor(Tia.textDark)
                }
                .frame(maxWidth: .infinity).frame(height: 46)
                .tiaCard(radius: 14)
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(.top, 2)
    }

    private func projectRow(_ name: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Tia.selection)
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: "doc.richtext").font(.system(size: 21)).foregroundColor(Tia.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15.5, weight: .semibold)).foregroundColor(Tia.textDark).lineLimit(1)
                Text("Tap to open").font(.system(size: 12)).foregroundColor(.secondary)
            }
            Spacer(minLength: 4)
            if let p = store.loadProject(name: name), let url = store.exportURL(p) {
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up").font(.system(size: 16)) }
                    .foregroundColor(Tia.accent)
                    .frame(width: 36, height: 36)
            }
            Button(role: .destructive) { store.delete(name: name) } label: {
                Image(systemName: "trash").font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 36)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
        }
        .padding(12)
        .tiaCard(radius: 16)
        .contentShape(Rectangle())
        .onTapGesture { store.open(name: name) }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create new project").font(.system(size: 18, weight: .bold))
            TextField("Project name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 16))
            Text("Created with one device: PLC_1 (CPU 1214C DC/DC/DC) and an empty Main (OB1). Saved in Documents/Projects.")
                .font(.system(size: 12)).foregroundColor(.secondary)
            HStack(spacing: 10) {
                Button {
                    let n = newName.trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty { store.create(name: n) }
                } label: {
                    Text("Create").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .background(Tia.accent).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableButtonStyle())
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                Button { selected = "open" } label: {
                    Text("Cancel").font(.system(size: 15, weight: .medium)).foregroundColor(Tia.textDark)
                        .frame(maxWidth: .infinity).frame(height: 46)
                        .tiaCard(radius: 12)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(14)
        .tiaCard(radius: 16)
    }

    private func infoCard(title: String, lines: [String], footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 18, weight: .bold))
                Spacer()
                Button { selected = "open" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 20)).foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            ForEach(lines, id: \.self) { Text($0).font(.system(size: 14)) }
            if let footnote {
                Text(footnote).font(.system(size: 12)).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .tiaCard(radius: 16)
    }

    private var stepsLines: [String] {
        ["Inside a project, rotate your phone to landscape — the workspace is laid out like the PC.",
         "1  Create a project and add the CPU from the catalog",
         "2  Declare your inputs and outputs in the tag table",
         "3  Program Main (OB1) in the LAD editor",
         "4  Compile and read the diagnostics in the inspector window",
         "5  Start PLCSIM, download, switch to RUN and test with the inputs"]
    }
}

extension View {
    /// Staggered entrance for list cards (Portal home).
    func entrance(_ index: Int, _ on: Bool) -> some View {
        opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(Double(index) * 0.06), value: on)
    }
}
