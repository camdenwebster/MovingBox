import SwiftUI
import UserNotifications

struct OnboardingNotificationsView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    
    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(height: 20)
                        
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 60))
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(.secondary)
                            .symbolEffect(.wiggle, options: .nonRepeating)
                        
                        Text("Stay on Top of Important Dates")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                OnboardingFeatureRow(
                                    icon: "clock.badge.exclamationmark",
                                    title: "Warranty Expiration Alerts",
                                    description: "Never miss a warranty deadline - we'll remind you before your coverage ends"
                                )
                                
                                .symbolEffect(.bounce.down.byLayer, options: .nonRepeating)
                                
                                OnboardingFeatureRow(
                                    icon: "calendar.badge.clock",
                                    title: "Maintenance Reminders",
                                    description: "Get timely reminders for routine maintenance of your valuable items"
                                )
                                
                                OnboardingFeatureRow(
                                    icon: "dollarsign.circle.fill",
                                    title: "Insurance Updates",
                                    description: "Stay informed about policy renewals and coverage changes"
                                )
                            }
                            .padding(20)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    .padding()
                }
                
                // Bottom button section
                VStack(spacing: 16) {
                    switch onboardingManager.notificationStatus {
                    case .notDetermined:
                        OnboardingContinueButton(action: {
                            Task {
                                await onboardingManager.requestNotificationPermissions()
                            }
                        }, title: "Enable Notifications")
                        .accessibilityIdentifier("notificationsButton")
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        
                    case .denied:
                        Text("Notifications are currently disabled")
                            .foregroundStyle(.secondary)
                        
                        Button(action: {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text("Open Settings")
                                .font(.headline)
                                .foregroundColor(Color.customPrimary)
                        }
                        .padding(.vertical, 8)
                        
                        OnboardingContinueButton(action: {
                            onboardingManager.moveToNext()
                        })
                        .accessibilityIdentifier("notificationsButton")
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        
                    case .authorized, .provisional, .ephemeral:
                        Text("Notifications enabled! ")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding(.bottom)
                        
                        OnboardingContinueButton(action: {
                            onboardingManager.moveToNext()
                        })
                        .accessibilityIdentifier("notificationsButton")
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        
                    @unknown default:
                        EmptyView()
                    }

                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    OnboardingNotificationsView()
        .environmentObject(OnboardingManager())
}
