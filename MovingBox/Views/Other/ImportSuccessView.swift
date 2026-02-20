import SwiftUI

struct ImportSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var router: Router
    @Environment(\.colorScheme) private var colorScheme

    let importResult: DataManager.ImportResult

    @State private var showCheckmark = false
    @State private var showConfetti = false

    private var isDatabaseRestore: Bool {
        importResult.requiresRestart
    }

    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if let image = UIImage(named: backgroundImage) {
                Image(uiImage: image)
                    .resizable()
                    .renderingMode(.original)
                    .interpolation(.medium)
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.5)
            }

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
            }

            VStack(spacing: 24) {

                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: showCheckmark ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 80))
                        .foregroundStyle(.green)
                        .scaleEffect(showCheckmark ? 1 : 0.5)
                        .opacity(showCheckmark ? 1 : 0)

                    Text(isDatabaseRestore ? "Restore Staged!" : "Import Complete!")
                        .font(.title.bold())

                    if isDatabaseRestore {
                        Text("Restart the app to apply this database backup.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding()
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            }
                    } else {
                        VStack(spacing: 12) {
                            if importResult.itemCount > 0 {
                                ResultRow(
                                    icon: "cube.box.fill",
                                    count: importResult.itemCount,
                                    label: importResult.itemCount == 1 ? "item" : "items"
                                )
                            }

                            if importResult.locationCount > 0 {
                                ResultRow(
                                    icon: "map.fill",
                                    count: importResult.locationCount,
                                    label: importResult.locationCount == 1 ? "location" : "locations"
                                )
                            }

                            if importResult.labelCount > 0 {
                                ResultRow(
                                    icon: "tag.fill",
                                    count: importResult.labelCount,
                                    label: importResult.labelCount == 1 ? "label" : "labels"
                                )
                            }

                            if importResult.homeCount > 0 {
                                ResultRow(
                                    icon: "house.fill",
                                    count: importResult.homeCount,
                                    label: importResult.homeCount == 1 ? "home" : "homes"
                                )
                            }

                            if importResult.insurancePolicyCount > 0 {
                                ResultRow(
                                    icon: "doc.text.fill",
                                    count: importResult.insurancePolicyCount,
                                    label: importResult.insurancePolicyCount == 1 ? "policy" : "policies"
                                )
                            }
                        }
                        .padding()
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        }
                    }
                }
                .padding()
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)))

                Spacer()

                Group {
                    if isDatabaseRestore {
                        VStack(spacing: 12) {
                            Button {
                                exit(0)
                            } label: {
                                Text("Restart Now")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .tint(.green)
                            .backport.glassProminentButtonStyle()
                            .accessibilityIdentifier("import-success-restart-now-button")

                            Button {
                                navigateToDashboard()
                            } label: {
                                Text("Later")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                            .tint(.secondary)
                            .backport.glassProminentButtonStyle()
                            .accessibilityIdentifier("import-success-later-button")
                        }
                    } else {
                        Button {
                            navigateToDashboard()
                        } label: {
                            Text("Go to Dashboard")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .tint(.green)
                        .backport.glassProminentButtonStyle()
                        .accessibilityIdentifier("import-success-dashboard-button")
                    }
                }
                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                .padding()
            }
            .padding(.horizontal, 60)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showCheckmark = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showConfetti = true
                }
            }
        }
    }

    private func navigateToDashboard() {
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            router.navigateToRoot()
        }
    }
}

struct ResultRow: View {
    let icon: String
    let count: Int
    let label: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 30)

            Text("\(count) \(label) imported")
                .font(.body)

            Spacer()
        }
    }
}

#Preview {
    ImportSuccessView(
        importResult: DataManager.ImportResult(
            itemCount: 42,
            locationCount: 5,
            labelCount: 8
        )
    )
    .environmentObject(Router())
}
