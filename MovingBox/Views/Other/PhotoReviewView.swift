import SwiftUI

struct PhotoReviewView: View {
    let image: UIImage
    let onAccept: ((UIImage, Bool, @escaping () -> Void) -> Void)
    let onRetake: () -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settings = SettingsManager()
    @State private var isAnalyzing = false
    @State private var showingApiKeyAlert = false

    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                    .transition(.scale.combined(with: .opacity))
                
                if isAnalyzing {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analyzing image...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 100)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 40) {
                        Button(action: onRetake) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title)
                                Text("Retake")
                            }
                            .foregroundColor(.red)
                        }
                        
                        Button(action: {
                            if settings.apiKey.isEmpty {
                                showingApiKeyAlert = true
                            } else {
                                isAnalyzing = true
                                // Pass the image and analysis flag, but handle dismissal here
                                onAccept(image, !settings.apiKey.isEmpty) {
                                    // This closure will only be called after analysis is complete
                                    DispatchQueue.main.async {
                                        isAnalyzing = false
                                        print("Analysis complete, dismissing PhotoReviewView")
                                        dismiss()
                                    }
                                }
                            }
                        }) {
                            VStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.title)
                                Text("Use Photo")
                            }
                            .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isAnalyzing)
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: { dismiss() })
                        .disabled(isAnalyzing)
                }
            }
            .alert("OpenAI API Key Required", isPresented: $showingApiKeyAlert) {
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please configure your OpenAI API key in the settings to use image analysis.")
            }
            .interactiveDismissDisabled(isAnalyzing)
        }
    }
}
