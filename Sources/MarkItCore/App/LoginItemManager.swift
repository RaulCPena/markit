import ServiceManagement
import os.log

public enum LoginItemManager {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static func setEnabled(_ enabled: Bool) {
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
