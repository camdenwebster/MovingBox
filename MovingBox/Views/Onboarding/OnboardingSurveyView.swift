import SwiftUI

@MainActor
struct OnboardingSurveyView: View {
    @EnvironmentObject private var manager: OnboardingManager

    @State private var selectedUsages: Set<UsageType> = []

    var isContinueDisabled: Bool {
        selectedUsages.isEmpty
    }
    
    private var maxFrameWidth: CGFloat {
        min(UIScreen.main.bounds.width - 32, 600)
    }

    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                        VStack(spacing: 16) {
                            VStack(spacing: 0){
                                OnboardingHeaderText(text: "What brings you to MovingBox?")

                                OnboardingDescriptionText(text: "Select all that apply")
                                    .frame(maxWidth: maxFrameWidth)
                            }

                            // Usage Options
                            VStack(spacing: 12) {
                                ForEach(UsageType.allCases, id: \.self) { usage in
                                    UsageSurveyOptionButton(
                                        usage: usage,
                                        isSelected: selectedUsages.contains(usage),
                                        action: {
                                            toggleSelection(for: usage)
                                        }
                                    )
                                    .tint(.primary)
                                }
                            }
                            .frame(maxWidth: maxFrameWidth)

                            Spacer()
                                .frame(height: 100)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                VStack {
                    OnboardingContinueButton {
                        handleContinue()
                    }
                    .accessibilityIdentifier("onboarding-survey-continue-button")
                    .disabled(isContinueDisabled)
                    .frame(maxWidth: maxFrameWidth)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func toggleSelection(for usage: UsageType) {
        if selectedUsages.contains(usage) {
            selectedUsages.remove(usage)
        } else {
            selectedUsages.insert(usage)
        }
    }

    private func handleContinue() {
        let selectedCount = selectedUsages.count
        let selectedUsagesString = selectedUsages
            .sorted { $0.rawValue < $1.rawValue }
            .map { $0.rawValue }
            .joined(separator: ",")

        // Track telemetry event with error handling
        do {
            TelemetryManager.shared.trackUsageSurveySelected(
                usages: selectedUsagesString,
                count: selectedCount
            )
        } catch {
            // Log error but don't block user flow for telemetry failures
            print("⚠️ Failed to track usage survey telemetry: \(error)")
        }

        // Mark survey as completed
        UserDefaults.standard.set(true, forKey: OnboardingManager.hasCompletedUsageSurveyKey)

        manager.moveToNext()
    }
}

// MARK: - Survey Option Button

struct UsageSurveyOptionButton: View {
    let usage: UsageType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .green : .secondary)

                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(usage.title)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .green : .secondary)

                    Text(usage.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                        .fill(isSelected ? Color.green.opacity(0.1) : Color(.systemBackground))

                    if !isSelected {
                        RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                            .fill(.ultraThinMaterial)
                    }

                    RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                        .stroke(isSelected ? Color.green : Color(.separator), lineWidth: 1)
                }
            }
        }
        .accessibilityIdentifier("onboarding-survey-option-\(usage.rawValue)")
    }
}

#Preview {
    OnboardingSurveyView()
        .environmentObject(OnboardingManager())
}
