import Foundation

/// PLCSIM-lite: a scan-cycle evaluator for the taught LAD subset.
/// One scan every 100 ms while RUN is on. Contacts read the current value
/// table; coils write it. TON/CTU keep runtime state per instance.
/// Teaching simplification (documented): in a network where a CTU feeds a
/// TON, the counter is reset when the TON hold finishes (Q falls) — the
/// same batch behaviour as the SortingStation SCL twin.
final class Simulator: ObservableObject {
    @Published var values: [String: Bool] = [:]
    @Published var counts: [String: Int] = [:]
    @Published var powered = false
    @Published var running = false

    private var tonElapsed: [String: Double] = [:]
    private var tonQ: [String: Bool] = [:]
    private var ctuCV: [String: Int] = [:]
    private var ctuLastCU: [String: Bool] = [:]
    private var timer: Timer?
    private var device: PlcDevice?

    func attach(_ device: PlcDevice) {
        self.device = device
        if values.isEmpty { reset() }
    }

    func reset() {
        values = [:]; counts = [:]
        tonElapsed = [:]; tonQ = [:]; ctuCV = [:]; ctuLastCU = [:]
        if let d = device { for t in d.tags { values[t.name] = false } }
    }

    func power(_ on: Bool) {
        powered = on
        if !on { running = false; stopTimer() }
    }

    func run(_ on: Bool) {
        guard powered else { return }
        running = on
        if on { startTimer() } else { stopTimer() }
    }

    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.scan() }
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }

    func setInput(_ tag: String, _ v: Bool) { values[tag] = v }

    private func contact(_ el: LadElement) -> Bool {
        let v = values[el.tag] ?? false
        return el.kind == .contactNC ? !v : v
    }

    private func scan() {
        guard let d = device, let main = d.blocks.first(where: { $0.type == "OB" }) else { return }
        let dt = 0.1
        for net in main.networks {
            var power = true
            for el in net.series {
                // Timers and counters in the rung are driven by the power
                // flowing into them, then contribute their Q to the rung.
                if el.kind == .ctu { applyCounter(el, cuPower: power) }
                if el.kind == .ton { advanceTimer(el, power: power, net: net, dt: dt) }
                power = power && elementValue(el)
            }
            if !net.parallel.isEmpty {
                var branch = true
                for el in net.parallel {
                    if el.kind == .ctu { applyCounter(el, cuPower: branch) }
                    branch = branch && elementValue(el)
                }
                power = power || branch
            }
            applyOutput(net.output, power: power, net: net, dt: dt)
        }
        counts = ctuCV
    }

    private func elementValue(_ el: LadElement) -> Bool {
        switch el.kind {
        case .contactNO, .contactNC: return contact(el)
        case .ton: return tonQ[el.instance] ?? false
        case .ctu: return (ctuCV[el.instance] ?? 0) >= el.presetValue
        default: return values[el.tag] ?? false
        }
    }

    private func advanceTimer(_ el: LadElement, power: Bool, net: LadNetwork, dt: Double) {
        let wasQ = tonQ[el.instance] ?? false
        if power {
            tonElapsed[el.instance] = (tonElapsed[el.instance] ?? 0) + dt
        } else {
            tonElapsed[el.instance] = 0
        }
        let q = power && (tonElapsed[el.instance] ?? 0) >= el.presetSeconds
        tonQ[el.instance] = q
        if !el.tag.isEmpty { values[el.tag] = q }
        if wasQ && !q {
            // hold finished: reset counters feeding this timer in the same network
            for s in net.series where s.kind == .ctu { ctuCV[s.instance] = 0 }
        }
    }

    private func applyOutput(_ el: LadElement, power: Bool, net: LadNetwork, dt: Double) {
        switch el.kind {
        case .coil: values[el.tag] = power
        case .coilSet: if power { values[el.tag] = true }
        case .coilReset:
            if power {
                if ctuCV[el.tag] != nil { ctuCV[el.tag] = 0 }
                else { values[el.tag] = false }
            }
        case .ton: advanceTimer(el, power: power, net: net, dt: dt)
        case .ctu: applyCounter(el, cuPower: power)
        default: break
        }
    }

    /// CU comes from the counter's input tag (rising edge) when one is set,
    /// otherwise from the rung power flowing into the counter.
    private func applyCounter(_ el: LadElement, cuPower: Bool) {
        let cu = el.inputTag.isEmpty ? cuPower : (values[el.inputTag] ?? false)
        let last = ctuLastCU[el.instance] ?? false
        if cu && !last { ctuCV[el.instance] = (ctuCV[el.instance] ?? 0) + 1 }
        ctuLastCU[el.instance] = cu
        if !el.tag.isEmpty { values[el.tag] = (ctuCV[el.instance] ?? 0) >= el.presetValue }
    }
}
