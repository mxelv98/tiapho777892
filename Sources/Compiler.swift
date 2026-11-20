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
            for block in device.blocks {
                let blockPath = "\(device.name) › Program blocks › \(block.name) (\(block.type)\(block.number))"
                for (ni, net) in block.networks.enumerated() {
                    let netPath = blockPath + " › Network \(ni + 1)"
                    let elements = net.series + net.parallel + [net.output]
                    if net.series.isEmpty && net.parallel.isEmpty {
                        warn(netPath, "The network contains no instruction in the main rung.")
                    }
                    for el in elements {
                        switch el.kind {
                        case .contactNO, .contactNC, .coil, .coilSet:
                            if el.tag.isEmpty { err(netPath, "An instruction has no operand.") }
                            else if !defined.contains(el.tag) { err(netPath, "The tag '\(el.tag)' is not defined in the tag table.") }
                        case .coilReset:
                            if el.tag.isEmpty { err(netPath, "A reset coil has no operand.") }
                        case .ton:
                            if el.instance.isEmpty { err(netPath, "The timer has no instance name.") }
                            if el.tag.isEmpty { err(netPath, "The timer output (Q) has no tag.") }
                            else if !defined.contains(el.tag) { err(netPath, "The tag '\(el.tag)' is not defined in the tag table.") }
                        case .ctu:
                            if el.instance.isEmpty { err(netPath, "The counter has no instance name.") }
                            if !el.inputTag.isEmpty && !defined.contains(el.inputTag) {
                                err(netPath, "The counter input tag '\(el.inputTag)' is not defined in the tag table.")
                            }
                            if el.tag.isEmpty { err(netPath, "The counter output (Q) has no tag.") }
                            else if !defined.contains(el.tag) { err(netPath, "The tag '\(el.tag)' is not defined in the tag table.") }
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
