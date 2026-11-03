import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// Launch at login through SMAppService. macOS stores the state, so nothing is saved here.
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin(service: SMAppService.mainApp)

    @Published private(set) var status: SMAppService.Status
    @Published private(set) var error: String?

    private let service: LoginItemService

    init(service: LoginItemService) {
        self.service = service
        status = service.status
    }

    /// Waiting for approval counts as on: the user asked for it, and macOS only needs confirmation.
    var isEnabled: Bool { status == .enabled || status == .requiresApproval }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled { try service.register() } else { try service.unregister() }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        status = service.status
    }

    /// Reads the state again, in case it changed in System Settings.
    func refresh() { status = service.status }
}
