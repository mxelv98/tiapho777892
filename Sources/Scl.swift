import Foundation

/// A teaching subset of SCL (v4.0): assignments, IF / ELSIF / ELSE,
/// arithmetic and logic over the project's Bool and numeric operands —
/// enough for students to write the same logic in text that they wire
/// in LAD. Anything outside the subset is skipped statement by statement
/// instead of failing the whole block.

enum SclValue {
    case bool(Bool)
    case num(Double)
    var asNum: Double { switch self { case .bool(let b): return b ? 1 : 0; case .num(let n): return n } }
    var asBool: Bool { switch self { case .bool(let b): return b; case .num(let n): return n != 0 } }
}

enum SclEngine {
    static func run(source: String, sim: Simulator) {
        let tokens = tokenize(source)
        var parser = SclParser(tokens: tokens, sim: sim)
        parser.run()
    }

    // MARK: Tokenizer

    enum Tok: Equatable {
        case ident(String)
        case number(Double)
        case symbol(String)   // := == <> <= >= < > + - * / ( ) ;
        case keyword(String)  // AND OR NOT XOR IF THEN ELSIF ELSE END_IF TRUE FALSE
    }

    static func tokenize(_ src: String) -> [Tok] {
        var out: [Tok] = []
        let chars = Array(src)
        var i = 0
        let keywords: Set<String> = ["AND", "OR", "NOT", "XOR", "IF", "THEN", "ELSIF", "ELSE", "END_IF", "TRUE", "FALSE"]
        while i < chars.count {
            let c = chars[i]
            if c.isWhitespace { i += 1; continue }
            if c == "/", i + 1 < chars.count, chars[i + 1] == "/" {
                while i < chars.count && chars[i] != "\n" { i += 1 }
                continue
            }
            if c == "(", i + 1 < chars.count, chars[i + 1] == "*" {
                i += 2
                while i + 1 < chars.count && !(chars[i] == "*" && chars[i + 1] == ")") { i += 1 }
                i += 2
                continue
            }
            if c == "\"" {
                var j = i + 1
                var s = ""
                while j < chars.count && chars[j] != "\"" { s.append(chars[j]); j += 1 }
                out.append(.ident(s))
                i = j + 1
                continue
            }
            if c.isLetter || c == "_" || c == "%" {
                var j = i
                var s = ""
                while j < chars.count && (chars[j].isLetter || chars[j].isNumber || chars[j] == "_" || chars[j] == "." || chars[j] == "%") {
                    s.append(chars[j]); j += 1
                }
                let up = s.uppercased()
                if keywords.contains(up) && !s.contains(".") && !s.contains("%") {
                    out.append(.keyword(up))
                } else {
                    out.append(.ident(s))
                }
                i = j
                continue
            }
            if c.isNumber {
                var j = i
                var s = ""
                while j < chars.count && (chars[j].isNumber || chars[j] == ".") { s.append(chars[j]); j += 1 }
                out.append(.number(Double(s) ?? 0))
                i = j
                continue
            }
            if i + 1 < chars.count {
                let two = String([c, chars[i + 1]])
                if [":=", "==", "<>", "<=", ">="].contains(two) {
                    out.append(.symbol(two)); i += 2; continue
                }
            }
            if "<>+-*/();".contains(c) {
                out.append(.symbol(String(c))); i += 1; continue
            }
            i += 1
        }
        return out
    }
}

// MARK: - Parser / evaluator

private struct SclParser {
    let tokens: [SclEngine.Tok]
    let sim: Simulator
    var pos = 0

    mutating func run() {
        _ = parseStatements(execute: true, stopAt: [])
    }

    private var peek: SclEngine.Tok? { pos < tokens.count ? tokens[pos] : nil }

    private mutating func advance() -> SclEngine.Tok? {
        defer { pos += 1 }
        return peek
    }

    private mutating func expectSymbol(_ s: String) {
        if peek == .symbol(s) { pos += 1 }
    }

    /// Returns the stop keyword that ended the block (not consumed).
    @discardableResult
    private mutating func parseStatements(execute: Bool, stopAt: Set<String>) -> String? {
        while let t = peek {
            if case .keyword(let k) = t {
                if stopAt.contains(k) { return k }
                if k == "IF" { parseIf(execute: execute); continue }
                pos += 1
                continue
            }
            if case .ident = t { parseAssignment(execute: execute); continue }
            pos += 1
        }
        return nil
    }

