//
//  MultiItemCardPrototype.swift
//  MovingBox
//
//  Created by Claude on 9/19/25.
//

import SwiftUI

struct MultiItemCardPrototype: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detectedItems: [MockInventoryItem] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var currentPhase: CapturePhase = .camera
    @State private var captureProgress: Double = 0
    @State private var selectedCardId: UUID?
    @State private var showSaveAnimation = false
    
    private enum CapturePhase {
        case camera, analyzing, selecting, saving
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                switch currentPhase {
                case .camera:
                    cameraPhaseView
                case .analyzing:
                    analyzingPhaseView
                case .selecting:
                    selectingPhaseView
                case .saving:
                    savingPhaseView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            generateMockItems()
        }
    }
    
    private var cameraPhaseView: some View {
        VStack(spacing: 0) {
            // Mock camera viewfinder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .aspectRatio(4/3, contentMode: .fit)
                    .padding()
                
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("Multi-Item Mode")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    Text("Point camera at multiple items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Camera controls
            HStack(spacing: 40) {
                Button(action: {}) {
                    Image(systemName: "photo.stack")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Button(action: capturePhoto) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 6)
                            .frame(width: 80, height: 80)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                    }
                }
                
                Button(action: {}) {
                    Image(systemName: "camera.rotate")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.black)
    }
    
    private var analyzingPhaseView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color(.systemGray4), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: captureProgress)
                    .stroke(Color.blue, lineWidth: 8)
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: captureProgress)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                Text("AI Analyzing Photo")
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("Identifying individual items...")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("\(Int(captureProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            startAnalysis()
        }
    }
    
    private var selectingPhaseView: some View {
        VStack(spacing: 0) {
            // Header with selection count
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Items Found")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(selectedItems.count) of \(detectedItems.count) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(selectedItems.count == detectedItems.count ? "Deselect All" : "Select All") {
                    withAnimation(.spring()) {
                        if selectedItems.count == detectedItems.count {
                            selectedItems.removeAll()
                        } else {
                            selectedItems = Set(detectedItems.map { $0.id })
                        }
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            // Cards in scroll view
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(detectedItems) { item in
                        itemCard(for: item)
                    }
                }
                .padding()
            }
            
            // Bottom save button
            if !selectedItems.isEmpty {
                Button(action: saveSelectedItems) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add \(selectedItems.count) Items")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: selectedItems.isEmpty)
    }
    
    private func itemCard(for item: MockInventoryItem) -> some View {
        let isSelected = selectedItems.contains(item.id)
        
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedItems.remove(item.id)
                } else {
                    selectedItems.insert(item.id)
                }
                selectedCardId = item.id
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedCardId = nil
            }
        }) {
            HStack(spacing: 16) {
                // Image placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: item.icon)
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
                
                // Item details
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 12) {
                        Label(item.category, systemImage: "tag")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label(item.estimatedPrice, systemImage: "dollarsign.circle")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !item.make.isEmpty {
                        Text("Make: \(item.make)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Selection indicator with animation
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                            .scaleEffect(selectedCardId == item.id ? 1.3 : 1.0)
                            .animation(.spring(response: 0.2), value: selectedCardId == item.id)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(selectedCardId == item.id ? 0.98 : 1.0)
            .animation(.spring(response: 0.2), value: selectedCardId == item.id)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var savingPhaseView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                    .scaleEffect(showSaveAnimation ? 1.2 : 1.0)
                    .opacity(showSaveAnimation ? 0.5 : 1.0)
                    .animation(.easeOut(duration: 1.0).repeatCount(2), value: showSaveAnimation)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(showSaveAnimation ? 1.1 : 1.0)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showSaveAnimation)
            }
            
            VStack(spacing: 12) {
                Text("Items Added!")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(selectedItems.count) items added to your inventory")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
            .padding()
        }
        .onAppear {
            showSaveAnimation = true
        }
    }
    
    private func capturePhoto() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPhase = .analyzing
        }
    }
    
    private func startAnalysis() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if captureProgress < 1.0 {
                captureProgress += 0.05
            } else {
                timer.invalidate()
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentPhase = .selecting
                    selectedItems = Set(detectedItems.prefix(3).map { $0.id })
                }
            }
        }
    }
    
    private func saveSelectedItems() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentPhase = .saving
        }
    }
    
    private func generateMockItems() {
        detectedItems = [
            MockInventoryItem(title: "Laptop Computer", category: "Electronics", estimatedPrice: "$1,200", make: "Apple", icon: "laptopcomputer"),
            MockInventoryItem(title: "Coffee Mug", category: "Household", estimatedPrice: "$15", make: "Starbucks", icon: "cup.and.saucer"),
            MockInventoryItem(title: "Desk Lamp", category: "Furniture", estimatedPrice: "$45", make: "IKEA", icon: "lamp.desk"),
            MockInventoryItem(title: "Notebook", category: "Office", estimatedPrice: "$8", make: "Moleskine", icon: "book"),
            MockInventoryItem(title: "Smartphone", category: "Electronics", estimatedPrice: "$800", make: "Samsung", icon: "phone"),
            MockInventoryItem(title: "Water Bottle", category: "Household", estimatedPrice: "$25", make: "Hydro Flask", icon: "waterbottle")
        ]
    }
}

struct MockInventoryItem: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let estimatedPrice: String
    let make: String
    let icon: String
}

#Preview {
    MultiItemCardPrototype()
}