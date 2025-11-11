import SwiftUIBackports
import SwiftUI

struct ExportLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isComplete: Bool
    let exportCompleted: Bool
    let progress: Double
    let phase: String
    let error: Error?
    let archiveURL: URL?
    let onCancel: () -> Void
    let onShare: () -> Void
    
    @State private var showFinishButton = false
    @State private var showShareSheet = false
    @State private var shareableURL: URL?
    @State private var isPreparingShare = false
    
    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }
    
    var body: some View {
        NavigationStack {
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
                
                VStack(spacing: 24) {
                    Group {
                        if let error = error {
                            // Error state
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.red)
                                
                                Text("Export Failed")
                                    .font(.title2.bold())
                                
                                Text(error.localizedDescription)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                                
                                Spacer()
                                
                                Button("Close") {
                                    isComplete = false
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                            
                        } else if !showFinishButton {
                            // Loading state
                            VStack {
                                Spacer()
                                
                                ProgressView()
                                    .controlSize(.extraLarge)
                                
                                Text(phase.isEmpty ? "Preparing export..." : phase)
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.primary)
                                    .transition(.opacity)
                                
                                Spacer()
                                
                                // Progress bar
                                VStack(spacing: 8) {
                                    ProgressView(value: progress)
                                        .progressViewStyle(.linear)
                                        .tint(.green)
                                    
                                    Text("\(Int(progress * 100))%")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 40)
                                .padding(.bottom, 40)
                            }
                            
                        } else {
                            // Success state
                            VStack(spacing: 16) {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.green)
                                
                                Text("Export Complete!")
                                    .font(.title2.bold())
                                
                                Text("Your data has been exported successfully.")
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Spacer()
                                
                                VStack(spacing: 12) {
                                    Button {
                                        prepareForSharing()
                                    } label: {
                                        HStack {
                                            if isPreparingShare {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .scaleEffect(0.8)
                                                Text("Preparing...")
                                            } else {
                                                Image(systemName: "square.and.arrow.up")
                                                Text("Share Export")
                                            }
                                        }
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                    }
                                    .backport.glassProminentButtonStyle()
                                    .disabled(isPreparingShare)

                                    Button {
                                        isComplete = false
                                    } label: {
                                        Text("Done")
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                    }
                                    .tint(Color.secondary.opacity(0.2))
                                    .backport.glassProminentButtonStyle()
                                    .disabled(isPreparingShare)
                                }
                            }
                            .padding(.horizontal)
                            .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        }
                    }
                    .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !showFinishButton && error == nil {
                        Button("Cancel", role: .cancel) {
                            onCancel()
                        }
                    }
                }
            }
        }
        .onChange(of: exportCompleted) { _, completed in
            if completed {
                withAnimation {
                    showFinishButton = true
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            Group {
                if let shareableURL {
                    ShareSheet(activityItems: [shareableURL])
                        .onAppear {
                            print("🎭 Sheet content appeared with URL: \(shareableURL.path)")
                            isPreparingShare = false
                        }
                        .onDisappear {
                            print("🎭 Sheet dismissed, cleaning up files and closing export view")
                            // Clean up both the shareable copy and original temp file
                            try? FileManager.default.removeItem(at: shareableURL)
                            if let archiveURL {
                                try? FileManager.default.removeItem(at: archiveURL)
                            }
                            // Close the export loading view after sharing completes
                            isComplete = false
                        }
                } else {
                    Text("No file available")
                        .onAppear {
                            print("❌ Sheet appeared but shareableURL is nil!")
                            isPreparingShare = false
                        }
                }
            }
        }
        .onChange(of: showShareSheet) { oldValue, newValue in
            print("🔄 showShareSheet changed: \(oldValue) -> \(newValue)")
            print("   shareableURL is: \(shareableURL?.path ?? "nil")")
        }
    }

    /// Copies the ZIP file to Documents directory for reliable share sheet access
    private func prepareForSharing() {
        guard let archiveURL else {
            print("❌ No archive URL available")
            return
        }

        isPreparingShare = true
        print("📦 Preparing to share: \(archiveURL.path)")
        print("   File exists: \(FileManager.default.fileExists(atPath: archiveURL.path))")

        do {
            // Verify source file exists
            guard FileManager.default.fileExists(atPath: archiveURL.path) else {
                print("❌ Source file does not exist at: \(archiveURL.path)")
                return
            }

            // Get Documents directory
            let documentsURL = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )

            // Create destination URL with same filename
            let destinationURL = documentsURL.appendingPathComponent(archiveURL.lastPathComponent)
            print("📁 Destination: \(destinationURL.path)")

            // Remove existing file if present
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
                print("   Removed existing file")
            }

            // Copy file to Documents (synchronously to ensure it's ready before sheet presents)
            try FileManager.default.copyItem(at: archiveURL, to: destinationURL)
            print("✅ File copied successfully")

            // Verify destination file exists
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                print("❌ Destination file does not exist after copy")
                return
            }

            // Set proper permissions
            try FileManager.default.setAttributes([
                .posixPermissions: 0o644
            ], ofItemAtPath: destinationURL.path)
            print("✅ Permissions set")

            // Update state - file is now ready
            shareableURL = destinationURL

            // Small delay to ensure SwiftUI processes the state update
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showShareSheet = true
                print("✅ Share sheet presenting with: \(destinationURL.path)")
            }
        } catch {
            print("❌ Failed to prepare file for sharing: \(error)")
            print("   Error details: \(error.localizedDescription)")
            isPreparingShare = false
        }
    }
}