    private mutating func parseAssignment(execute: Bool) {
        guard case .ident(let name) = advance() ?? .symbol("") else { return }
        guard peek == .symbol(":=") else {
            // Not an assignment — skip to the next semicolon.
            while let t = peek, t != .symbol(";") { pos += 1 }
            expectSymbol(";")
            return
        }
        pos += 1
        let v = parseExpr()
        expectSymbol(";")
        if execute { sim.sclSet(name, v) }
    }

    private mutating func parseIf(execute: Bool) {
        pos += 1 // IF
        var anyTaken = false
        var cond = parseExpr()
        expectKeyword("THEN")
        var branchOn = execute && cond.asBool
        if branchOn { anyTaken = true }
        var stop = parseStatements(execute: branchOn, stopAt: ["ELSIF", "ELSE", "END_IF"])
        while stop == "ELSIF" {
            pos += 1
            cond = parseExpr()
            expectKeyword("THEN")
            branchOn = execute && !anyTaken && cond.asBool
            if branchOn { anyTaken = true }
            stop = parseStatements(execute: branchOn, stopAt: ["ELSIF", "ELSE", "END_IF"])
        }
        if stop == "ELSE" {
            pos += 1
            _ = parseStatements(execute: execute && !anyTaken, stopAt: ["END_IF"])
        }
        if peek == .keyword("END_IF") { pos += 1 }
        expectSymbol(";")
    }

    private mutating func expectKeyword(_ k: String) {
        if peek == .keyword(k) { pos += 1 }
    }

    // Expression grammar, lowest to highest precedence:
    // OR → AND → NOT → comparison → additive → multiplicative → unary → primary

    private mutating func parseExpr() -> SclValue { parseOr() }

    private mutating func parseOr() -> SclValue {
        var l = parseAnd()
        while peek == .keyword("OR") || peek == .keyword("XOR") {
            let isXor = peek == .keyword("XOR")
            pos += 1
            let r = parseAnd()
            l = .bool(isXor ? (l.asBool != r.asBool) : (l.asBool || r.asBool))
        }
        return l
    }

    private mutating func parseAnd() -> SclValue {
        var l = parseNot()
        while peek == .keyword("AND") {
            pos += 1
            let r = parseNot()
            l = .bool(l.asBool && r.asBool)
        }
        return l
    }

    private mutating func parseNot() -> SclValue {
        if peek == .keyword("NOT") {
            pos += 1
            return .bool(!parseNot().asBool)
        }
        return parseCmp()
    }

    private mutating func parseCmp() -> SclValue {
        let l = parseAdd()
        guard case .symbol(let op) = peek ?? .ident(""), ["==", "<>", "<", "<=", ">", ">="].contains(op) else { return l }
        pos += 1
        let r = parseAdd()
        let a = l.asNum, b = r.asNum
        switch op {
        case "==": return .bool(abs(a - b) < 0.0001)
        case "<>": return .bool(abs(a - b) >= 0.0001)
        case "<": return .bool(a < b)
        case "<=": return .bool(a <= b)
        case ">": return .bool(a > b)
        default: return .bool(a >= b)
        }
    }

    private mutating func parseAdd() -> SclValue {
        var l = parseMul()
        while case .symbol(let op) = peek ?? .ident(""), op == "+" || op == "-" {
            pos += 1
            let r = parseMul()
            l = .num(op == "+" ? l.asNum + r.asNum : l.asNum - r.asNum)
        }
        return l
    }

    private mutating func parseMul() -> SclValue {
        var l = parseUnary()
        while case .symbol(let op) = peek ?? .ident(""), op == "*" || op == "/" {
            pos += 1
            let r = parseUnary()
            l = .num(op == "*" ? l.asNum * r.asNum : (r.asNum == 0 ? 0 : l.asNum / r.asNum))
        }
        return l
    }

    private mutating func parseUnary() -> SclValue {
        if peek == .symbol("-") {
            pos += 1
            return .num(-parseUnary().asNum)
        }
        return parsePrimary()
    }

    private mutating func parsePrimary() -> SclValue {
        guard let t = advance() else { return .num(0) }
        switch t {
        case .number(let n): return .num(n)
        case .keyword("TRUE"): return .bool(true)
        case .keyword("FALSE"): return .bool(false)
        case .ident(let name): return sim.sclValue(name)
        case .symbol("("):
            let v = parseExpr()
            expectSymbol(")")
            return v
        default: return .num(0)
        }
    }
}
