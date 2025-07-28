//
//  ReportInputView.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import SwiftUI
import PhotosUI
import CoreLocation

struct ReportInputView: View {
    let location: CLLocationCoordinate2D
    let onSubmit: (String, UIImage?) -> Void
    let onCancel: () -> Void
    
    @State private var reportText = ""
    @State private var selectedPhoto: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var characterCount = 0
    @StateObject private var preferencesManager = PreferencesManager.shared
    
    private let maxCharacters = 500
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Location Information
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text(preferencesManager.currentLanguage == "es" ? "Ubicación del Reporte" : "Report Location")
                            .font(.headline)
                        Text(preferencesManager.currentLanguage == "es" ? "Su ubicación está protegida y será difusa" : "Your location is protected and will be fuzzed")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)
                
                // Description Input
                VStack(alignment: .leading) {
                    Text(preferencesManager.currentLanguage == "es" ? "Por favor describa el incidente." : "Please describe the incident.")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextEditor(text: $reportText)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(minHeight: 120)
                        .onChange(of: reportText) { newValue in
                            // Limit characters
                            if newValue.count > maxCharacters {
                                reportText = String(newValue.prefix(maxCharacters))
                            }
                            characterCount = reportText.count
                            
                            // Auto-sanitize as user types
                            let sanitized = SecurityManager.shared.sanitizeTextInput(newValue)
                            if sanitized != newValue {
                                reportText = sanitized
                            }
                        }
                    
                    Text("\(characterCount)/\(maxCharacters)")
                        .font(.caption)
                        .foregroundColor(characterCount > Int(Double(maxCharacters) * 0.9) ? .red : .gray)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                
                // Photo Section
                VStack {
                    if let photo = selectedPhoto {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(10)
                            .overlay(
                                Button(action: { selectedPhoto = nil }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Circle())
                                }
                                .padding(8),
                                alignment: .topTrailing
                            )
                    } else {
                        HStack(spacing: 20) {
                            Button(action: { showingCamera = true }) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text(preferencesManager.currentLanguage == "es" ? "Tomar Foto" : "Take Photo")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                            
                            Button(action: { showingImagePicker = true }) {
                                VStack {
                                    Image(systemName: "photo.fill")
                                        .font(.title2)
                                    Text(preferencesManager.currentLanguage == "es" ? "Elegir de Galería" : "Choose from Gallery")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                            }
                        }
                    }
                }
                
                // Privacy Notice
                Text(preferencesManager.currentLanguage == "es" ? "Su reporte será enviado de forma anónima sin información de identificación" : "Your report will be submitted anonymously with no identifying information")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle(preferencesManager.currentLanguage == "es" ? "Reportar Problema" : "Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(preferencesManager.currentLanguage == "es" ? "Cancelar" : "Cancel") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(preferencesManager.currentLanguage == "es" ? "Enviar" : "Submit") {
                        submitReport()
                    }
                    .disabled(reportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedPhoto)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedPhoto)
        }
    }
    
    private func submitReport() {
        let trimmedText = reportText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Final sanitization before submission
        let sanitizedText = SecurityManager.shared.sanitizeTextInput(trimmedText)
        
        // Sanitize photo if present
        var sanitizedPhoto: UIImage?
        if let photo = selectedPhoto {
            sanitizedPhoto = SecurityManager.shared.sanitizeImage(photo)
        }
        
        onSubmit(sanitizedText, sanitizedPhoto)
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Sanitize the image to remove metadata
                parent.selectedImage = SecurityManager.shared.sanitizeImage(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Camera Picker
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.showsCameraControls = true
        
        // Disable location services for camera
        if let metadata = picker.value(forKey: "_cameraMetadata") as? NSMutableDictionary {
            metadata.setValue(false, forKey: "locationEnabled")
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        
        init(_ parent: CameraPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Sanitize the image to remove metadata
                parent.selectedImage = SecurityManager.shared.sanitizeImage(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}