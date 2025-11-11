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
    
    @State private var viewModel: ViewModel
    
    private enum Constants {
        static let iconSize: CGFloat = 60
        static let backgroundOpacity: CGFloat = 0.5
        static let maxContentWidth: CGFloat = 600
        static let contentHorizontalPadding: CGFloat = 32
        static let progressViewScale: CGFloat = 0.8
        static let filePermissions: UInt16 = 0o644
        static let shareSheetDelay: TimeInterval = 0.1
    }
    
    init(
        isComplete: Binding<Bool>,
        exportCompleted: Bool,
        progress: Double,
        phase: String,
        error: Error?,
        archiveURL: URL?,
        onCancel: @escaping () -> Void,
        onShare: @escaping () -> Void
    ) {
        self._isComplete = isComplete
        self.exportCompleted = exportCompleted
        self.progress = progress
        self.phase = phase
        self.error = error
        self.archiveURL = archiveURL
        self.onCancel = onCancel
        self.onShare = onShare
        
        self._viewModel = State(wrappedValue: ViewModel())
    }
    
    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }
    
    private var contentMaxWidth: CGFloat {
        min(UIScreen.main.bounds.width - Constants.contentHorizontalPadding, Constants.maxContentWidth)
    }
    
    private var backgroundLayer: some View {
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
                    .opacity(Constants.backgroundOpacity)
            }
        }
    }
    
    private var shareSheetContent: some View {
        Group {
            if let shareableURL = viewModel.shareableURL {
                ShareSheet(activityItems: [shareableURL])
                    .onAppear {
                        viewModel.handleShareSheetAppear(url: shareableURL)
                    }
                    .onDisappear {
                        viewModel.handleShareSheetDismissal(
                            shareableURL: shareableURL,
                            archiveURL: archiveURL,
                            isComplete: $isComplete
                        )
                    }
            } else {
                Text("No file available")
                    .onAppear {
                        viewModel.handleMissingShareURL()
                    }
            }
        }
    }
    
    private var progressPercentage: String {
        "\(Int(progress * 100))%"
    }
    
    private var displayPhase: String {
        phase.isEmpty ? "Preparing export..." : phase
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundLayer
                
                VStack(spacing: 24) {
                    Group {
                        if let error = error {
                            errorStateView(error: error)
                        } else if !viewModel.showFinishButton {
                            loadingStateView
                        } else {
                            successStateView
                        }
                    }
                    .transition(.opacity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.showFinishButton && error == nil {
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
                    viewModel.showFinishButton = true
                }
            }
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            shareSheetContent
        }
        .onChange(of: viewModel.showShareSheet) { oldValue, newValue in
            print("🔄 showShareSheet changed: \(oldValue) -> \(newValue)")
            print("   shareableURL is: \(viewModel.shareableURL?.path ?? "nil")")
        }
    }
    
    private func errorStateView(error: Error) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: Constants.iconSize))
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
        .frame(maxWidth: contentMaxWidth)
    }
    
    private var loadingStateView: some View {
        VStack {
            Spacer()
            
            ProgressView()
                .controlSize(.extraLarge)
            
            Text(displayPhase)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .transition(.opacity)
            
            Spacer()
            
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(.green)
                
                Text(progressPercentage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }
    
    private var successStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: Constants.iconSize))
                .foregroundColor(.green)
            
            Text("Export Complete!")
                .font(.title2.bold())
            
            Text("Your data has been exported successfully.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            VStack(spacing: 12) {
                shareButton
                doneButton
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: contentMaxWidth)
    }
    
    private var shareButton: some View {
        Button {
            prepareForSharing()
        } label: {
            HStack {
                if viewModel.isPreparingShare {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(Constants.progressViewScale)
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
        .disabled(viewModel.isPreparingShare)
    }
    
    private var doneButton: some View {
        Button {
            isComplete = false
        } label: {
            Text("Done")
                .frame(maxWidth: .infinity)
                .padding()
        }
        .tint(Color.secondary.opacity(0.2))
        .backport.glassProminentButtonStyle()
        .disabled(viewModel.isPreparingShare)
    }
    
    private func prepareForSharing() {
        viewModel.prepareForSharing(archiveURL: archiveURL)
    }
}

extension ExportLoadingView {
    @MainActor
    @Observable
    final class ViewModel {
        var showFinishButton = false
        var showShareSheet = false
        var shareableURL: URL?
        var isPreparingShare = false
        
        func handleShareSheetAppear(url: URL) {
            print("🎭 Sheet content appeared with URL: \(url.path)")
            isPreparingShare = false
        }
        
        func handleMissingShareURL() {
            print("❌ Sheet appeared but shareableURL is nil!")
            isPreparingShare = false
        }
        
        func handleShareSheetDismissal(
            shareableURL: URL,
            archiveURL: URL?,
            isComplete: Binding<Bool>
        ) {
            print("🎭 Sheet dismissed, cleaning up files and closing export view")
            try? FileManager.default.removeItem(at: shareableURL)
            if let archiveURL {
                try? FileManager.default.removeItem(at: archiveURL)
            }
            isComplete.wrappedValue = false
        }
        
        func prepareForSharing(archiveURL: URL?) {
            guard let archiveURL else {
                print("❌ No archive URL available")
                return
            }

            isPreparingShare = true
            print("📦 Preparing to share: \(archiveURL.path)")
            print("   File exists: \(FileManager.default.fileExists(atPath: archiveURL.path))")

            do {
                guard FileManager.default.fileExists(atPath: archiveURL.path) else {
                    print("❌ Source file does not exist at: \(archiveURL.path)")
                    isPreparingShare = false
                    return
                }

                let documentsURL = try FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )

                let destinationURL = documentsURL.appendingPathComponent(archiveURL.lastPathComponent)
                print("📁 Destination: \(destinationURL.path)")

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                    print("   Removed existing file")
                }

                try FileManager.default.copyItem(at: archiveURL, to: destinationURL)
                print("✅ File copied successfully")

                guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                    print("❌ Destination file does not exist after copy")
                    isPreparingShare = false
                    return
                }

                try FileManager.default.setAttributes([
                    .posixPermissions: ExportLoadingView.Constants.filePermissions
                ], ofItemAtPath: destinationURL.path)
                print("✅ Permissions set")

                shareableURL = destinationURL

                DispatchQueue.main.asyncAfter(deadline: .now() + ExportLoadingView.Constants.shareSheetDelay) {
                    self.showShareSheet = true
                    print("✅ Share sheet presenting with: \(destinationURL.path)")
                }
            } catch {
                print("❌ Failed to prepare file for sharing: \(error)")
                print("   Error details: \(error.localizedDescription)")
                isPreparingShare = false
            }
        }
    }
}
