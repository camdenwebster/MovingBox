import SwiftUI
import AcknowList

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private var copyrightYear: String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        return "\(currentYear)"
    }
    
    private let externalLinks: [String: ExternalLink] = [
        "privacyPolicy": ExternalLink(
            title: "Privacy Policy",
            icon: "lock",
            url: URL(string: "https://movingbox.ai/privacy")!
        ),
        "termsOfService": ExternalLink(
            title: "Terms of Use",
            icon: "doc.text",
            url: URL(string: "https://movingbox.ai/eula")!
        ),
        "roadmap": ExternalLink(
            title: "What's New",
            icon: "sparkles",
            url: URL(string: "https://movingbox.ai/roadmap")!
        )
    ]
    
    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    if let uiImage = UIImage(named: "AppIcon") {
                        Image(uiImage: uiImage)
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    
                    Text("About MovingBox")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("MovingBox is built by an independent developer dedicated to helping you organize and protect your home inventory, and we strive to offer the best experience on Apple Platforms.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Text("We take your privacy seriously. MovingBox is supported entirely by MovingBox Pro subscriptions, and we will never collect or sell your data.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Text("Copyright © \(copyrightYear) Mothersound, LLC")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 10)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            Section {
                Link(destination: externalLinks["privacyPolicy"]!.url) {
                    HStack {
                        Text("Privacy Policy")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Link(destination: externalLinks["termsOfService"]!.url) {
                    HStack {
                        Text("Terms of Use")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Link(destination: externalLinks["roadmap"]!.url) {
                    HStack {
                        Label {
                            Text("What's New")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "sparkles")
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                NavigationLink {
                    AcknowListSwiftUIView()
                        .navigationBarTitleDisplayMode(.inline)
                } label: {
                    Label {
                        Text("Credits")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "heart")
                    }
                }
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
