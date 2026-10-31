import AppKit
import Combine
import TetherCore

@MainActor
final class PreferencesStore: ObservableObject {
    @Published private(set) var snapshot: Preferences
    var value: Preferences {
        get { snapshot }
        set {
            var clean = newValue
            clean.sanitize()
            snapshot = clean
            flush()
        }
    }
    @Published var notice: String?
    private let defaults: UserDefaults
    static let key = "Tether.preferences.v1"
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                snapshot = try Preferences.decode(data)
                if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], object["schemaVersion"] as? Int == 1,
                   defaults.data(forKey: Self.key + ".migrationBackup") == nil {
                    defaults.set(data, forKey: Self.key + ".migrationBackup")
                }
            }
            catch { snapshot = Preferences(); notice = "Saved preferences could not be read. Defaults were restored." }
        } else { snapshot = Preferences() }
    }
    func flush() {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: Self.key) }
    }
    func editCharm(_ edit: (inout Charm) -> Void) {
        guard let i = value.charms.firstIndex(where: { $0.id == value.selectedID }) else { return }
        var prefs = value; edit(&prefs.charms[i]); value = prefs
    }
}

extension PreferencesStore {
    func perform(_ operation: (inout Preferences) throws -> Void) {
        do { var next = value; try operation(&next); value = next }
        catch { notice = error.localizedDescription }
    }
    func addToDesktop(_ templateID: String) { perform { _ = try $0.add(templateID: templateID) } }
    func duplicate(_ id: String) { perform { _ = try $0.duplicate(id) } }
    func removeFromDesktop(_ id: String) { perform { $0.removeFromDesktop(id) } }
}
