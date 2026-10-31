import Foundation

public enum CharmKind: String, Codable, CaseIterable, Sendable { case sprout, cloud, comet, moon, jelly, custom }
public enum AnimationQuality: Int, Codable, CaseIterable, Sendable { case economical = 30, smooth = 60 }
public struct RGBA: Codable, Equatable, Sendable {
    public var red: Double; public var green: Double; public var blue: Double; public var alpha: Double
    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) { self.red = red; self.green = green; self.blue = blue; self.alpha = alpha }
    public mutating func sanitize() { red = bounded(red, 0...1, 0.57); green = bounded(green, 0...1, 0.49); blue = bounded(blue, 0...1, 0.38); alpha = bounded(alpha, 0.1...1, 1) }
}
public func bounded(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
    value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
}
public struct Charm: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: CharmKind
    public var assetFilename: String? = nil
    public var templateID: String? = nil
    public var size: Double = 88
    public var ropeLength: Double = 220
    public var anchorX: Double = 0.75
    public var displayID: String? = nil
    public var visible: Bool = true
    public var opacity: Double = 1
    public var attachmentX: Double = 0.5
    public var attachmentY: Double = 0.12
    public var ropeWidth: Double = 2.5
    public var ropeColor: RGBA = .init(0.57, 0.49, 0.38)
    public var gravity: Double = 1100
    public var damping: Double = 0.9
    public var windIntensity: Double = 0
    public var swingIntensity: Double = 1
    public init(id: String, name: String, kind: CharmKind, assetFilename: String? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.assetFilename = assetFilename
    }
    public var sourceID: String { templateID ?? id }
    public mutating func sanitize() {
        name = String(name.prefix(60))
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { name = "Companion" }
        size = bounded(size, 44...160, 88); ropeLength = bounded(ropeLength, 80...600, 220)
        anchorX = bounded(anchorX, 0.05...0.95, 0.75); opacity = bounded(opacity, 0.2...1, 1)
        attachmentX = bounded(attachmentX, 0...1, 0.5); attachmentY = bounded(attachmentY, 0...1, 0.12)
        ropeWidth = bounded(ropeWidth, 1...8, 2.5); ropeColor.sanitize()
        gravity = bounded(gravity, 100...2500, 1100); damping = bounded(damping, 0.2...3, 0.9)
        windIntensity = bounded(windIntensity, 0...400, 0); swingIntensity = bounded(swingIntensity, 0.1...2, 1)
        if let file = assetFilename, file != URL(fileURLWithPath: file).lastPathComponent || !["png", "webp"].contains(URL(fileURLWithPath: file).pathExtension.lowercased()) { assetFilename = nil }
    }
    private enum CodingKeys: String, CodingKey { case id, name, kind, assetFilename, templateID, size, ropeLength, anchorX, displayID, visible, opacity, attachmentX, attachmentY, ropeWidth, ropeColor, gravity, damping, windIntensity, swingIntensity }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decode(CharmKind.self, forKey: .kind)
        assetFilename = try c.decodeIfPresent(String.self, forKey: .assetFilename)
        templateID = try c.decodeIfPresent(String.self, forKey: .templateID)
        size = try c.decodeIfPresent(Double.self, forKey: .size) ?? 88
        ropeLength = try c.decodeIfPresent(Double.self, forKey: .ropeLength) ?? 220
        anchorX = try c.decodeIfPresent(Double.self, forKey: .anchorX) ?? 0.75
        displayID = try c.decodeIfPresent(String.self, forKey: .displayID)
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        opacity = try c.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        attachmentX = try c.decodeIfPresent(Double.self, forKey: .attachmentX) ?? 0.5
        attachmentY = try c.decodeIfPresent(Double.self, forKey: .attachmentY) ?? 0.12
        ropeWidth = try c.decodeIfPresent(Double.self, forKey: .ropeWidth) ?? 2.5
        ropeColor = try c.decodeIfPresent(RGBA.self, forKey: .ropeColor) ?? .init(0.57, 0.49, 0.38)
        gravity = try c.decodeIfPresent(Double.self, forKey: .gravity) ?? 1100
        damping = try c.decodeIfPresent(Double.self, forKey: .damping) ?? 0.9
        windIntensity = try c.decodeIfPresent(Double.self, forKey: .windIntensity) ?? 0
        swingIntensity = try c.decodeIfPresent(Double.self, forKey: .swingIntensity) ?? 1
    }
}
public enum LibraryError: LocalizedError {
    case limit, missing, builtin
    public var errorDescription: String? {
        switch self { case .limit: "The companion limit has been reached. Remove a companion, increase the desktop limit, or forget unused arrangements in Settings."; case .missing: "This character is no longer available."; case .builtin: "Built-in artwork cannot be deleted." }
    }
}
public struct Preferences: Codable, Equatable, Sendable {
    public static let builtins: [Charm] = [
        Charm(id: "sprout", name: "Pip the Sprout", kind: .sprout),
        Charm(id: "cloud", name: "Mallow the Cloud", kind: .cloud),
        Charm(id: "comet", name: "Sol the Comet", kind: .comet),
        Charm(id: "moon", name: "Luna the Moon", kind: .moon),
        Charm(id: "jelly", name: "Nori the Jelly", kind: .jelly)
    ].map { original in
        var charm = original
        switch charm.kind { case .cloud: charm.attachmentY = 0.22; case .comet: charm.attachmentY = 0.07; case .moon: charm.attachmentY = 0.08; default: break }
        return charm
    }
    public var schemaVersion: Int = 2
    public var charms: [Charm] = Array(Self.builtins.prefix(3))
    public var library: [Charm] = Self.builtins
    public var activeIDs: [String] = ["sprout"]
    public var selectedID: String = "sprout"
    public var visible: Bool = true
    public var paused: Bool = false
    public var wind: Bool = false
    public var damping: Double = 0.9
    public var respectReduceMotion: Bool = true
    public var maxActive: Int = 6
    public var showOnStartup: Bool = true
    public var restoreSession: Bool = true
    public var statusShowsCount: Bool = true
    public var animationEnabled: Bool = true
    public var animationSpeed: Double = 1
    public var idleReactions: Bool = true
    public var blinking: Bool = true
    public var sleepAfter: Double = 120
    public var quality: AnimationQuality = .smooth
    public var pauseWhenHidden: Bool = true
    public var reduceOnBattery: Bool = true
    public init() {}
    public var selected: Charm { charms.first(where: { $0.id == selectedID }) ?? Self.builtins[0] }
    public var active: [Charm] { activeIDs.compactMap { id in charms.first { $0.id == id } } }
    public mutating func sanitize() {
        var ids = Set<String>()
        charms = Array(charms.filter { !$0.id.isEmpty && ids.insert($0.id).inserted }.prefix(64))
        if charms.isEmpty { charms = Array(Self.builtins.prefix(3)) }
        for i in charms.indices { charms[i].sanitize() }
        ids.removeAll()
        library = Array(library.filter { !$0.id.isEmpty && ids.insert($0.id).inserted }.prefix(100))
        for i in library.indices { library[i].sanitize() }
        if !charms.contains(where: { $0.id == selectedID }) { selectedID = charms[0].id }
        maxActive = min(12, max(1, maxActive))
        ids.removeAll()
        activeIDs = Array(activeIDs.filter { id in charms.contains { $0.id == id } && ids.insert(id).inserted }.prefix(maxActive))
        damping = bounded(damping, 0.2...3, 0.9)
        animationSpeed = bounded(animationSpeed, 0.25...2, 1)
        sleepAfter = sleepAfter == 0 ? 0 : bounded(sleepAfter, 15...3600, 120)
    }
    public mutating func applyStartupPolicy() {
        visible = showOnStartup
        if !restoreSession { activeIDs = [selectedID] }
        sanitize()
    }
    @discardableResult public mutating func add(templateID: String) throws -> String {
        guard activeIDs.count < maxActive else { throw LibraryError.limit }
        guard let template = library.first(where: { $0.id == templateID }) else { throw LibraryError.missing }
        if let existing = charms.first(where: { $0.sourceID == templateID && !activeIDs.contains($0.id) }) {
            activeIDs.append(existing.id); selectedID = existing.id
            if let i = charms.firstIndex(where: { $0.id == existing.id }) {
                charms[i].visible = true
                let occupied = active.filter { $0.id != existing.id && $0.displayID == existing.displayID }.map(\.anchorX)
                if occupied.contains(where: { abs($0 - existing.anchorX) < 0.1 }), let free = [0.25, 0.5, 0.75, 0.38, 0.62, 0.85, 0.12].first(where: { candidate in !occupied.contains { abs($0 - candidate) < 0.1 } }) {
                    charms[i].anchorX = free
                }
            }
            return existing.id
        }
        guard charms.count < 64 else { throw LibraryError.limit }
        var instance = template; instance.id = UUID().uuidString; instance.templateID = templateID
        instance.anchorX = [0.25, 0.5, 0.75, 0.38, 0.62, 0.85][activeIDs.count % 6]
        charms.append(instance); activeIDs.append(instance.id); selectedID = instance.id
        return instance.id
    }
    @discardableResult public mutating func duplicate(_ id: String) throws -> String {
        guard activeIDs.count < maxActive, charms.count < 64 else { throw LibraryError.limit }
        guard var instance = charms.first(where: { $0.id == id }) else { throw LibraryError.missing }
        instance.templateID = instance.sourceID; instance.id = UUID().uuidString
        instance.name = String((instance.name + " copy").prefix(60)); instance.anchorX = min(0.95, instance.anchorX + (instance.anchorX > 0.8 ? -0.12 : 0.12))
        instance.visible = true
        charms.append(instance); activeIDs.append(instance.id); selectedID = instance.id
        return instance.id
    }
    public mutating func removeFromDesktop(_ id: String) { activeIDs.removeAll { $0 == id } }
    public mutating func deleteInstance(_ id: String) {
        activeIDs.removeAll { $0 == id }; charms.removeAll { $0.id == id }; sanitize()
    }
    public mutating func deleteArtwork(_ id: String) throws {
        guard let template = library.first(where: { $0.id == id }) else { throw LibraryError.missing }
        guard template.kind == .custom else { throw LibraryError.builtin }
        let removed = Set(charms.filter { $0.sourceID == id }.map(\.id))
        charms.removeAll { removed.contains($0.id) }; activeIDs.removeAll { removed.contains($0) }
        library.removeAll { $0.id == id }; sanitize()
    }
    public mutating func restoreBuiltins() {
        let custom = library.filter { $0.kind == .custom }
        library = Self.builtins + custom
    }
    private enum CodingKeys: String, CodingKey { case schemaVersion, charms, library, activeIDs, selectedID, visible, paused, wind, damping, respectReduceMotion, maxActive, showOnStartup, restoreSession, statusShowsCount, animationEnabled, animationSpeed, idleReactions, blinking, sleepAfter, quality, pauseWhenHidden, reduceOnBattery }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 2
        charms = try c.decodeIfPresent([Charm].self, forKey: .charms) ?? Array(Self.builtins.prefix(3))
        library = try c.decodeIfPresent([Charm].self, forKey: .library) ?? Self.builtins
        activeIDs = try c.decodeIfPresent([String].self, forKey: .activeIDs) ?? ["sprout"]
        selectedID = try c.decodeIfPresent(String.self, forKey: .selectedID) ?? "sprout"
        visible = try c.decodeIfPresent(Bool.self, forKey: .visible) ?? true
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused) ?? false
        wind = try c.decodeIfPresent(Bool.self, forKey: .wind) ?? false
        damping = try c.decodeIfPresent(Double.self, forKey: .damping) ?? 0.9
        respectReduceMotion = try c.decodeIfPresent(Bool.self, forKey: .respectReduceMotion) ?? true
        maxActive = try c.decodeIfPresent(Int.self, forKey: .maxActive) ?? 6
        showOnStartup = try c.decodeIfPresent(Bool.self, forKey: .showOnStartup) ?? true
        restoreSession = try c.decodeIfPresent(Bool.self, forKey: .restoreSession) ?? true
        statusShowsCount = try c.decodeIfPresent(Bool.self, forKey: .statusShowsCount) ?? true
        animationEnabled = try c.decodeIfPresent(Bool.self, forKey: .animationEnabled) ?? true
        animationSpeed = try c.decodeIfPresent(Double.self, forKey: .animationSpeed) ?? 1
        idleReactions = try c.decodeIfPresent(Bool.self, forKey: .idleReactions) ?? true
        blinking = try c.decodeIfPresent(Bool.self, forKey: .blinking) ?? true
        sleepAfter = try c.decodeIfPresent(Double.self, forKey: .sleepAfter) ?? 120
        quality = try c.decodeIfPresent(AnimationQuality.self, forKey: .quality) ?? .smooth
        pauseWhenHidden = try c.decodeIfPresent(Bool.self, forKey: .pauseWhenHidden) ?? true
        reduceOnBattery = try c.decodeIfPresent(Bool.self, forKey: .reduceOnBattery) ?? true
        guard (1...2).contains(schemaVersion) else { throw CocoaError(.coderReadCorrupt) }
        if schemaVersion == 1 {
            activeIDs = [selectedID]
            library = Self.builtins + charms.filter { $0.kind == .custom }
            for i in charms.indices { charms[i].damping = damping }
            showOnStartup = visible
            schemaVersion = 2
        }
    }
    public static func decode(_ data: Data) throws -> Self {
        var result = try JSONDecoder().decode(Self.self, from: data)
        result.sanitize(); return result
    }
}
