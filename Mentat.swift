import Cocoa

// mentat menu bar app: estimates Claude Code cost from local logs on a timer and shows it.
let configDir = NSString(string: "~/.config/mentat").expandingTildeInPath
let configPath = configDir + "/config.json"
let appVersion = "2.0.0"

// Log file: ~/Library/Logs/Mentat/mentat.log (standard macOS place; Console.app shows it under Log Reports).
// One line per event: time, level, message. Rotates at 512 KB (keeps one old file). Never logs secrets.
let logDir = NSHomeDirectory() + "/Library/Logs/Mentat"
let logPath = logDir + "/mentat.log"
let logQueue = DispatchQueue(label: "mentat.log")
var loggingEnabled = true

func logEvent(_ level: String, _ message: String) {
    guard loggingEnabled else { return }
    logQueue.sync {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
        if let size = (try? fm.attributesOfItem(atPath: logPath))?[.size] as? Int, size > 512 * 1024 {
            try? fm.removeItem(atPath: logPath + ".1")
            try? fm.moveItem(atPath: logPath, toPath: logPath + ".1")
        }
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        f.formatOptions = [.withInternetDateTime, .withSpaceBetweenDateAndTime]
        let line = "\(f.string(from: Date())) \(level) \(message)\n"
        if let h = FileHandle(forWritingAtPath: logPath) {
            h.seekToEndOfFile(); h.write(Data(line.utf8)); h.closeFile()
        } else {
            try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }
}


// MARK: - Usage estimate (port of usage.py)
// Output: first line = menu bar title (may hold colour spans RS level US text GS),
// then '---' and detail lines ('--' prefix = indented).

var lastLogged: [String: String] = [:]
/// Log a message only when it differs from the last one for this topic, so a repeating problem does not fill the file.
func logOnce(_ topic: String, _ level: String, _ message: String) {
    if lastLogged[topic] == message { return }
    lastLogged[topic] = message
    logEvent(level, message)
}

func num(_ v: Any?) -> Double { (v as? NSNumber)?.doubleValue ?? 0 }

func usageText() -> String {
    let started = Date()
    let cfg: [String: Any] = {
        guard let d = FileManager.default.contents(atPath: configPath) else {
            logOnce("config", "WARN", "config file not found or not readable: \(configPath). Using defaults.")
            return [:]
        }
        guard let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else {
            logOnce("config", "ERROR", "config file is not valid JSON: \(configPath). Using defaults.")
            return [:]
        }
        logOnce("config", "INFO", "config OK")
        return o
    }()
    let prices = (cfg["prices"] as? [String: [Double]]) ?? [:]
    let w5m = (cfg["cache_write_5m_multiplier"] as? NSNumber)?.doubleValue ?? 1.25
    let w1h = (cfg["cache_write_1h_multiplier"] as? NSNumber)?.doubleValue ?? 2.0
    let limit = num(cfg["monthly_limit"])

    let now = Date()
    let cal = Calendar.current
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(identifier: "UTC")!
    let names = ["5h", "today", "7d", "month"]
    let starts: [String: Date] = [
        "5h": now.addingTimeInterval(-5 * 3600),
        "today": cal.startOfDay(for: now),
        "7d": now.addingTimeInterval(-7 * 86400),
        "month": utc.date(from: utc.dateComponents([.year, .month], from: now))!,
    ]
    let wanted = ((cfg["windows"] as? [String]) ?? names).filter { starts[$0] != nil }
    let oldest = starts.values.min()!

    func price(_ model: String) -> [Double]? {
        let best = prices.keys.filter { model.hasPrefix($0) }.max { $0.count < $1.count }
        return best.flatMap { prices[$0] }.flatMap { $0.count >= 3 ? $0 : nil }
    }

    var cost: [String: [String: Double]] = [:]
    for n in names { cost[n] = [:] }
    var unknown = Set<String>()
    var seen = Set<String>()

    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let isoPlain = ISO8601DateFormatter()
    let usageMarker = Data("\"usage\"".utf8)

    let root = NSString(string: "~/.claude/projects").expandingTildeInPath
    let fm = FileManager.default
    if let en = fm.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) {
        for case let url as URL in en where url.pathExtension == "jsonl" {
            guard let mod = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  mod >= oldest, let data = try? Data(contentsOf: url) else { continue }
            for line in data.split(separator: 0x0A, omittingEmptySubsequences: true) {
                let lineData = Data(line)
                if lineData.range(of: usageMarker) == nil { continue }
                guard let d = (try? JSONSerialization.jsonObject(with: lineData)) as? [String: Any],
                      let m = d["message"] as? [String: Any],
                      let u = m["usage"] as? [String: Any], !u.isEmpty else { continue }
                let mid = m["id"] as? String, rid = d["requestId"] as? String
                if mid != nil || rid != nil {
                    let key = (mid ?? "") + "|" + (rid ?? "")
                    if seen.contains(key) { continue }
                    seen.insert(key)
                }
                guard let tsStr = d["timestamp"] as? String,
                      let ts = iso.date(from: tsStr) ?? isoPlain.date(from: tsStr) else { continue }
                let model = m["model"] as? String ?? ""
                guard let p = price(model) else {
                    if !model.isEmpty && !model.hasPrefix("<") { unknown.insert(model) }
                    continue
                }
                var c5 = 0.0, c1 = 0.0
                if let cc = u["cache_creation"] as? [String: Any], !cc.isEmpty {
                    c1 = num(cc["ephemeral_1h_input_tokens"]); c5 = num(cc["ephemeral_5m_input_tokens"])
                } else {
                    c5 = num(u["cache_creation_input_tokens"])
                }
                let usd = (num(u["input_tokens"]) * p[0] + num(u["output_tokens"]) * p[1]
                           + num(u["cache_read_input_tokens"]) * p[2]
                           + c5 * p[0] * w5m + c1 * p[0] * w1h) / 1e6
                for (w, s) in starts where ts >= s { cost[w]![model, default: 0] += usd }
            }
        }
    }

    var tot: [String: Double] = [:]
    for n in names { tot[n] = cost[n]!.values.reduce(0, +) }

    // Alerts: percent of budget. Month budget = limit. Day budget = limit / working days (Mon-Fri).
    let levels = ["yellow", "orange", "red"]
    let pct = (cfg["alert_percent"] as? [String: Any]) ?? ["yellow": 70, "orange": 80, "red": 90]
    let days = cal.range(of: .day, in: .month, for: now)?.count ?? 30
    let comps = cal.dateComponents([.year, .month], from: now)
    var workdays = 0
    for day in 1...days {
        var c = comps; c.day = day
        if let dt = cal.date(from: c), (2...6).contains(cal.component(.weekday, from: dt)) { workdays += 1 }
    }
    workdays = max(workdays, 1)
    let budgets = ["day": limit / Double(workdays), "month": limit]
    var alertLines: [String] = []
    var worst = -1
    var scopeLevel: [String: Int] = [:]
    for (scope, window) in [("day", "today"), ("month", "month")] {
        guard let budget = budgets[scope], budget > 0 else { continue }
        let used = tot[window]! / budget * 100
        var hit = -1
        for (i, name) in levels.enumerated() {
            if let t = pct[name] as? NSNumber, used >= t.doubleValue { hit = i }
        }
        if hit >= 0 {
            alertLines.append(String(format: "ALERT %@: %@ ($%.0f is %.0f%% of $%.0f budget)", scope, levels[hit].uppercased(), tot[window]!, used, budget))
            worst = max(worst, hit)
            scopeLevel[scope] = hit
        }
    }

    // Title: {today} {month} {limit} {pct} {5h} {7d}. A day alert colours today. A month alert colours month and pct.
    var fields: [String: String] = [:]
    for n in names { fields[n] = String(format: "%.0f", tot[n]!) }
    fields["limit"] = String(format: "%.0f", limit)
    fields["pct"] = limit > 0 ? String(format: "%.0f%%", tot["month"]! / limit * 100) : "-"
    func paint(_ level: Int, _ text: String) -> String { "\u{1e}\(levels[level])\u{1f}\(text)\u{1d}" }
    let colored = ["today": scopeLevel["day"] ?? -1, "month": scopeLevel["month"] ?? -1, "pct": scopeLevel["month"] ?? -1]
    var title = (cfg["title"] as? String) ?? "${month}"
    for (k, v) in fields {
        if let lv = colored[k], lv >= 0 {
            title = title.replacingOccurrences(of: "${" + k + "}", with: paint(lv, "$" + v))
            title = title.replacingOccurrences(of: "{" + k + "}", with: paint(lv, v))
        } else {
            title = title.replacingOccurrences(of: "{" + k + "}", with: v)
        }
    }
    if worst >= 0 && !title.contains("\u{1e}") { title = paint(worst, title) }

    for scope in ["day", "month"] {
        let now = scopeLevel[scope].map { levels[$0] } ?? "none"
        let window = scope == "day" ? "today" : "month"
        let used = budgets[scope]! > 0 ? tot[window]! / budgets[scope]! * 100 : 0
        let before = lastLogged["alert-" + scope] ?? "none"
        if before != now {
            logEvent(now == "none" || levels.firstIndex(of: now)! < (levels.firstIndex(of: before) ?? -1) ? "INFO" : "WARN",
                     String(format: "alert %@: %@ -> %@ ($%.0f is %.0f%% of budget $%.0f)", scope, before, now, tot[window]!, used, budgets[scope]!))
            lastLogged["alert-" + scope] = now
        }
    }
    if !unknown.isEmpty { logOnce("unknown", "WARN", "no price for model(s): " + unknown.sorted().joined(separator: ", ") + ". Cost is not counted.") }
    let took = Date().timeIntervalSince(started)
    if took > 5 { logEvent("WARN", String(format: "refresh was slow: %.1f s", took)) }

    var out = [title, "---"]
    out += alertLines
    if !alertLines.isEmpty { out.append("---") }
    for w in wanted {
        out.append(String(format: "%@: $%.2f", w, tot[w]!))
        for (model, usd) in cost[w]!.sorted(by: { $0.value > $1.value }) {
            out.append(String(format: "--%@: $%.2f", model, usd))
        }
    }
    out.append("---")
    out.append(String(format: "Budget: $%.0f/month, $%.0f/day (%d working days)", limit, budgets["day"]!, workdays))
    out.append("Estimate at API list prices, this Mac only")
    if !unknown.isEmpty { out.append("No price for: " + unknown.sorted().joined(separator: ", ")) }
    return out.joined(separator: "\n") + "\n"
}

