//
//  ImageUpdateEdit.swift
//  MovingBox
//
//  Created by Camden Webster on 6/11/24.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ImageUpdateEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State var vm: ImageUpdateEditViewModel
    @State private var imagePicker = ImagePicker()
    
    var body: some View {
        NavigationStack {
            Form {
                VStack {
                    if vm.data != nil {
                        Button("Clear image") {
                            vm.clearImge()
                        }
                        .buttonStyle(.bordered)
                    }
                    HStack {
                        Button("Camera", systemImage: "camera") {
                        }
                        PhotosPicker(selection: $imagePicker.imageSelection) {
                            Label("Photos", systemImage: "photo")
                        }
                    }
                    .foregroundStyle(.white)
                    .buttonStyle(.borderedProminent)
                    Image(uiImage: vm.image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding()
                }
            }
            .onAppear {
                imagePicker.setup(vm)
            }
//            .toolbar {
////                ToolbarItem(placement: .topBarLeading) {
////                    Button("Cancel") {
////                        dismiss()
////                    }
////                }
////                ToolbarItem(placement: .topBarTrailing) {
////                    Button {
////                        if vm.isUpdating {
////                            if let inventoryItem = vm.inventoryItem {
////                                if vm.image != Constants.placeholderImage {
////                                    inventoryItem.data = vm.image.jpegData(compressionQuality: 0.8)
////                                } else {
////                                    inventoryItem.data = nil
////                                }
////                                dismiss()
////                                
////                            }
////                        } else {
////                            let newInventoryItem = InventoryItem()
////                            if vm.image != Constants.placeholderImage {
////                                newInventoryItem.data = vm.image.jpegData(compressionQuality: 0.8)
////                            } else {
////                                newInventoryItem = nil
////                            }
////                            modelContext.insert(newInventoryItem)
////                            dismiss()
////                        }
////                    } label: {
////                        Text(vm.isUpdating ? "Update" : "Add")
////                    }
////                }
//            }
        }
    }
}

#Preview {
    ImageUpdateEditView(vm: ImageUpdateEditViewModel())
}
