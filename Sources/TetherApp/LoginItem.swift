import AppKit
import Combine
import ServiceManagement

@MainActor
final class LoginItem: ObservableObject {
    @Published var enabled = SMAppService.mainApp.status == .enabled
    @Published var message: String?
    func refresh() { enabled = SMAppService.mainApp.status == .enabled }
    func setEnabled(_ flag: Bool) {
        do {
            if flag { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            refresh()
            if SMAppService.mainApp.status == .requiresApproval {
                message = "Approve Tether in System Settings → General → Login Items."
            } else { message = nil }
        } catch { refresh(); message = error.localizedDescription }
    }
}
