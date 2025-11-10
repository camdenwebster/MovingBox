import SwiftUI

struct ExportLoadingView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isComplete: Bool
    let exportCompleted: Bool
    let progress: Double
    let phase: String
    let error: Error?
    let onCancel: () -> Void
    
    @State private var showFinishButton = false
    
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
                                Button("Done") {
                                    isComplete = false
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.green)
                                .cornerRadius(10)
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
    }
}
