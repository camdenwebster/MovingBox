//
//  LocationItemCard.swift
//  MovingBox
//
//  Created by Camden Webster on 6/6/24.
//

import SwiftUI

struct LocationItemCard: View {
    var location: InventoryLocation
    var showCost: Bool = false
    @State private var thumbnail: UIImage?
    @State private var loadingError: Error?
    @State private var isDownloading = false

    private var totalReplacementCost: Decimal {
        location.inventoryItems?.reduce(0, { $0 + $1.price }) ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Photo section
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 100)
                        .clipped()
                } else if let sfSymbol = location.sfSymbolName {
                    // Show SF Symbol for default rooms
                    Rectangle()
                        .fill(
                            Color(.secondarySystemGroupedBackground)
                        )
                        .frame(width: 160, height: 100)
                        .overlay(
                            Image(systemName: sfSymbol)
                                .font(.system(size: 44, weight: .light))
                                .foregroundStyle(.secondary)
                        )
                } else {
                    // Fallback to generic photo placeholder
                    Rectangle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 160, height: 100)
                        .overlay(
                            Group {
                                if isDownloading {
                                    ProgressView()
                                        .tint(.secondary)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 40))
                                        .tint(.secondary)
                                }
                            }
                        )
                }
            }
            .task(id: location.imageURL) {
                loadingError = nil
                updateDownloadState()
                do {
                    thumbnail = try await location.thumbnail
                    isDownloading = false
                } catch {
                    loadingError = error
                    thumbnail = nil
                    isDownloading = false
                }
            }

            // Location details
            VStack(alignment: .leading) {
                Text(location.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.label))
                HStack {
                    Text("Items")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text("\(location.inventoryItems?.count ?? 0)")
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
                HStack {
                    Text("Value")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                    Spacer()
                    Text(CurrencyFormatter.format(totalReplacementCost))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.label))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: UIConstants.cornerRadius))
        .background(
            RoundedRectangle(cornerRadius: UIConstants.cornerRadius)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .padding(1)
    }

    private func updateDownloadState() {
        guard let imageURL = location.imageURL else {
            isDownloading = false
            return
        }

        let id = imageURL.deletingPathExtension().lastPathComponent
        let thumbnailURL = OptimizedImageManager.shared.getThumbnailURL(for: id)
        isDownloading =
            OptimizedImageManager.shared.isUbiquitousItemDownloading(thumbnailURL)
            || OptimizedImageManager.shared.isUbiquitousItemDownloading(imageURL)
    }
}

#Preview {
    do {
        let previewer = try Previewer()
        return LocationItemCard(location: previewer.location)
            .modelContainer(previewer.container)
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
}
