import AcknowList
import SwiftUI
import WhatsNewKit

struct AboutView: View {
    @State private var whatsNew: WhatsNew? = nil

    private var appVersion: String {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
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
        ),
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 20) {
                    if let appIcon = Bundle.main.icon {
                        Image(uiImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text("About MovingBox")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(appVersion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(
                        "MovingBox is built by an independent developer dedicated to offering the best home inventory experience on Apple Platforms."
                    )
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)

                    Text(
                        "We take your privacy seriously. MovingBox is supported entirely by MovingBox Pro subscriptions, and we will never collect or sell your data."
                    )
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
                Button {
                    whatsNew = .current
                } label: {
                    HStack {
                        Label {
                            Text("What's New")
                                .foregroundStyle(.primary)
                        } icon: {
                            Image(systemName: "sparkles")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                NavigationLink {
                    AcknowListSwiftUIView()
                        .movingBoxNavigationTitleDisplayModeInline()
                } label: {
                    Label {
                        Text("Third Party Acknowledgements")
                            .foregroundStyle(.primary)
                    } icon: {
                        Image(systemName: "heart")
                    }
                }
            }
        }
        .navigationTitle("About")
        .movingBoxNavigationTitleDisplayModeInline()
        .sheet(whatsNew: $whatsNew)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
