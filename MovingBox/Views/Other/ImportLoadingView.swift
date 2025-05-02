import SwiftUI

struct ImportLoadingView: View {
    let importedItemCount: Int
    let importedLocationCount: Int
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isComplete: Bool
    let importCompleted: Bool
    let progress: Double
    let error: Error?
    
    @State private var currentMessage = 0
    @State private var showFinishButton = false
    
    private let messages = [
        "Reading your data...",
        "Processing items...",
        "Setting up locations...",
        "Almost there..."
    ]
    
    private var backgroundImage: String {
        colorScheme == .dark ? "background-dark" : "background-light"
    }
    
    var body: some View {
        let _ = Self._printChanges()
        
        ZStack {
            Image(backgroundImage)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Group {
                    if let error = error {
                        // Error state
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.red)
                            
                            Text("Import Failed")
                                .font(.title2.bold())
                            
                            Text(error.localizedDescription)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                            
                            Spacer()
                            
                            Button("Close") {
                                print("🔴 Error view close button tapped")
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
                        .onAppear { print("🔴 Error view appeared with: \(error.localizedDescription)") }
                        
                    } else if !showFinishButton {
                        // Loading state
                        VStack {
                            Spacer()
                            
                            ProgressView()
                                .controlSize(.extraLarge)
                            
                            Text(messages[currentMessage])
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.primary)
                                .transition(.move(edge: .top).combined(with: .opacity))
                                .id("message-\(currentMessage)")
                            
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
                        .onAppear { print("📊 Loading view appeared") }
                        
                    } else {
                        // Success state
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("Import Complete!")
                                .font(.title2.bold())
                            
                            VStack(spacing: 8) {
                                Text("\(importedItemCount) items imported")
                                Text("\(importedLocationCount) locations imported")
                            }
                            Spacer()
                            Button("Done") {
                                print("✅ Success view done button tapped")
                                isComplete = false
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: min(UIScreen.main.bounds.width - 32, 600))
                        .onAppear { print("✅ Success view appeared") }
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            print("👁️ ImportLoadingView appeared with - Error: \(String(describing: error)), Completed: \(importCompleted), Progress: \(progress)")
        }
        .onChange(of: importCompleted) { _, completed in
            print("🔄 Import completed changed to: \(completed)")
            if completed {
                withAnimation {
                    showFinishButton = true
                }
            }
        }
        .task {
            await animateMessages()
        }
    }
    
    @MainActor
    private func animateMessages() async {
        while !showFinishButton && error == nil {
            try? await Task.sleep(for: .seconds(2))
            guard !showFinishButton && error == nil else {
                print("🛑 Stopping message animation - ShowFinish: \(showFinishButton), Error: \(String(describing: error))")
                break
            }
            
            withAnimation {
                currentMessage = (currentMessage + 1) % messages.count
            }
        }
    }
}
