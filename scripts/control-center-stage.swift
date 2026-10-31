import AppKit
import ApplicationServices
@main struct StageControl {
    @MainActor static func main() async throws {
        guard AXIsProcessTrusted(), let app=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.controlcenter").first else { print("{\"status\":\"BLOCKED\"}");return }
        let root=AXUIElementCreateApplication(app.processIdentifier)
        func attr(_ node:AXUIElement,_ key:String)->CFTypeRef? { var value:CFTypeRef?;guard AXUIElementCopyAttributeValue(node,key as CFString,&value) == .success else{return nil};return value }
        func nodes()->[(AXUIElement,String,String,Int?)] {
            var result=[(AXUIElement,String,String,Int?)](), visited=0
            func walk(_ node:AXUIElement,_ depth:Int) {
                guard depth<20,visited<1500 else{return};visited+=1
                let text=[kAXTitleAttribute,kAXDescriptionAttribute,kAXHelpAttribute].compactMap{attr(node,$0) as? String}.joined(separator:" · ")
                if text.localizedCaseInsensitiveContains("Control Center") || text.localizedCaseInsensitiveContains("Stage Manager") { result.append((node,attr(node,kAXRoleAttribute) as? String ?? "",text,(attr(node,kAXValueAttribute) as? NSNumber)?.intValue)) }
                if let children=attr(node,kAXChildrenAttribute) as? [AXUIElement] { for child in children{walk(child,depth+1)} }
            }
            walk(root,0);return result
        }
        var report:[String:Any]=[:]
        if let control=nodes().first(where:{$0.2.localizedCaseInsensitiveContains("Control Center") && ["AXMenuBarItem","AXButton"].contains($0.1)}) {
            report["openResult"]=AXUIElementPerformAction(control.0,kAXPressAction as CFString).rawValue
            try await Task.sleep(for:.seconds(1))
        }
        report["stageControls"]=nodes().filter{$0.2.localizedCaseInsensitiveContains("Stage Manager")}.map{["role":$0.1,"label":$0.2,"value":$0.3 ?? -1]}
        if CommandLine.arguments.contains("--toggle"), let control=nodes().first(where:{$0.2.localizedCaseInsensitiveContains("Stage Manager") && $0.1=="AXCheckBox" && $0.3 != nil}) {
            report["before"]=control.3
            report["pressResult"]=AXUIElementPerformAction(control.0,kAXPressAction as CFString).rawValue
            try await Task.sleep(for:.seconds(1))
            report["status"]="NATIVE TOGGLE ATTEMPTED; verify exact main-switch state separately"
        } else {report["status"]="READ ONLY / no unambiguous Stage Manager checkbox"}
        print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8) ?? "{}")
        CGEvent(keyboardEventSource:nil,virtualKey:53,keyDown:true)?.post(tap:.cghidEventTap)
        CGEvent(keyboardEventSource:nil,virtualKey:53,keyDown:false)?.post(tap:.cghidEventTap)
    }
}
