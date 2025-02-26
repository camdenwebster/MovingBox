 import SwiftUI

struct PhotoReviewView: View {
    let image: UIImage
    let onAccept: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                HStack(spacing: 40) {
                    Button(action: { dismiss() }) {
                        VStack {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.title)
                            Text("Retake")
                        }
                        .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        onAccept(image)
                        dismiss()
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
            }
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: { dismiss() })
                }
            }
        }
    }
}
