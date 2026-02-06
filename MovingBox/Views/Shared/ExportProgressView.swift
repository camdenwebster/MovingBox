import SwiftUI

struct ExportProgressView: View {
    let phase: String
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.5)

                VStack(spacing: 8) {
                    Text(phase.isEmpty ? "Preparing export..." : phase)
                        .font(.headline)
                        .accessibilityIdentifier("export-progress-phase-text")
                    Text("Please wait while we prepare your export...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if progress > 0 {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .tint(.green)
                            .padding(.horizontal, 40)
                            .padding(.top, 16)
                            .accessibilityIdentifier("export-progress-value")

                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Export")
            .movingBoxNavigationTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("export-cancel-button")
                }
            }
        }
    }
}
