# Tia Phone

A training replica of the **TIA Portal V16** interface for iPhone — same
layout, same workflow — so students without a computer can practise PLC
programming from their phone:

- **Portal view**: create / open projects, recent projects, first steps.
- **Project view**: project tree, tabbed editors, task cards (Catalog /
  Instructions), inspector window with compile diagnostics, status bar.
- **Device configuration**: rack view of the CPU 1214C DC/DC/DC and its
  modules, device overview table; add signal modules from the catalog.
- **PLC tag table**: add/edit tags with data types and %I/%Q/%M addresses.
- **LAD editor**: networks with contacts (NO/NC), coils (normal, S, R),
  TON timers and CTU counters, parallel branches, element properties.
- **Compile**: realistic diagnostics (undefined tags, duplicate names,
  writing to an input address…) in the inspector window.
- **S7-PLCSIM panel**: power, RUN/STOP, drive the inputs and watch the
  outputs — a scan-cycle evaluator runs Main (OB1) every 100 ms.
- **Export**: share the project as JSON (Tia Phone format).

Ships with the **SortingStation** demo project (the same station as the
tia-mcp / Agent Factory twin): belts on BtnStart, count 5 boxes with a
CTU, hold the blade 3.5 s with a TON, stack lamps.

Tia Phone is a teaching model. It does not connect to real PLCs and does
not replace TIA Portal.

## Build (unsigned IPA, like CloudiOS)

1. Create a GitHub repo and push this folder to it (branch `main`).
2. GitHub Actions → "Build IPA" runs automatically and produces the
   `TiaPhone-unsigned-ipa` artifact.
3. Download `TiaPhone.ipa`, sign it with your certificate, install.

Local build (Mac): `brew install xcodegen && xcodegen generate`, then open
`TiaPhone.xcodeproj`.

## Layout

- `project.yml` — XcodeGen project (iOS 16+, bundle id `com.mehdi.tiaphone`)
- `Sources/` — the SwiftUI app (Models, Store, Theme, PortalView,
  ProjectView, DeviceConfigView, TagTableView, LadEditorView, Compiler,
  Simulator, SimPanelView)
- `.github/workflows/build.yml` — unsigned IPA pipeline
