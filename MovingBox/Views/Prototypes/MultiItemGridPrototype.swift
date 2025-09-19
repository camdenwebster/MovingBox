//
//  MultiItemGridPrototype.swift
//  MovingBox
//
//  Created by Claude on 9/19/25.
//

import SwiftUI

struct MultiItemGridPrototype: View {
    @Environment(\.dismiss) private var dismiss
    @State private var detectedItems: [MockInventoryItem] = []
    @State private var selectedItems: Set<UUID> = []
    @State private var currentPhase: GridCapturePhase = .camera
    @State private var animateGrid = false
    @State private var draggedItemId: UUID?
    @State private var pulsingItems: Set<UUID> = []
    @State private var showConfetti = false
    
    private enum GridCapturePhase {
        case camera, discovering, interactive, finalizing
    }
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                switch currentPhase {
                case .camera:
                    gridCameraPhaseView
                case .discovering:
                    discoveringPhaseView
                case .interactive:
                    interactiveGridView
                case .finalizing:
                    finalizingPhaseView
                }
                
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if currentPhase == .interactive {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Text("\(selectedItems.count)/\(detectedItems.count)")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.1))
                            )
                    }
                }
            }
        }
        .onAppear {
            generateMockItems()
        }
    }
    
    private var gridCameraPhaseView: some View {
        VStack(spacing: 0) {
            // Mock camera with grid overlay
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .aspectRatio(4/3, contentMode: .fit)
                    .padding()
                
                // Grid overlay
                VStack(spacing: 20) {
                    HStack(spacing: 20) {
                        ForEach(0..<6) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue.opacity(0.5))
                        }
                    }
                    
                    HStack(spacing: 20) {
                        ForEach(0..<6) { _ in
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue.opacity(0.5))
                        }
                    }
                }
                
                VStack(spacing: 16) {
                    Image(systemName: "grid")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    
                    Text("Grid Mode Active")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("AI will detect items in grid layout")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
            }
            
            Spacer()
            
            // Camera controls
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 6)
                        .frame(width: 80, height: 80)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 60, height: 60)
                    Image(systemName: "grid.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.black)
    }
    
    private var discoveringPhaseView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated grid discovery
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(detectedItems.enumerated()), id: \.element.id) { index, item in
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 100)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: item.icon)
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Found!")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        )
                        .scaleEffect(animateGrid ? 1.0 : 0.1)
                        .opacity(animateGrid ? 1.0 : 0.0)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.8)
                            .delay(Double(index) * 0.1),
                            value: animateGrid
                        )
                }
            }
            .padding()
            
            Text("Discovering items in your photo...")
                .font(.headline)
                .foregroundColor(.primary)
                .opacity(animateGrid ? 1.0 : 0.0)
                .animation(.easeIn(duration: 0.5).delay(1.0), value: animateGrid)
            
            Spacer()
        }
        .onAppear {
            startDiscovery()
        }
    }
    
    private var interactiveGridView: some View {
        VStack(spacing: 0) {
            // Instructions header
            VStack(spacing: 8) {
                Text("Tap items to select")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Long press and drag to reorder")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button("Select All") {
                        withAnimation(.spring()) {
                            selectedItems = Set(detectedItems.map { $0.id })
                            triggerPulseAnimation()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Button("Clear All") {
                        withAnimation(.spring()) {
                            selectedItems.removeAll()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(detectedItems) { item in
                        interactiveGridItem(for: item)
                    }
                }
                .padding()
            }
            
            // Action button
            if !selectedItems.isEmpty {
                Button(action: finalizeSelection) {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Add \(selectedItems.count) Items")
                        Image(systemName: "sparkles")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .scale))
            }
        }
        .animation(.spring(), value: selectedItems.isEmpty)
    }
    
    private func interactiveGridItem(for item: MockInventoryItem) -> some View {
        let isSelected = selectedItems.contains(item.id)
        let isPulsing = pulsingItems.contains(item.id)
        
        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .stroke(
                    isSelected ? Color.blue : Color.clear,
                    lineWidth: 2
                )
            
            VStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
                
                Text(item.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text(item.estimatedPrice)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            
            // Selection indicator
            VStack {
                HStack {
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                            .background(Color.white, in: Circle())
                    }
                }
                Spacer()
            }
            .padding(8)
        }
        .frame(height: 120)
        .scaleEffect(isPulsing ? 1.1 : (draggedItemId == item.id ? 1.05 : 1.0))
        .animation(.spring(response: 0.3), value: isPulsing)
        .animation(.spring(response: 0.2), value: draggedItemId == item.id)
        .onTapGesture {
            withAnimation(.spring()) {
                if isSelected {
                    selectedItems.remove(item.id)
                } else {
                    selectedItems.insert(item.id)
                }
            }
        }
        .onLongPressGesture {
            draggedItemId = item.id
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                draggedItemId = nil
            }
        }
    }
    
    private var finalizingPhaseView: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation with sparkles
            ZStack {
                ForEach(0..<8) { i in
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .offset(
                            x: cos(Double(i) * .pi / 4) * 50,
                            y: sin(Double(i) * .pi / 4) * 50
                        )
                        .opacity(showConfetti ? 0.0 : 1.0)
                        .scaleEffect(showConfetti ? 0.5 : 1.0)
                        .animation(
                            .easeOut(duration: 1.0).delay(Double(i) * 0.1),
                            value: showConfetti
                        )
                }
                
                Image(systemName: "grid.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .scaleEffect(showConfetti ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6), value: showConfetti)
            }
            
            VStack(spacing: 16) {
                Text("Grid Complete!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("\(selectedItems.count) items organized and ready")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Finish") {
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
            showConfetti = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = false
            }
        }
    }
    
    private func capturePhoto() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPhase = .discovering
        }
    }
    
    private func startDiscovery() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateGrid = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPhase = .interactive
                selectedItems = Set(detectedItems.prefix(4).map { $0.id })
            }
        }
    }
    
    private func triggerPulseAnimation() {
        pulsingItems = selectedItems
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pulsingItems.removeAll()
        }
    }
    
    private func finalizeSelection() {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPhase = .finalizing
        }
    }
    
    private func generateMockItems() {
        detectedItems = [
            MockInventoryItem(title: "Wireless Mouse", category: "Electronics", estimatedPrice: "$35", make: "Logitech", icon: "computermouse"),
            MockInventoryItem(title: "Picture Frame", category: "Decor", estimatedPrice: "$20", make: "", icon: "photo.on.rectangle"),
            MockInventoryItem(title: "Pen Set", category: "Office", estimatedPrice: "$12", make: "Pilot", icon: "pencil"),
            MockInventoryItem(title: "Desk Calendar", category: "Office", estimatedPrice: "$15", make: "", icon: "calendar"),
            MockInventoryItem(title: "Headphones", category: "Electronics", estimatedPrice: "$120", make: "Sony", icon: "headphones"),
            MockInventoryItem(title: "Plant Pot", category: "Decor", estimatedPrice: "$18", make: "", icon: "leaf")
        ]
    }
}

struct ConfettiView: View {
    @State private var confettiPieces: [ConfettiPiece] = []
    
    var body: some View {
        ZStack {
            ForEach(confettiPieces) { piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(piece.color)
                    .frame(width: 8, height: 8)
                    .position(x: piece.x, y: piece.y)
            }
        }
        .onAppear {
            generateConfetti()
        }
    }
    
    private func generateConfetti() {
        let colors: [Color] = [.blue, .green, .yellow, .orange, .red, .purple]
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for _ in 0..<50 {
            let piece = ConfettiPiece(
                id: UUID(),
                x: Double.random(in: 0...screenWidth),
                y: Double.random(in: -100...screenHeight/3),
                color: colors.randomElement() ?? .blue
            )
            confettiPieces.append(piece)
        }
        
        // Animate confetti falling
        withAnimation(.linear(duration: 3.0)) {
            for i in 0..<confettiPieces.count {
                confettiPieces[i].y += screenHeight + 100
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            confettiPieces.removeAll()
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id: UUID
    var x: Double
    var y: Double
    let color: Color
}

#Preview {
    MultiItemGridPrototype()
}