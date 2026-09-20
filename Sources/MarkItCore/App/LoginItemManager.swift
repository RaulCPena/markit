import ServiceManagement
import os.log

enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            os_log("MarkIt: failed to set login item enabled=%{public}@: %{public}@", "\(enabled)", "\(error)")
        }
    }
}
