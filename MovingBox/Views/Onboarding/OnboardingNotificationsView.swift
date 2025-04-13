import SwiftUI
import UserNotifications

struct OnboardingNotificationsView: View {
    @EnvironmentObject var onboardingManager: OnboardingManager
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)
                .symbolEffect(.bounce, options: .repeating)
            
            Text("Stay on Top of Important Dates")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            VStack(alignment: .leading, spacing: 16) {
                NotificationFeatureRow(
                    icon: "clock.badge.exclamationmark",
                    title: "Warranty Expiration Alerts",
                    description: "Never miss a warranty deadline - we'll remind you before your coverage ends"
                )
                
                NotificationFeatureRow(
                    icon: "calendar.badge.clock",
                    title: "Maintenance Reminders",
                    description: "Get timely reminders for routine maintenance of your valuable items"
                )
                
                NotificationFeatureRow(
                    icon: "dollarsign.circle.fill",
                    title: "Insurance Updates",
                    description: "Stay informed about policy renewals and coverage changes"
                )
            }
            .padding(.horizontal)
            
            Spacer()
            
            NotificationStatusButton(status: onboardingManager.notificationStatus)
                .padding(.bottom, 8)
            
            NavigationControlButtons()
                .environmentObject(onboardingManager)
        }
        .padding()
    }
}

struct NotificationFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct NotificationStatusButton: View {
    let status: UNAuthorizationStatus
    @EnvironmentObject var onboardingManager: OnboardingManager
    
    var body: some View {
        VStack(spacing: 8) {
            switch status {
            case .notDetermined:
                Button(action: {
                    Task {
                        await onboardingManager.requestNotificationPermissions()
                    }
                }) {
                    Text("Enable Notifications")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                
            case .denied:
                VStack(spacing: 8) {
                    Text("Notifications are currently disabled")
                        .foregroundStyle(.secondary)
                    
                    Button(action: {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Open Settings")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                
            case .authorized, .provisional, .ephemeral:
                Text("Notifications enabled! 🎉")
                    .font(.headline)
                    .foregroundStyle(.green)
            @unknown default:
                EmptyView()
            }
            
            if status != .notDetermined {
                Button(action: {
                    onboardingManager.moveToNext()
                }) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    OnboardingNotificationsView()
        .environmentObject(OnboardingManager())
}