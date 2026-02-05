//
//  CloudSharingView.swift
//  MovingBox
//
//  Created by Camden Webster on 2/4/26.
//

import CloudKit
import SQLiteData
import SwiftUI
import UIKit

/// A SwiftUI wrapper for UICloudSharingController to present CloudKit sharing UI
struct CloudSharingView: UIViewControllerRepresentable {
    let shareRecord: SharedRecord
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: shareRecord.share, container: CKContainer.default())
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDismiss: onDismiss)
    }

    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        let onDismiss: () -> Void

        init(onDismiss: @escaping () -> Void) {
            self.onDismiss = onDismiss
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: any Error
        ) {
            print("Failed to save share: \(error.localizedDescription)")
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            "MovingBox Data"
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            print("Share saved successfully")
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            print("Sharing stopped")
            onDismiss()
        }
    }
}

/// A view that prepares a share before presenting the sharing controller
struct CloudSharingPrepareView: View {
    @Bindable var viewModel: FamilySharingViewModel
    @Binding var isPresented: Bool

    @State private var shareRecord: SharedRecord?
    @State private var isPreparing = true
    @State private var prepareError: String?

    var body: some View {
        Group {
            if isPreparing {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Preparing share...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = prepareError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Unable to Share")
                        .font(.headline)
                    Text(error)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Dismiss") {
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if let record = shareRecord {
                CloudSharingView(shareRecord: record) {
                    isPresented = false
                }
            }
        }
        .task {
            await prepareShare()
        }
    }

    private func prepareShare() async {
        isPreparing = true

        // Try to get existing share first
        if let existing = await viewModel.getShareRecord() {
            shareRecord = existing
            isPreparing = false
            return
        }

        // Create a new share
        if let newShare = await viewModel.createShare() {
            shareRecord = newShare
        } else {
            prepareError = viewModel.error ?? "Failed to create share"
        }

        isPreparing = false
    }
}
