import AppKit
import ScreenCaptureKit
import ApplicationServices
@main struct CaptureOwnedWindows {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count > 2, let pid = Int32(CommandLine.arguments[1]), CGPreflightScreenCaptureAccess() else { print("{\"status\":\"BLOCKED: no existing capture access\"}"); return }
        let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let content = try await SCShareableContent.excludingDesktopWindows(true,onScreenWindowsOnly:true)
        let windows = content.windows.filter { $0.owningApplication?.processID == pid && $0.frame.width > 100 && $0.frame.height > 100 }
        var evidence = [[String:Any]]()
        let onScreen = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
        for window in windows {
            let configuration = SCStreamConfiguration(); configuration.width = Int(window.frame.width * 2); configuration.height = Int(window.frame.height * 2); configuration.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter:SCContentFilter(desktopIndependentWindow:window),configuration:configuration)
            let name = String(window.windowID)+"-owned.png"
            try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])?.write(to:folder.appendingPathComponent(name))
            evidence.append(["title":window.title ?? "","windowNumber":window.windowID,"windowServerOnScreen":onScreen.contains { ($0[kCGWindowNumber as String] as? UInt32)==window.windowID },"width":window.frame.width,"height":window.frame.height,"image":name])
        }
        let report:[String:Any] = ["status":"CAPTURED OWNED WINDOWS","windows":evidence,"scope":"Only target process windows, no other application content or full desktop captured."]
        print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8) ?? "{}")
    }
}
