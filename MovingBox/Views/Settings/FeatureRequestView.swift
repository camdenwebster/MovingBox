import SwiftUI
import WishKit

struct FeatureRequestView: View {
    var body: some View {
        WishKit.FeedbackListView()
            .navigationTitle("Feature Requests")
            .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        FeatureRequestView()
    }
}
