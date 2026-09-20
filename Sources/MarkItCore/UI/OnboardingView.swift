import SwiftUI

struct OnboardingView: View {
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
            Text("MarkIt needs Accessibility access")
                .font(.headline)
            Text("If MarkIt is already in the list and switched on, that row is an older copy. Turn it off, click − to remove it, then + and choose this MarkIt. Then quit and reopen the app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open Accessibility Settings") {
                onRequestPermission()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 380)
    }
}
