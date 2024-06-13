//
//  ImagePicker.swift
//  MovingBox
//
//  Created by Camden Webster on 6/11/24.
//

import SwiftUI
import PhotosUI


@Observable
class ImagePicker {
    
    var image: Image?
    var images: [Image] = []
  
  // Change the UpdateEditFormViewModel to match the name of your own ViewModel
    var vm: ImageUpdateEditViewModel?
    
    func setup(_ vm: ImageUpdateEditViewModel) {
        self.vm = vm
    }
    var imageSelection: PhotosPickerItem? {
        didSet {
            if let imageSelection {
                Task {
                    try await loadTransferable(from: imageSelection)
                }
            }
        }
    }
    
    @MainActor
    func loadTransferable(from imageSelection: PhotosPickerItem?) async throws {
        do {
            if let data = try await imageSelection?.loadTransferable(type: Data.self) {
                vm?.data = data
                if let uiImage = UIImage(data: data) {
                    self.image = Image(uiImage: uiImage)
                }
            }
        } catch {
            print(error.localizedDescription)
            image = nil
        }
    }
}
