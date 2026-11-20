import Foundation

enum TiaCompiler {
    static func compile(project: TiaProject) -> [Diagnostic] {
        var out: [Diagnostic] = []
        let df = DateFormatter(); df.dateFormat = "HH:mm:ss"
        let now = df.string(from: Date())
        func err(_ path: String, _ text: String) { out.append(Diagnostic(isError: true, path: path, text: text, time: now)) }
        func warn(_ path: String, _ text: String) { out.append(Diagnostic(isError: false, path: path, text: text, time: now)) }

        for device in project.devices {
            let tagPath = "\(device.name) › PLC tags › Default tag table"
            var seenNames = Set<String>()
            var seenAddr = Set<String>()
            for tag in device.tags {
                if tag.name.isEmpty { err(tagPath, "A tag has no name."); continue }
                if !seenNames.insert(tag.name).inserted { err(tagPath, "The tag name '\(tag.name)' is used more than once.") }
                if !tag.address.isEmpty && !seenAddr.insert(tag.address).inserted {
                    warn(tagPath, "The address '\(tag.address)' is assigned to more than one tag.")
                }
                if tag.dataType == "Bool" && !tag.address.isEmpty &&
                   !(tag.address.hasPrefix("%I") || tag.address.hasPrefix("%Q") || tag.address.hasPrefix("%M")) {
                    warn(tagPath, "The address '\(tag.address)' of tag '\(tag.name)' is outside the I/Q/M areas used in this course.")
                }
            }
            let defined = Set(device.tags.map { $0.name })
                .union((device.dataBlocks ?? []).flatMap { db in db.rows.map { "\(db.name).\($0.name)" } })
            for block in device.blocks {
                let blockPath = "\(device.name) › Program blocks › \(block.name) (\(block.type)\(block.number))"
                if block.language == "SCL" && (block.sclSource ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    warn(blockPath, "The SCL block has no source text yet.")
                }
                for (ni, net) in block.networks.enumerated() {
                    let netPath = blockPath + " › Network \(ni + 1)"
                    let elements = net.series + net.branches.flatMap { $0 } + [net.output]
                    if net.series.isEmpty && net.branches.isEmpty {
                        warn(netPath, "The network contains no instruction in the main rung.")
                    }
                    for el in elements {
                        switch el.kind {
                        case .contactNO, .contactNC, .coil, .coilSet, .pTrig, .nTrig:
                            if el.tag.isEmpty { err(netPath, "An instruction has no operand.") }
                            else if !defined.contains(el.tag) { err(netPath, "The tag '\(el.tag)' is not defined in the tag table.") }
                        case .notOp:
                            break
                        case .coilReset:
                            if el.tag.isEmpty { err(netPath, "A reset coil has no operand.") }
                        case .ton, .tof, .tp:
                            if el.instance.isEmpty { err(netPath, "The timer has no instance name.") }
                            if el.tag.isEmpty { err(netPath, "The timer output (Q) has no tag.") }
                            else if !defined.contains(el.tag) { err(netPath, "The tag '\(el.tag)' is not defined in the tag table.") }
                        case .ctu, .ctd:
                            if el.instance.isEmpty { err(netPath, "The counter has no instance name.") }
                            if !el.inputTag.isEmpty && !defined.contains(el.inputTag) {
                                err(netPath, "The counter input tag '\(el.inputTag)' is not defined in the tag table.")
                            }
                            if el.tag.isEmpty { err(netPath, "The counter output (Q) has no tag.") }
                            else if !defined.contains(el.tag) { err(netPath, "The tag '\(el.tag)' is not defined in the tag table.") }
                        case .tonr:
                            if el.instance.isEmpty { err(netPath, "The timer has no instance name.") }
                            if !el.inputTag.isEmpty && !defined.contains(el.inputTag) {
                                err(netPath, "The TONR reset tag '\(el.inputTag)' is not defined.")
                            }
                        case .ctud:
                            if el.instance.isEmpty { err(netPath, "The counter has no instance name.") }
                            if !el.inputTag.isEmpty && !defined.contains(el.inputTag) {
                                err(netPath, "The CD input tag '\(el.inputTag)' is not defined.")
                            }
                        case .sr, .rs:
                            if el.instance.isEmpty { err(netPath, "The flip-flop has no instance name.") }
                            if !el.inputTag.isEmpty && !defined.contains(el.inputTag) {
                                err(netPath, "The reset tag '\(el.inputTag)' is not defined.")
                            }
                        case .cmp:
                            if el.tag.isEmpty { err(netPath, "The comparator has no IN1 operand.") }
                            else if !defined.contains(el.tag) && Double(el.tag) == nil {
                                err(netPath, "The operand '\(el.tag)' is not defined.")
                            }
                            if !el.useConst && el.inputTag.isEmpty { err(netPath, "The comparator has no IN2 operand.") }
                        case .math, .move:
                            if el.tag.isEmpty { err(netPath, "The instruction has no IN operand.") }
                            if el.outTag.isEmpty { err(netPath, "The instruction has no OUT operand.") }
                            else if !defined.contains(el.outTag) { err(netPath, "The tag '\(el.outTag)' is not defined in the tag table.") }
                        case .pid:
                            if el.instance.isEmpty { err(netPath, "The PID has no instance name.") }
                            if el.tag.isEmpty { err(netPath, "The PID has no setpoint operand.") }
                            if el.inputTag.isEmpty { err(netPath, "The PID has no process-value operand.") }
                            if el.outTag.isEmpty { err(netPath, "The PID has no output operand.") }
                        case .jmp:
                            if el.tag.isEmpty { err(netPath, "The jump has no label name.") }
                            else if !block.networks.contains(where: { $0.output.kind == .label && $0.output.tag == el.tag }) {
                                err(netPath, "The label '\(el.tag)' does not exist in this block.")
                            }
                        case .label, .ret:
                            break
                        }
                        if (el.kind == .coil || el.kind == .coilSet),
                           let t = device.tags.first(where: { $0.name == el.tag }),
                           t.address.hasPrefix("%I") {
                            err(netPath, "The operand '\(el.tag)' has an input address (\(t.address)) and cannot be written.")
                        }
                    }
                }
            }
        }
        return out
    }
}
