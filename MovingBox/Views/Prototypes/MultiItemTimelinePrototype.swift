//
//  MultiItemTimelinePrototype.swift
//  MovingBox
//
//  Created by Claude on 9/19/25.
//

import SwiftUI

struct MultiItemTimelinePrototype: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detectedItems: [MockInventoryItem] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var currentPhase: TimelinePhase = .camera
    @State private var revealedItems: Set<UUID> = []
    @State private var currentStoryIndex = 0
    @State private var showItemDetails = false
    @State private var selectedItemForDetail: MockInventoryItem?
    @State private var timelineProgress: Double = 0
    
    private enum TimelinePhase {
        case camera, storytelling, reviewing, completed
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dynamic background that changes with phase
                backgroundGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.0), value: currentPhase)
                
                switch currentPhase {
                case .camera:
                    timelineCameraPhaseView
                case .storytelling:
                    storytellingPhaseView
                case .reviewing:
                    reviewingPhaseView
                case .completed:
                    completedPhaseView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                if currentPhase == .storytelling || currentPhase == .reviewing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("Step \(currentStoryIndex + 1)/\(detectedItems.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .onAppear {
            generateMockItems()
        }
        .sheet(isPresented: Binding(
            get: { selectedItemForDetail != nil },
            set: { if !$0 { selectedItemForDetail = nil } }
        )) {
            if let item = selectedItemForDetail {
                itemDetailSheet(for: item)
            }
        }
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: backgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var backgroundColors: [Color] {
        switch currentPhase {
        case .camera:
            return [.black, .gray.opacity(0.8)]
        case .storytelling:
            return [.purple.opacity(0.8), .blue.opacity(0.8)]
        case .reviewing:
            return [.blue.opacity(0.8), .teal.opacity(0.8)]
        case .completed:
            return [.green.opacity(0.8), .mint.opacity(0.8)]
        }
    }
    
    private var timelineCameraPhaseView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Story-style camera interface
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 180, height: 180)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "timeline.selection")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        
                        Text("Story Mode")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                
                VStack(spacing: 8) {
                    Text("Capture Your Collection")
                        .font(.headline)
                        .foregroundColor(.white)
                        .opacity(0.9)
                    
                    Text("AI will tell the story of each item")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .opacity(0.7)
                        .multilineTextAlignment(.center)
                }
            }
            
            Spacer()
            
            // Story-style capture button
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private var storytellingPhaseView: some View {
        VStack(spacing: 0) {
            // Progress bar at top
            VStack(spacing: 8) {
                HStack {
                    ForEach(0..<detectedItems.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index <= currentStoryIndex ? Color.white : Color.white.opacity(0.3))
                            .frame(height: 3)
                            .animation(.easeInOut(duration: 0.3), value: currentStoryIndex)
                    }
                }
                .padding(.horizontal)
                
                Text("Discovering your items...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top, 8)
            
            Spacer()
            
            // Story card for current item
            if currentStoryIndex < detectedItems.count {
                let currentItem = detectedItems[currentStoryIndex]
                
                VStack(spacing: 24) {
                    // Item visualization
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                            .frame(width: 200, height: 200)
                        
                        VStack(spacing: 16) {
                            Image(systemName: currentItem.icon)
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                                .scaleEffect(revealedItems.contains(currentItem.id) ? 1.0 : 0.5)
                                .opacity(revealedItems.contains(currentItem.id) ? 1.0 : 0.0)
                                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: revealedItems.contains(currentItem.id))
                        }
                        
                        // Magical sparkle effect
                        if revealedItems.contains(currentItem.id) {
                            ForEach(0..<6) { i in
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                                    .offset(
                                        x: cos(Double(i) * .pi / 3) * 80,
                                        y: sin(Double(i) * .pi / 3) * 80
                                    )
                                    .opacity(0.8)
                                    .animation(.easeOut(duration: 1.0).delay(0.3), value: revealedItems.contains(currentItem.id))
                            }
                        }
                    }
                    
                    // Story text
                    if revealedItems.contains(currentItem.id) {
                        VStack(spacing: 12) {
                            Text(currentItem.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 6) {
                                Text("Category: \(currentItem.category)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                Text("Estimated Value: \(currentItem.estimatedPrice)")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                if !currentItem.make.isEmpty {
                                    Text("Brand: \(currentItem.make)")
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.5).delay(0.5), value: revealedItems.contains(currentItem.id))
                    }
                }
                .onAppear {
                    revealItem(currentItem)
                }
            }
            
            Spacer()
            
            // Navigation controls
            HStack(spacing: 40) {
                if currentStoryIndex > 0 {
                    Button("Previous") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStoryIndex -= 1
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                } else {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 80)
                }
                
                // Selection toggle
                if currentStoryIndex < detectedItems.count {
                    let currentItem = detectedItems[currentStoryIndex]
                    let isSelected = selectedItems.contains(currentItem.id)
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            if isSelected {
                                selectedItems.remove(currentItem.id)
                            } else {
                                selectedItems.insert(currentItem.id)
                            }
                        }
                    }) {
                        HStack {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                            Text(isSelected ? "Added" : "Add Item")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.green : Color.white.opacity(0.2))
                        )
                    }
                }
                
                if currentStoryIndex < detectedItems.count - 1 {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentStoryIndex += 1
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                } else {
                    Button("Review") {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            currentPhase = .reviewing
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .stroke(Color.white, lineWidth: 2)
                    )
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private var reviewingPhaseView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Your Story Collection")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("\(selectedItems.count) items selected for your inventory")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.top)
            
            // Timeline view of selected items
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(detectedItems.filter { selectedItems.contains($0.id) }) { item in
                        timelineItemCard(for: item)
                    }
                }
                .padding()
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Edit Selection") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentPhase = .storytelling
                        currentStoryIndex = 0
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .stroke(Color.white, lineWidth: 2)
                )
                
                Button("Save Collection") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        currentPhase = .completed
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                )
            }
            .padding(.bottom)
        }
    }
    
    private func timelineItemCard(for item: MockInventoryItem) -> some View {
        HStack(spacing: 16) {
            // Timeline connector
            VStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 2, height: 40)
            }
            
            // Item card
            Button(action: {
                selectedItemForDetail = item
            }) {
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text(item.estimatedPrice)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation(.spring()) {
                            let _ = selectedItems.remove(item.id)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
    }
    
    private var completedPhaseView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 3)
                    .frame(width: 150, height: 150)
                
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .scaleEffect(1.2)
                    .animation(.spring(response: 0.6), value: currentPhase)
            }
            
            VStack(spacing: 16) {
                Text("Story Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your collection of \(selectedItems.count) items has been added to your inventory")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            Button("Continue Your Story") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
            )
            .padding()
        }
    }
    
    private func itemDetailSheet(for item: MockInventoryItem) -> some View {
        NavigationView {
            VStack(spacing: 24) {
                // Large item icon
                Image(systemName: item.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                // Item details
                VStack(spacing: 16) {
                    Text(item.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    VStack(spacing: 8) {
                        DetailRow(label: "Category", value: item.category)
                        DetailRow(label: "Estimated Value", value: item.estimatedPrice)
                        if !item.make.isEmpty {
                            DetailRow(label: "Brand", value: item.make)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Item Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        selectedItemForDetail = nil
                    }
                }
            }
        }
    }
    
    private func capturePhoto() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPhase = .storytelling
            selectedItems = Set(detectedItems.prefix(3).map { $0.id })
        }
    }
    
    private func revealItem(_ item: MockInventoryItem) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring()) {
                let _ = revealedItems.insert(item.id)
            }
        }
    }
    
    private func generateMockItems() {
        detectedItems = [
            MockInventoryItem(title: "Vintage Camera", category: "Electronics", estimatedPrice: "$250", make: "Canon", icon: "camera"),
            MockInventoryItem(title: "Leather Journal", category: "Office", estimatedPrice: "$45", make: "Moleskine", icon: "book"),
            MockInventoryItem(title: "Brass Compass", category: "Collectibles", estimatedPrice: "$75", make: "", icon: "safari"),
            MockInventoryItem(title: "Wooden Clock", category: "Furniture", estimatedPrice: "$120", make: "", icon: "clock"),
            MockInventoryItem(title: "Art Print", category: "Decor", estimatedPrice: "$85", make: "", icon: "photo.artframe")
        ]
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
}

extension MockInventoryItem {
    static var preview: MockInventoryItem {
        MockInventoryItem(
            title: "Sample Item",
            category: "Test",
            estimatedPrice: "$100",
            make: "Test Brand",
            icon: "star"
        )
    }
}

#Preview {
    MultiItemTimelinePrototype()
}
