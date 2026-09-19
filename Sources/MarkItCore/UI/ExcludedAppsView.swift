import SwiftUI
import AppKit

struct RunningAppOption {
    let bundleID: String
    let name: String
}

final class ExcludedAppsModel: ObservableObject {
    @Published var excludedBundleIDs: [String] = []
    @Published var selectedRunningAppBundleID: String?
    @Published var runningAppOptions: [RunningAppOption] = []

    private let exclusions: ExclusionList

    init(exclusions: ExclusionList) {
        self.exclusions = exclusions
        refresh()
    }

    func refresh() {
        excludedBundleIDs = Array(exclusions.bundleIDs).sorted()
        runningAppOptions = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier, let name = app.localizedName else { return nil }
                return RunningAppOption(bundleID: bundleID, name: name)
            }
            .sorted { $0.name < $1.name }
    }

    func addSelected() {
        guard let bundleID = selectedRunningAppBundleID else { return }
        exclusions.add(bundleID)
        selectedRunningAppBundleID = nil
        refresh()
    }

    func remove(_ bundleID: String) {
        exclusions.remove(bundleID)
        refresh()
    }
}

struct ExcludedAppsView: View {
    @ObservedObject var model: ExcludedAppsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Excluded Apps").font(.headline)
            List {
                ForEach(model.excludedBundleIDs, id: \.self) { bundleID in
                    HStack {
                        Text(bundleID)
                        Spacer()
                        Button("Remove") { model.remove(bundleID) }
                    }
                }
            }
            .frame(minHeight: 150)

            HStack {
                Picker("Add running app", selection: $model.selectedRunningAppBundleID) {
                    Text("Choose an app…").tag(String?.none)
                    ForEach(model.runningAppOptions, id: \.bundleID) { app in
                        Text(app.name).tag(String?.some(app.bundleID))
                    }
                }
                Button("Add") { model.addSelected() }
                    .disabled(model.selectedRunningAppBundleID == nil)
            }
        }
        .padding()
        .frame(width: 360)
    }
}