final class App: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var timer: Timer?

    func applicationWillTerminate(_ n: Notification) { logEvent("INFO", "quit") }

    func applicationDidFinishLaunching(_ n: Notification) {
        item.button?.title = "…"
        logEvent("INFO", "start version \(appVersion) pid \(ProcessInfo.processInfo.processIdentifier) macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        installEditMenu()
        refresh()
        schedule()
    }

    func refreshSeconds() -> TimeInterval {
        guard let data = FileManager.default.contents(atPath: configPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let s = obj["refresh_seconds"] as? Double, s >= 10 else { return 300 }
        return s
    }

    func schedule() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshSeconds(), repeats: true) { [weak self] _ in self?.refresh() }
    }

    var isRefreshing = false // touched on the main thread only

    @objc func refresh() {
        if isRefreshing { return }
        isRefreshing = true
        DispatchQueue.global().async {
            let text = usageText()
            DispatchQueue.main.async {
                self.isRefreshing = false
                self.render(text)
            }
        }
    }

    // Start at login: a LaunchAgent plist. macOS starts the app at the next login when the file exists.
    var loginPlistPath: String { NSHomeDirectory() + "/Library/LaunchAgents/com.mentat.plist" }

    func loginEnabled() -> Bool { FileManager.default.fileExists(atPath: loginPlistPath) }

    @objc func toggleLogin(_ sender: NSMenuItem) {
        let fm = FileManager.default
        do {
            if loginEnabled() {
                try fm.removeItem(atPath: loginPlistPath)
                logEvent("INFO", "start at login: off")
            } else {
                guard let exe = Bundle.main.executablePath else { return }
                try? fm.createDirectory(atPath: logDir, withIntermediateDirectories: true)
                let plist: [String: Any] = ["Label": "com.mentat", "ProgramArguments": [exe], "RunAtLoad": true,
                                            "StandardOutPath": logDir + "/launchd.log", "StandardErrorPath": logDir + "/launchd.log"]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try fm.createDirectory(atPath: (loginPlistPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: loginPlistPath), options: .atomic)
                logEvent("INFO", "start at login: on")
            }
        } catch {
            let a = NSAlert()
            logEvent("ERROR", "start at login change failed: \(error.localizedDescription)")
            a.messageText = "Start at login failed"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
        sender.state = loginEnabled() ? .on : .off
    }

    func alertColor(_ name: String) -> NSColor? {
        switch name {
        case "yellow": return NSColor(srgbRed: 1.0, green: 0.85, blue: 0.0, alpha: 1)
        case "orange": return NSColor(srgbRed: 1.0, green: 0.5, blue: 0.0, alpha: 1)
        case "red": return NSColor(srgbRed: 1.0, green: 0.15, blue: 0.15, alpha: 1)
        default: return nil
        }
    }

    // Title text may hold colour spans: RS(0x1e) level US(0x1f) text GS(0x1d).
    func setTitle(_ raw: String) {
        let font = NSFont.menuBarFont(ofSize: 0)
        let out = NSMutableAttributedString()
        var rest = Substring(raw)
        while let rs = rest.firstIndex(of: "\u{1e}") {
            out.append(NSAttributedString(string: String(rest[..<rs]), attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
            let afterRS = rest.index(after: rs)
            guard let us = rest[afterRS...].firstIndex(of: "\u{1f}"),
                  let gs = rest[us...].firstIndex(of: "\u{1d}") else { rest = rest[afterRS...]; continue }
            let level = String(rest[afterRS..<us])
            let text = String(rest[rest.index(after: us)..<gs])
            out.append(NSAttributedString(string: text, attributes: [
                .font: font, .foregroundColor: alertColor(level) ?? NSColor.labelColor]))
            rest = rest[rest.index(after: gs)...]
        }
        if out.length == 0 && !raw.contains("\u{1e}") {
            item.button?.attributedTitle = NSAttributedString(string: "")
            item.button?.title = raw
            return
        }
        out.append(NSAttributedString(string: String(rest), attributes: [.font: font, .foregroundColor: NSColor.labelColor]))
        item.button?.attributedTitle = out
    }

    func render(_ text: String) {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        while lines.last == "" { lines.removeLast() }
        setTitle(lines.first ?? "?")
        let menu = NSMenu()
        for line in lines.dropFirst() {
            if line == "---" { menu.addItem(.separator()); continue }
            let indent = line.hasPrefix("--")
            let mi = NSMenuItem(title: (indent ? "    " : "") + (indent ? String(line.dropFirst(2)) : line), action: nil, keyEquivalent: "")
            mi.isEnabled = false
            menu.addItem(mi)
        }
        menu.addItem(.separator())
        let r = NSMenuItem(title: "Refresh", action: #selector(refresh), keyEquivalent: "r"); r.target = self
        let o = NSMenuItem(title: "Open config", action: #selector(openConfig), keyEquivalent: ","); o.target = self
        let lg = NSMenuItem(title: "Open log", action: #selector(openLog), keyEquivalent: "l"); lg.target = self
        let l = NSMenuItem(title: "Start at login", action: #selector(toggleLogin(_:)), keyEquivalent: ""); l.target = self
        l.state = loginEnabled() ? .on : .off
        let q = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        [r, o, lg, l, q].forEach { menu.addItem($0) }
        item.menu = menu
        schedule() // pick up a changed refresh_seconds
    }

    var editor: NSWindow?
    var fields: [String: NSTextField] = [:]
    var windowChecks: [String: NSButton] = [:]
    var statusLabel: NSTextField?
    let allWindows = ["5h", "today", "7d", "month"]
    let levels = ["yellow", "orange", "red"]

    func loadConfig() -> [String: Any] {
        guard let data = FileManager.default.contents(atPath: configPath),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return obj
    }

    func numString(_ v: Any?) -> String { (v as? NSNumber)?.stringValue ?? "" }

    func makeField(_ key: String, _ value: String, width: CGFloat = 70) -> NSTextField {
        let f = NSTextField(string: value)
        f.translatesAutoresizingMaskIntoConstraints = false
        f.widthAnchor.constraint(equalToConstant: width).isActive = true
        fields[key] = f
        return f
    }

    @objc func openConfig() {
        if let w = editor {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            return
        }
        let cfg = loadConfig()
        fields = [:]; windowChecks = [:]
        func label(_ s: String) -> NSTextField { NSTextField(labelWithString: s) }

        let enabled = cfg["windows"] as? [String] ?? allWindows
        let checks = allWindows.map { name -> NSButton in
            let b = NSButton(checkboxWithTitle: name, target: nil, action: nil)
            b.state = enabled.contains(name) ? .on : .off
            windowChecks[name] = b
            return b
        }
        let checkRow = NSStackView(views: checks)
        checkRow.spacing = 14

        let pct = cfg["alert_percent"] as? [String: Any] ?? [:]
        var alertViews: [NSView] = []
        for l in levels {
            alertViews.append(label(l.capitalized))
            alertViews.append(makeField("alert.\(l)", numString(pct[l])))
        }
        let alertRow = NSStackView(views: alertViews)
        alertRow.spacing = 8

        func note(_ text: String) -> NSTextField {
            let n = NSTextField(wrappingLabelWithString: text)
            n.textColor = .secondaryLabelColor
            n.font = .systemFont(ofSize: 11)
            n.preferredMaxLayoutWidth = 430
            n.translatesAutoresizingMaskIntoConstraints = false
            n.widthAnchor.constraint(equalToConstant: 430).isActive = true
            return n
        }
        let none = NSGridCell.emptyContentView

        let grid = NSGridView(views: [
            [label("Refresh (seconds)"), makeField("refresh_seconds", numString(cfg["refresh_seconds"]))],
            [none, note("How often Mentat reads the Claude Code logs and updates the menu bar. Minimum 10.")],
            [label("Monthly limit ($)"), makeField("monthly_limit", numString(cfg["monthly_limit"]))],
            [none, note("Your monthly budget in USD. All alert levels are a percent of this number.")],
            [label("Title template"), makeField("title", cfg["title"] as? String ?? "", width: 360)],
            [none, note("Text shown in the menu bar. Variables: {today} {month} {limit} {pct} {5h} {7d}. {pct} is the month cost as a percent of the limit.")],
            [label("Show windows"), checkRow],
            [none, note("Time windows listed in the menu. 5h = last 5 hours. today = since midnight. 7d = last 7 days. month = since the 1st.")],
            [label("Alerts (% of budget)"), alertRow],
            [none, note("The title changes colour when cost reaches this percent of the budget. Month budget = monthly limit. Day budget = limit / working days this month (Mon-Fri, holidays not removed). A day alert colours the today value. A month alert colours the month value and percent. Empty = level off.")],
            [label("Cache write 5m ×"), makeField("cache_write_5m_multiplier", numString(cfg["cache_write_5m_multiplier"]))],
            [none, note("Price multiplier on the input price for text written to the 5-minute prompt cache. Anthropic list value: 1.25.")],
            [label("Cache write 1h ×"), makeField("cache_write_1h_multiplier", numString(cfg["cache_write_1h_multiplier"]))],
            [none, note("Same, for the 1-hour prompt cache. Anthropic list value: 2.0. Change the cache values only if Anthropic changes its prices.")],
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .leading

        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 700),
                         styleMask: [.titled, .closable, .miniaturizable],
                         backing: .buffered, defer: false)
        w.title = "Mentat settings"
        w.isReleasedWhenClosed = false
        w.delegate = self
        let content = w.contentView!
        content.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 22),
        ])

        let label2 = NSTextField(labelWithString: "")
        label2.frame = NSRect(x: 22, y: 50, width: 556, height: 17)
        label2.textColor = .systemRed
        content.addSubview(label2)

        let file = NSButton(title: "Open file (prices)…", target: self, action: #selector(openConfigFile))
        file.frame = NSRect(x: 16, y: 10, width: 160, height: 28)
        file.bezelStyle = .rounded
        content.addSubview(file)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(closeEditor))
        cancel.frame = NSRect(x: 406, y: 10, width: 84, height: 28)
        cancel.keyEquivalent = "\u{1b}"
        cancel.bezelStyle = .rounded
        content.addSubview(cancel)

        let save = NSButton(title: "Save", target: self, action: #selector(saveConfig))
        save.frame = NSRect(x: 496, y: 10, width: 84, height: 28)
        save.keyEquivalent = "\r"
        save.bezelStyle = .rounded
        content.addSubview(save)

        editor = w; statusLabel = label2
        w.center()
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }

    @objc func openLog() {
        if !FileManager.default.fileExists(atPath: logPath) { logEvent("INFO", "log opened") }
        NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
    }

    @objc func openConfigFile() { NSWorkspace.shared.open(URL(fileURLWithPath: configPath)) }

    func fail(_ msg: String) { statusLabel?.stringValue = msg }

    @objc func saveConfig() {
        func text(_ k: String) -> String { (fields[k]?.stringValue ?? "").trimmingCharacters(in: .whitespaces) }
        func num(_ k: String) -> Double? { Double(text(k)) }

        guard let refreshSecs = num("refresh_seconds"), refreshSecs >= 10 else { return fail("Refresh must be a number, 10 or more.") }
        guard let limit = num("monthly_limit"), limit >= 0 else { return fail("Monthly limit must be a number, 0 or more.") }
        guard let m5 = num("cache_write_5m_multiplier"), m5 > 0 else { return fail("Cache write 5m multiplier must be above 0.") }
        guard let m1 = num("cache_write_1h_multiplier"), m1 > 0 else { return fail("Cache write 1h multiplier must be above 0.") }
        let chosen = allWindows.filter { windowChecks[$0]?.state == .on }
        if chosen.isEmpty { return fail("Select at least one window.") }

        var alerts: [String: Double] = [:]
        var prev = -Double.infinity
        for l in levels {
            let v = text("alert.\(l)")
            if v.isEmpty { continue }
            guard let n = Double(v), n >= 0 else { return fail("\(l): enter a percent, 0 or more.") }
            if n < prev { return fail("Alerts must rise: yellow <= orange <= red.") }
            prev = n
            alerts[l] = n
        }

        var cfg = loadConfig() // keep keys this form does not show (prices, notes)
        cfg["refresh_seconds"] = refreshSecs
        cfg["monthly_limit"] = limit
        cfg["title"] = fields["title"]?.stringValue ?? ""
        cfg["windows"] = chosen
        cfg["alert_percent"] = alerts
        cfg.removeValue(forKey: "alerts")
        cfg["cache_write_5m_multiplier"] = m5
        cfg["cache_write_1h_multiplier"] = m1
        do {
            let data = try JSONSerialization.data(withJSONObject: cfg, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try data.write(to: URL(fileURLWithPath: configPath), options: .atomic)
        } catch {
            return fail("Save failed: \(error.localizedDescription)")
        }
        logEvent("INFO", "settings saved")
        closeEditor()
        refresh()
    }

    @objc func closeEditor() { editor?.close() }

    func windowWillClose(_ n: Notification) {
        editor = nil; statusLabel = nil; fields = [:]; windowChecks = [:]
    }

    func installEditMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = main
    }
}

if CommandLine.arguments.contains("--print") { // debug: print the usage text and exit
    loggingEnabled = false
    print(usageText(), terminator: "")
    exit(0)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = App()
app.delegate = delegate
app.run()
