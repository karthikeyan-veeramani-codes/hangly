import AppKit
import ApplicationServices
@main struct OwnedKeyboardCheck {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count > 1, let pid = Int32(CommandLine.arguments[1]), AXIsProcessTrusted(), let app = NSRunningApplication(processIdentifier: pid) else { print("{\"status\":\"BLOCKED\"}"); return }
        _ = app.activate(options: []); try await Task.sleep(for: .milliseconds(500))
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { print("{\"status\":\"BLOCKED: target not frontmost; no keys sent\"}"); return }
        func key(_ code: CGKeyCode, _ flags: CGEventFlags = []) {
            for down in [true,false] { let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down); event?.flags = flags; event?.post(tap: .cghidEventTap) }
        }
        func focus() -> [String: Any] {
            var item: CFTypeRef?
            guard AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &item) == .success, let item, CFGetTypeID(item) == AXUIElementGetTypeID() else { return ["status":"no focused element"] }
            let element = unsafeBitCast(item, to: AXUIElement.self)
            var owner: pid_t = 0; AXUIElementGetPid(element, &owner)
            guard owner == pid else { return ["status":"focus outside owned process; no content read"] }
            var record: [String: Any] = ["owned":true]
            for name in [kAXRoleAttribute,kAXTitleAttribute,kAXDescriptionAttribute] { var value: CFTypeRef?; if AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success, let text = value as? String { record[name] = text } }
            return record
        }
        var rows = [[String: Any]](); rows.append(["action":"initial","focus":focus()])
        for index in 1...6 { key(48); try await Task.sleep(for: .milliseconds(180)); rows.append(["action":"Tab \(index)","focus":focus()]) }
        if NSWorkspace.shared.isVoiceOverEnabled {
            for index in 1...3 {
                let control = CGEvent(keyboardEventSource:nil,virtualKey:59,keyDown:true);control?.flags = .maskControl;control?.post(tap:.cghidEventTap)
                let option = CGEvent(keyboardEventSource:nil,virtualKey:58,keyDown:true);option?.flags = [.maskControl,.maskAlternate];option?.post(tap:.cghidEventTap)
                key(124,[.maskControl,.maskAlternate])
                let optionUp = CGEvent(keyboardEventSource:nil,virtualKey:58,keyDown:false);optionUp?.flags = .maskControl;optionUp?.post(tap:.cghidEventTap)
                let controlUp = CGEvent(keyboardEventSource:nil,virtualKey:59,keyDown:false);controlUp?.flags = [];controlUp?.post(tap:.cghidEventTap)
                try await Task.sleep(for:.milliseconds(180));rows.append(["action":"VoiceOver next \(index)","focus":focus()])
            }
        }
        let report: [String:Any] = ["voiceOverEnabled":NSWorkspace.shared.isVoiceOverEnabled,"events":rows,"scope":"Only owned focused elements read; actual Tab/VO-next commands. Spoken audio and VoiceOver cursor order not certified from keyboard-focus attributes."]
        print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8) ?? "{}")
    }
}
