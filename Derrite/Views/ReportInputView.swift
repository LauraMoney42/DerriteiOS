//  ReportInputView.swift
//  Derrite

import SwiftUI
import PhotosUI
import CoreLocation
import AVFoundation

struct ReportInputView: View {
    let location: CLLocationCoordinate2D
    let onSubmit: (String, UIImage?) -> Void
    let onCancel: () -> Void

    @State private var reportText = ""
    @State private var selectedPhoto: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var characterCount = 0
    @State private var validationError: String?
    @State private var showingValidationError = false
    @State private var errorMessage: String?
    @State private var showError = false
    @StateObject private var preferencesManager = PreferencesManager.shared
    @StateObject private var authManager = AuthenticationManager.shared

    private let inputValidator = InputValidator.shared
    private var maxCharacters: Int { inputValidator.maxReportLength }

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
                        Text(preferencesManager.currentLanguage == "es" ? "Ubicación exacta para reportes precisos" : "Exact location for accurate reports")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.systemBlue).opacity(0.1))
                .cornerRadius(10)

                // Anonymity Notice
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.blue)
                    Text(preferencesManager.localizedString("anonymity_notice"))
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                }
                .padding()
                .background(Color(UIColor.systemBlue).opacity(0.1))
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
                        .onChange(of: reportText) { _, newValue in
                            // Limit characters using InputValidator
                            if newValue.count > maxCharacters {
                                reportText = String(newValue.prefix(maxCharacters))
                            }
                            characterCount = reportText.count

                            // Clear validation error when user starts typing again
                            if showingValidationError {
                                showingValidationError = false
                                validationError = nil
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
                            Button(action: { 
                                requestCameraPermission()
                            }) {
                                VStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                    Text(preferencesManager.currentLanguage == "es" ? "Tomar Foto" : "Take Photo")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(UIColor.systemBlue).opacity(0.1))
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
                                .background(Color(UIColor.systemBlue).opacity(0.1))
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
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
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
                    .alert("Validation Error", isPresented: $showingValidationError) {
                        Button("OK") {
                            showingValidationError = false
                            validationError = nil
                        }
                    } message: {
                        Text(validationError ?? "Invalid input")
                    }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $selectedPhoto)
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker(selectedImage: $selectedPhoto)
        }
        .onChange(of: showingCamera) { isShowing in
            // Set camera usage flag to prevent Face ID prompting during camera use
            authManager.setCameraInUse(isShowing)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {
                showError = false
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func submitReport() {
        // Dismiss keyboard first
        hideKeyboard()
        
        // Validate report text
        let validation = inputValidator.safeValidateReportText(reportText)
        if !validation.isValid {
            validationError = validation.error
            showingValidationError = true
            return
        }

        guard let validatedText = validation.sanitizedText else {
            validationError = "Failed to process report text"
            showingValidationError = true
            return
        }

        // Validate photo if present
        var validatedPhoto: UIImage?
        if let photo = selectedPhoto {
            let photoValidation = inputValidator.safeValidateImage(photo)
            if !photoValidation.isValid {
                validationError = photoValidation.error ?? "Invalid image"
                showingValidationError = true
                return
            }
            validatedPhoto = photoValidation.sanitizedImage
        }

        onSubmit(validatedText, validatedPhoto)
    }
    
    private func requestCameraPermission() {
        // Check if camera is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            errorMessage = preferencesManager.currentLanguage == "es" ? 
                "La cámara no está disponible en este dispositivo" :
                "Camera is not available on this device"
            showError = true
            return
        }
        
        // Check current authorization status
        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authorizationStatus {
        case .authorized:
            // Permission already granted
            showingCamera = true
            
        case .notDetermined:
            // Request permission
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.showingCamera = true
                    } else {
                        self.errorMessage = self.preferencesManager.currentLanguage == "es" ?
                            "Se requiere acceso a la cámara para tomar fotos. Ve a Configuración para permitir el acceso." :
                            "Camera access is required to take photos. Go to Settings to allow access."
                        self.showError = true
                    }
                }
            }
            
        case .denied, .restricted:
            // Permission denied - direct user to settings
            errorMessage = preferencesManager.currentLanguage == "es" ?
                "Se requiere acceso a la cámara. Ve a Configuración > Privacidad > Cámara y activa el acceso para Alerta." :
                "Camera access is required. Go to Settings > Privacy > Camera and enable access for Alerta."
            showError = true
            
        @unknown default:
            errorMessage = preferencesManager.currentLanguage == "es" ?
                "Error desconocido al acceder a la cámara" :
                "Unknown error accessing camera"
            showError = true
        }
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
        picker.cameraDevice = .rear
        
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
            defer {
                parent.presentationMode.wrappedValue.dismiss()
            }
            
            guard let image = info[.originalImage] as? UIImage else {
                return
            }
            
            // Sanitize the image to remove metadata
            parent.selectedImage = SecurityManager.shared.sanitizeImage(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}