//
//  JoiningShareView.swift
//  MovingBox
//
//  Created by Camden Webster on 2/6/26.
//

import CloudKit
import Dependencies
import SQLiteData
import SwiftUI

struct JoiningShareView: View {
    let shareMetadata: CKShare.Metadata
    let onComplete: () -> Void

    @Dependency(\.defaultSyncEngine) private var syncEngine
    @State private var phase: Phase = .accepting
    @State private var errorMessage: String?

    private enum Phase {
        case accepting
        case success
        case error
    }

    var body: some View {
        OnboardingContainer {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 20) {
                        switch phase {
                        case .accepting:
                            acceptingContent
                        case .success:
                            successContent
                        case .error:
                            errorContent
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                }

                if phase == .success {
                    OnboardingContinueButton(action: finishJoining, title: "Get Started")
                        .accessibilityIdentifier("joining-share-continue-button")
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                }
            }
        }
        .onboardingBackground()
        .task {
            guard phase == .accepting else { return }
            await acceptShare()
        }
    }

    // MARK: - Phase Content

    private var acceptingContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "Joining Shared Inventory")

            OnboardingDescriptionText(
                text: "Setting up your access to the shared inventory..."
            )

            ProgressView()
                .controlSize(.large)
                .padding(.top, 8)
        }
    }

    private var successContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "You're All Set!")

            OnboardingDescriptionText(
                text: "You now have access to the shared inventory."
            )

            VStack(alignment: .leading, spacing: 12) {
                OnboardingFeatureRow(
                    icon: "eye.fill",
                    title: "View shared items",
                    description: "Browse everything in the shared inventory"
                )

                OnboardingFeatureRow(
                    icon: "plus.circle.fill",
                    title: "Add new items",
                    description: "Contribute items to the shared collection"
                )

                OnboardingFeatureRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Stay in sync",
                    description: "Changes sync automatically across devices"
                )
            }
            .padding(20)
            .background {
                RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                    .fill(.ultraThinMaterial)
            }
            .padding(.horizontal)
        }
    }

    private var errorContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)
                .padding(.bottom, 8)

            OnboardingHeaderText(text: "Something Went Wrong")

            if let errorMessage {
                OnboardingDescriptionText(text: errorMessage)
            }

            VStack(spacing: 12) {
                OnboardingContinueButton(
                    action: {
                        phase = .accepting
                        Task { await acceptShare() }
                    }, title: "Try Again"
                )
                .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))

                Button("Skip and Start Fresh") {
                    finishJoining()
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Actions

    private func acceptShare() async {
        do {
            try await syncEngine.acceptShare(metadata: shareMetadata)
            withAnimation {
                phase = .success
            }
        } catch {
            errorMessage = "Could not join the shared inventory. Check your network connection and try again."
            withAnimation {
                phase = .error
            }
        }
    }

    private func finishJoining() {
        OnboardingManager.markOnboardingCompleteStatic()
        onComplete()
    }
}
