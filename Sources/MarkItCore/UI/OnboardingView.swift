import SwiftUI

struct OnboardingView: View {
    let onRequestPermission: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 40))
            Text("MarkIt needs Accessibility access")
                .font(.headline)
            Text("This lets MarkIt see when you select text anywhere, so it can copy it automatically. It never reads or stores anything except what you actively select.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                onRequestPermission()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(24)
        .frame(width: 340)
    }
}
