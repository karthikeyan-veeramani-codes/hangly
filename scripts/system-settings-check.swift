// Approval-required verification helper. Read-only unless an explicit --set is supplied.
// Uses native System Settings controls, never writes private preference databases.
import AppKit
import ApplicationServices

@main
struct SettingsCheck {
    @MainActor static func main() async {
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }; return args[i + 1] }
        let section = value("--section") ?? "display"
        let links = ["motion": "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Motion", "display": "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_Display", "voiceover": "x-apple.systempreferences:com.apple.preference.universalaccess?Seeing_VoiceOver", "desktop": "x-apple.systempreferences:com.apple.Desktop-Settings.extension"]
        var report: [String: Any] = ["section": section, "accessibilityTrusted": AXIsProcessTrusted()]
        guard AXIsProcessTrusted(), let link = links[section], let url = URL(string: link) else { report["status"] = "BLOCKED"; emit(report); return }
        _ = NSWorkspace.shared.open(url)
        try? await Task.sleep(for: .seconds(2))
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first else { report["status"] = "BLOCKED: System Settings not running"; emit(report); return }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        func attribute(_ node: AXUIElement, _ key: String) -> CFTypeRef? { var result: CFTypeRef?; guard AXUIElementCopyAttributeValue(node, key as CFString, &result) == .success else { return nil }; return result }
        func label(_ node: AXUIElement) -> String {
            var parts = [kAXTitleAttribute, kAXDescriptionAttribute, kAXHelpAttribute].compactMap { attribute(node, $0) as? String }
            if let title = attribute(node, kAXTitleUIElementAttribute), CFGetTypeID(title) == AXUIElementGetTypeID() {
                let element = unsafeBitCast(title, to: AXUIElement.self)
                parts += [kAXTitleAttribute, kAXValueAttribute].compactMap { attribute(element, $0) as? String }
            }
            return parts.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let allowed = ["Reduce motion", "Increase contrast", "VoiceOver", "Stage Manager", "Display", "Motion", "Desktop & Dock", "Accessibility", "Back", "Turn On", "Cancel", "Stage Manager"]
        func controls() -> [(AXUIElement, String, String, Int?)] {
            var result: [(AXUIElement, String, String, Int?)] = [], visited = 0
            func walk(_ node: AXUIElement, _ depth: Int) {
                guard depth < 35, visited < 4000 else { return }; visited += 1
                let role = attribute(node, kAXRoleAttribute) as? String ?? ""
                let text = label(node)
                if allowed.contains(where: { text.localizedCaseInsensitiveContains($0) }) {
                    result.append((node, role, text, (attribute(node, kAXValueAttribute) as? NSNumber)?.intValue))
                }
                if let children = attribute(node, kAXChildrenAttribute) as? [AXUIElement] { for child in children { walk(child, depth + 1) } }
            }
            walk(root, 0); return result
        }
        func find(_ text: String) -> (AXUIElement, String, String, Int?)? {
            let candidates = controls().filter { ["AXCheckBox", "AXSwitch"].contains($0.1) && $0.2.localizedCaseInsensitiveContains(text) }
            return candidates.first { $0.2.components(separatedBy: " · ").contains { $0.caseInsensitiveCompare(text) == .orderedSame } } ?? candidates.first
        }
        if let path = value("--navigate") {
            var navigation: [String: Any] = [:]
            for target in path.components(separatedBy: "/") where ["Display", "Motion", "VoiceOver", "Desktop & Dock", "Accessibility", "Back", "Turn On", "Cancel", "Stage Manager"].contains(target) {
                let candidates = controls().filter { ["AXButton", "AXRow"].contains($0.1) && ($0.2.components(separatedBy: " · ").contains(where: { $0.caseInsensitiveCompare(target) == .orderedSame }) || (target == "Back" && $0.2.localizedCaseInsensitiveContains("Back"))) }
                if let node = candidates.first { navigation[target] = AXUIElementPerformAction(node.0, kAXPressAction as CFString).rawValue; try? await Task.sleep(for: .seconds(2)) }
                else { navigation[target] = "Named native navigation control not found" }
            }
            report["navigation"] = navigation
        }
        report["controls"] = controls().map { ["role":$0.1, "label":$0.2, "value":$0.3 ?? -1] }
        if let target = value("--set"), allowed.contains(where: { $0.caseInsensitiveCompare(target) == .orderedSame }), let wanted = value("--value").flatMap(Int.init), [0,1].contains(wanted) {
            guard let control = find(target), let before = control.3 else { report["status"] = "BLOCKED: named native switch not found"; emit(report); return }
            report["target"] = target; report["before"] = before; report["requested"] = wanted
            var names: CFArray?
            AXUIElementCopyActionNames(control.0, &names)
            report["targetActions"] = names as? [String] ?? []
            report["targetEnabled"] = (attribute(control.0, kAXEnabledAttribute) as? NSNumber)?.boolValue ?? false
            var parents: [[String: Any]] = []
            var current = control.0
            var scrollArea: AXUIElement?
            for _ in 0..<5 {
                guard let raw = attribute(current, kAXParentAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { break }
                current = unsafeBitCast(raw, to: AXUIElement.self)
                var actions: CFArray?; AXUIElementCopyActionNames(current, &actions)
                let role = attribute(current,kAXRoleAttribute) as? String ?? ""
                parents.append(["role":role, "actions":actions as? [String] ?? []])
                if role == "AXScrollArea", scrollArea == nil { scrollArea = current }
            }
            report["targetParents"] = parents
            func rect(_ node: AXUIElement) -> CGRect? {
                guard let rawPoint = attribute(node,kAXPositionAttribute), let rawSize = attribute(node,kAXSizeAttribute), CFGetTypeID(rawPoint) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }
                var point = CGPoint.zero, size = CGSize.zero
                guard AXValueGetValue(unsafeBitCast(rawPoint,to:AXValue.self),.cgPoint,&point), AXValueGetValue(unsafeBitCast(rawSize,to:AXValue.self),.cgSize,&size) else { return nil }
                return CGRect(origin:point,size:size)
            }
            if target == "Stage Manager", let scrollArea {
                var scrolls = [String]()
                for _ in 0..<5 {
                    guard let node = find(target)?.0, let targetRect = rect(node), let viewport = rect(scrollArea) else { break }
                    report["targetY"] = targetRect.midY; report["viewportMinY"] = viewport.minY; report["viewportMaxY"] = viewport.maxY
                    if targetRect.midY >= viewport.minY && targetRect.midY <= viewport.maxY { break }
                    let action = targetRect.midY > viewport.maxY ? "AXScrollDownByPage" : "AXScrollUpByPage"
                    let result = AXUIElementPerformAction(scrollArea,action as CFString);scrolls.append(action + ":" + String(result.rawValue))
                    if result != .success {
                        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier, !CGEventSource.buttonState(.combinedSessionState, button:.left), let original = CGEvent(source:nil)?.location else { break }
                        let location = CGPoint(x:viewport.midX,y:viewport.midY)
                        CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:location,mouseButton:.left)?.post(tap:.cghidEventTap)
                        let event = CGEvent(scrollWheelEvent2Source:nil,units:.line,wheelCount:1,wheel1:targetRect.midY > viewport.maxY ? -5 : 5,wheel2:0,wheel3:0)
                        event?.location = location; event?.post(tap:.cghidEventTap)
                        try? await Task.sleep(for:.milliseconds(500))
                        CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:original,mouseButton:.left)?.post(tap:.cghidEventTap)
                        scrolls.append("Owned native viewport wheel fallback")
                    }
                    try? await Task.sleep(for:.milliseconds(500))
                }
                report["nativeScrolls"] = scrolls
            }
            var settable = DarwinBoolean(false)
            AXUIElementIsAttributeSettable(control.0, kAXValueAttribute as CFString, &settable)
            report["valueSettable"] = settable.boolValue
            if before != wanted {
                report["pressResult"] = AXUIElementPerformAction(find(target)?.0 ?? control.0, kAXPressAction as CFString).rawValue
                try? await Task.sleep(for: .seconds(2))
                if target == "Stage Manager", find(target)?.3 != wanted, let node = find(target)?.0, let targetRect = rect(node), let scrollArea, let viewport = rect(scrollArea), NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier, !CGEventSource.buttonState(.combinedSessionState,button:.left), let original = CGEvent(source:nil)?.location {
                    let point = CGPoint(x:targetRect.maxX - min(10,targetRect.width / 2),y:targetRect.midY)
                    if viewport.contains(point) {
                        CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
                        CGEvent(mouseEventSource:nil,mouseType:.leftMouseDown,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
                        try? await Task.sleep(for:.milliseconds(80))
                        CGEvent(mouseEventSource:nil,mouseType:.leftMouseUp,mouseCursorPosition:point,mouseButton:.left)?.post(tap:.cghidEventTap)
                        try? await Task.sleep(for:.seconds(1))
                        CGEvent(mouseEventSource:nil,mouseType:.mouseMoved,mouseCursorPosition:original,mouseButton:.left)?.post(tap:.cghidEventTap)
                        report["ownedVisibleKnobClick"] = true
                    }
                }
            }
            report["afterControls"] = controls().map { ["role":$0.1, "label":$0.2, "value":$0.3 ?? -1] }
            report["after"] = find(target)?.3 ?? -1
            report["status"] = (find(target)?.3 == wanted) ? "PASS" : "FAIL: native switch did not reach requested value"
        } else { report["status"] = "READ ONLY" }
        report["systemReduceMotion"] = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        report["systemIncreaseContrast"] = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        report["systemVoiceOver"] = NSWorkspace.shared.isVoiceOverEnabled
        emit(report)
    }
    static func emit(_ report: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]), let text = String(data: data, encoding: .utf8) { print(text) }
        else { print("{\"status\":\"FAIL: report encoding\"}") }
    }
}
