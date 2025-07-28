//
//  PreferencesManager.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import Foundation
import SwiftUI

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: languageKey)
        }
    }
    
    @Published var hasUserCreatedReports: Bool {
        didSet {
            UserDefaults.standard.set(hasUserCreatedReports, forKey: hasCreatedReportsKey)
        }
    }
    
    @Published var isLanguageChange: Bool {
        didSet {
            UserDefaults.standard.set(isLanguageChange, forKey: isLanguageChangeKey)
        }
    }
    
    @Published var enableSoundAlerts: Bool {
        didSet {
            UserDefaults.standard.set(enableSoundAlerts, forKey: soundAlertsKey)
        }
    }
    
    @Published var enableVibration: Bool {
        didSet {
            UserDefaults.standard.set(enableVibration, forKey: vibrationKey)
        }
    }
    
    @Published var alertDistanceMiles: Double {
        didSet {
            UserDefaults.standard.set(alertDistanceMiles, forKey: alertDistanceKey)
        }
    }
    
    @Published var emergencyAlertBypassSilent: Bool {
        didSet {
            UserDefaults.standard.set(emergencyAlertBypassSilent, forKey: emergencyAlertBypassKey)
        }
    }
    
    @Published var emergencyOverrideDistanceMiles: Double {
        didSet {
            UserDefaults.standard.set(emergencyOverrideDistanceMiles, forKey: emergencyOverrideDistanceKey)
        }
    }
    
    private let languageKey = "app_language"
    private let hasCreatedReportsKey = "has_created_reports"
    private let isLanguageChangeKey = "is_language_change"
    private let soundAlertsKey = "enable_sound_alerts"
    private let vibrationKey = "enable_vibration"
    private let alertDistanceKey = "alert_distance_miles"
    private let emergencyAlertBypassKey = "emergency_alert_bypass_silent"
    private let emergencyOverrideDistanceKey = "emergency_override_distance_miles"
    
    private init() {
        self.currentLanguage = UserDefaults.standard.string(forKey: languageKey) ?? "en"
        self.hasUserCreatedReports = UserDefaults.standard.bool(forKey: hasCreatedReportsKey)
        self.isLanguageChange = UserDefaults.standard.bool(forKey: isLanguageChangeKey)
        self.enableSoundAlerts = UserDefaults.standard.bool(forKey: soundAlertsKey)
        self.enableVibration = UserDefaults.standard.bool(forKey: vibrationKey)
        self.alertDistanceMiles = UserDefaults.standard.double(forKey: alertDistanceKey) == 0 ? 1.0 : UserDefaults.standard.double(forKey: alertDistanceKey)
        self.emergencyAlertBypassSilent = UserDefaults.standard.bool(forKey: emergencyAlertBypassKey)
        self.emergencyOverrideDistanceMiles = UserDefaults.standard.double(forKey: emergencyOverrideDistanceKey) == 0 ? 5.0 : UserDefaults.standard.double(forKey: emergencyOverrideDistanceKey)
    }
    
    func saveLanguage(_ language: String) {
        currentLanguage = language
    }
    
    func getSavedLanguage() -> String {
        return currentLanguage
    }
    
    func setAppLanguage(_ language: String) {
        // In iOS, we would typically use localization bundles
        // For now, we'll just track the preference
        currentLanguage = language
    }
    
    func setUserHasCreatedReports(_ value: Bool) {
        hasUserCreatedReports = value
    }
    
    func getUserHasCreatedReports() -> Bool {
        return hasUserCreatedReports
    }
    
    func setLanguageChange(_ value: Bool) {
        isLanguageChange = value
    }
    
    func getIsLanguageChange() -> Bool {
        return isLanguageChange
    }
    
    // MARK: - Localization Helpers
    func localizedString(_ key: String) -> String {
        // This would normally use NSLocalizedString
        // For now, we'll use a simple dictionary approach
        let strings = currentLanguage == "es" ? spanishStrings : englishStrings
        return strings[key] ?? key
    }
    
    private let englishStrings: [String: String] = [
        "app_name": "Derrite",
        "language_toggle": "Español",
        "settings": "Settings",
        "finding_location": "Finding your location...",
        "location_permission_needed": "Location permission needed",
        "create_report": "Create Pin",
        "add_to_favorites": "Add to Favorites",
        "cancel": "Cancel",
        "submit": "Submit",
        "safety": "Safety",
        "alerts": "Alerts",
        "favorites": "Favorites",
        "no_alerts": "All Clear!",
        "new_alert": "New Alert",
        "view_details": "View Details",
        "close": "Close",
        "search_address": "Search address...",
        
        // Critical missing keys
        "done": "Done",
        "alert_settings": "Alert Settings",
        "how_it_works": "How it works",
        "sound": "Sound",
        "sound_alerts": "Sound Alerts",
        "play_sound_when_receiving": "Play sound when receiving safety alerts",
        "vibration": "Vibration",
        "vibrate_for_alerts": "Vibrate when receiving safety alerts",
        "notification_distance": "Notification Distance",
        "choose_notification_distance": "Choose how far from your location or favorite places you want to receive notifications",
        "emergency_alert_mode": "Emergency Alert Mode",
        "bypass_silent_mode": "Bypass silent mode for safety alerts",
        "emergency_override_distance": "Emergency Override Distance",
        "reports_expire_8_hours": "Reports expire after 8 hours to ensure information stays current.",
        "emergency_alerts_explanation": "You will receive notifications when safety reports are created within your selected distance from your current location or any of your favorite places.",
        "emergency_bypass_explanation": "Emergency alerts will bypass silent mode only for reports within your emergency override distance, while regular notifications will still appear for all reports within your notification distance.",
        "emergency_alert_warning": "When enabled, safety alerts will play at full volume even when your phone is on silent. Use with caution as this can be disruptive.",
        "emergency_override_explanation": "Emergency alerts will only bypass silent mode if they are within this distance. Regular notifications will still appear for all reports within your notification distance.",
        
        // SettingsView
        "anonymous_safety_reporting": "Anonymous Safety Reporting",
        "version": "v1.0",
        "language": "Language",
        "app_language": "App Language",
        "notifications": "Notifications",
        "get_notified_nearby_reports": "Get notified of nearby reports",
        "on": "On",
        "off": "Off",
        "vibrate_for_alert_notifications": "Vibrate for alert notifications",
        "privacy_and_security": "Privacy & Security",
        "privacy_protection": "Privacy Protection",
        "learn_how_data_protected": "Learn how your data is protected",
        "location_privacy": "Location Privacy",
        "coordinates_automatically_fuzzed": "Coordinates are automatically fuzzed",
        "photo_security": "Photo Security",
        "exif_data_automatically_removed": "EXIF data automatically removed",
        "about": "About",
        "about_derrite": "About Derrite",
        "how_to_use": "How to Use",
        "long_press_map_to_report": "Long press on map to report safety issues",
        "debug": "Debug",
        "clear_all_data": "Clear All Data",
        
        // AboutView
        "derrite_description": "Derrite helps communities stay informed through anonymous safety reporting. Report incidents in your area while maintaining complete privacy and security.",
        "features": "Features",
        "anonymous_reporting_no_personal_data": "Anonymous reporting with no personal data stored",
        "location_privacy_coordinate_fuzzing": "Location privacy with automatic coordinate fuzzing",
        "photo_security_exif_removal": "Photo security with EXIF metadata removal",
        "realtime_alerts_nearby_reports": "Real-time alerts for nearby safety reports",
        "monitor_favorite_locations": "Monitor favorite locations for activity",
        "bilingual_support": "Bilingual support (English/Spanish)",
        "security": "Security",
        "privacy_top_priority": "Your privacy is our top priority. All reports are completely anonymous, with no way to trace them back to individuals. Location data is automatically fuzzed, photos are stripped of metadata, and all local data is encrypted.",
        
        // PrivacyView
        "privacy_protection_title": "Privacy Protection",
        "privacy_security_fundamental": "Your privacy and security are fundamental to how Derrite works.",
        "anonymous_reporting_title": "Anonymous Reporting",
        "anonymous_reporting_desc": "No personal information, device IDs, or identifiers are collected or stored. Reports cannot be traced back to individuals.",
        "location_privacy_title": "Location Privacy",
        "location_privacy_desc": "Report locations are automatically fuzzed within a ~100 meter radius before being sent to our servers. Favorite locations are stored exactly as you save them, but only locally on your device and are never transmitted.",
        "photo_security_title": "Photo Security",
        "photo_security_desc": "All photos are automatically stripped of EXIF metadata, GPS coordinates, and other identifying information before storage.",
        "local_data_storage": "Local Data Storage",
        "local_data_storage_desc": "Favorites and app settings are encrypted using AES-GCM encryption and stored locally in the secure keychain. This data never leaves your device.",
        "no_tracking": "No Tracking",
        "no_tracking_desc": "No analytics, crash reporting, or usage tracking. The app contains zero telemetry or tracking code.",
        "secure_communication": "Secure Communication",
        "secure_communication_desc": "All network requests use encrypted connections with no tracking headers or cookies.",
        "privacy": "Privacy",
        
        // Report timeAgo strings
        "just_now": "Just now",
        "min_ago": "min ago",
        "hr_ago": "hr ago",
        "day_ago": "day ago",
        
        // Distance formatting
        "mile": "mile",
        "miles": "miles",
        "selected": "Selected",
        "override": "Override",
        
        // ReportDetailsView
        "report": "Report",
        "reported": "Reported",
        "photo_evidence": "Photo Evidence",
        "description": "Description",
        "location": "Location",
        "report_status": "Report Status",
        "active": "Active",
        "expires": "Expires",
        "privacy_notice": "Privacy Notice",
        "report_submitted_anonymously": "This report was submitted anonymously. No personal information is stored or shared.",
        "ft_from_your_location": "ft from your location",
        "miles_from_your_location": "miles from your location",
        "ft_from": "ft from",
        "miles_from": "miles from",
        "expired": "Expired",
        "your_location": "your location",
        "from": "from",
        "ft": "ft",
        
        // Translation feature
        "translate": "Translate",
        "show_original": "Show Original",
        "translation_error": "Translation failed",
        "translating": "Translating...",
        
        // ContentView strings
        "what_would_you_like_to_do": "What would you like to do?",
        "report_safety_issue": "Report Safety Issue",
        "please_enter_address": "Please enter an address",
        "searching_address": "Searching address...",
        "found": "Found",
        "address_not_found": "Address not found",
        "speech_recognition_not_available": "Speech recognition not available",
        "speech_recognition_coming_soon": "Speech recognition coming soon...",
        "showing": "Showing",
        "unable_to_get_location": "Unable to get location",
        "safety_report_submitted": "Safety report submitted",
        "added_to_favorites": "added to favorites",
        "edit_functionality_coming_soon": "Edit functionality coming soon",
        "removed_from_favorites": "removed from favorites",
        "security_warning_jailbroken": "Security Warning: Device appears to be jailbroken",
        "safety_issue_near_favorite": "Safety issue near favorite location",
        "safety_issue_in_area": "Safety issue in your area",
        "long_press_instructions": "Long press anywhere on the map to report safety issues or add favorite places",
        "view_user_guide": "View User Guide"
    ]
    
    private let spanishStrings: [String: String] = [
        "app_name": "Derrite",
        "language_toggle": "English",
        "settings": "Configuración",
        "finding_location": "Encontrando tu ubicación...",
        "location_permission_needed": "Se necesita permiso de ubicación",
        "create_report": "Crear Pin",
        "add_to_favorites": "Agregar a Favoritos",
        "cancel": "Cancelar",
        "submit": "Enviar",
        "safety": "Seguridad",
        "alerts": "Alertas",
        "favorites": "Favoritos",
        "no_alerts": "¡Todo Despejado!",
        "new_alert": "Nueva Alerta",
        "view_details": "Ver Detalles",
        "close": "Cerrar",
        "search_address": "Buscar dirección...",
        
        // Critical missing keys
        "done": "Listo",
        "alert_settings": "Configuración de Alertas",
        "how_it_works": "Cómo funciona",
        "sound": "Sonido",
        "sound_alerts": "Alertas de Sonido",
        "play_sound_when_receiving": "Reproducir sonido al recibir alertas de seguridad",
        "vibration": "Vibración",
        "vibrate_for_alerts": "Vibrar al recibir alertas de seguridad",
        "notification_distance": "Distancia de Notificación",
        "choose_notification_distance": "Elige qué tan lejos de tu ubicación o lugares favoritos quieres recibir notificaciones",
        "emergency_alert_mode": "Modo de Alerta de Emergencia",
        "bypass_silent_mode": "Omitir modo silencioso para alertas de seguridad",
        "emergency_override_distance": "Distancia de Anulación de Emergencia",
        "reports_expire_8_hours": "Los reportes expiran después de 8 horas para garantizar que la información se mantenga actualizada.",
        "emergency_alerts_explanation": "Recibirás notificaciones cuando se creen reportes de seguridad dentro de tu distancia seleccionada desde tu ubicación actual o cualquiera de tus lugares favoritos.",
        "emergency_bypass_explanation": "Las alertas de emergencia omitirán el modo silencioso solo para reportes dentro de tu distancia de anulación de emergencia, mientras que las notificaciones regulares aparecerán para todos los reportes dentro de tu distancia de notificación.",
        "emergency_alert_warning": "Cuando está habilitado, las alertas de seguridad se reproducirán a todo volumen incluso cuando tu teléfono esté en silencio. Úsalo con precaución ya que puede ser disruptivo.",
        "emergency_override_explanation": "Las alertas de emergencia solo omitirán el modo silencioso si están dentro de esta distancia. Las notificaciones regulares seguirán apareciendo para todos los reportes dentro de tu distancia de notificación.",
        
        // SettingsView
        "anonymous_safety_reporting": "Reporte Anónimo de Seguridad",
        "version": "v1.0",
        "language": "Idioma",
        "app_language": "Idioma de la App",
        "notifications": "Notificaciones",
        "get_notified_nearby_reports": "Recibe notificaciones de reportes cercanos",
        "on": "Activado",
        "off": "Desactivado",
        "vibrate_for_alert_notifications": "Vibrar para notificaciones de alerta",
        "privacy_and_security": "Privacidad y Seguridad",
        "privacy_protection": "Protección de Privacidad",
        "learn_how_data_protected": "Aprende cómo se protegen tus datos",
        "location_privacy": "Privacidad de Ubicación",
        "coordinates_automatically_fuzzed": "Las coordenadas se difuminan automáticamente",
        "photo_security": "Seguridad de Fotos",
        "exif_data_automatically_removed": "Los datos EXIF se eliminan automáticamente",
        "about": "Acerca de",
        "about_derrite": "Acerca de Derrite",
        "how_to_use": "Cómo Usar",
        "long_press_map_to_report": "Mantén presionado en el mapa para reportar problemas de seguridad",
        "debug": "Depuración",
        "clear_all_data": "Borrar Todos los Datos",
        
        // AboutView
        "derrite_description": "Derrite ayuda a las comunidades a mantenerse informadas a través de reportes anónimos de seguridad. Reporta incidentes en tu área manteniendo completa privacidad y seguridad.",
        "features": "Características",
        "anonymous_reporting_no_personal_data": "Reportes anónimos sin datos personales almacenados",
        "location_privacy_coordinate_fuzzing": "Privacidad de ubicación con difuminado automático de coordenadas",
        "photo_security_exif_removal": "Seguridad de fotos con eliminación de metadatos EXIF",
        "realtime_alerts_nearby_reports": "Alertas en tiempo real para reportes cercanos de seguridad",
        "monitor_favorite_locations": "Monitorear ubicaciones favoritas para actividad",
        "bilingual_support": "Soporte bilingüe (Inglés/Español)",
        "security": "Seguridad",
        "privacy_top_priority": "Tu privacidad es nuestra máxima prioridad. Todos los reportes son completamente anónimos, sin forma de rastrearlos de vuelta a individuos. Los datos de ubicación se difuminan automáticamente, las fotos se limpian de metadatos, y todos los datos locales están encriptados.",
        
        // PrivacyView
        "privacy_protection_title": "Protección de Privacidad",
        "privacy_security_fundamental": "Tu privacidad y seguridad son fundamentales para cómo funciona Derrite.",
        "anonymous_reporting_title": "Reportes Anónimos",
        "anonymous_reporting_desc": "No se recopila ni almacena información personal, IDs de dispositivos o identificadores. Los reportes no se pueden rastrear de vuelta a individuos.",
        "location_privacy_title": "Privacidad de Ubicación",
        "location_privacy_desc": "Las ubicaciones de reportes se difuminan automáticamente dentro de un radio de ~100 metros antes de enviarse a nuestros servidores. Las ubicaciones favoritas se almacenan exactamente como las guardas, pero solo localmente en tu dispositivo y nunca se transmiten.",
        "photo_security_title": "Seguridad de Fotos",
        "photo_security_desc": "Todas las fotos se limpian automáticamente de metadatos EXIF, coordenadas GPS y otra información identificativa antes del almacenamiento.",
        "local_data_storage": "Almacenamiento Local de Datos",
        "local_data_storage_desc": "Los favoritos y configuraciones de la app están encriptados usando encriptación AES-GCM y almacenados localmente en el llavero seguro. Estos datos nunca salen de tu dispositivo.",
        "no_tracking": "Sin Rastreo",
        "no_tracking_desc": "Sin analíticas, reportes de fallos o rastreo de uso. La app no contiene código de telemetría o rastreo.",
        "secure_communication": "Comunicación Segura",
        "secure_communication_desc": "Todas las solicitudes de red usan conexiones encriptadas sin encabezados de rastreo o cookies.",
        "privacy": "Privacidad",
        
        // Report timeAgo strings
        "just_now": "Justo ahora",
        "min_ago": "min atrás",
        "hr_ago": "hr atrás",
        "day_ago": "día atrás",
        
        // Distance formatting
        "mile": "milla",
        "miles": "millas",
        "selected": "Seleccionado",
        "override": "Anular",
        
        // ReportDetailsView
        "report": "Reporte",
        "reported": "Reportado",
        "photo_evidence": "Evidencia Fotográfica",
        "description": "Descripción",
        "location": "Ubicación",
        "report_status": "Estado del Reporte",
        "active": "Activo",
        "expires": "Expira",
        "privacy_notice": "Aviso de Privacidad",
        "report_submitted_anonymously": "Este reporte fue enviado de forma anónima. No se almacena ni comparte información personal.",
        "ft_from_your_location": "pies de tu ubicación",
        "miles_from_your_location": "millas de tu ubicación",
        "ft_from": "pies de",
        "miles_from": "millas de",
        "expired": "Expirado",
        "your_location": "tu ubicación",
        "from": "de",
        "ft": "pies",
        
        // Translation feature
        "translate": "Traducir",
        "show_original": "Mostrar Original",
        "translation_error": "Error de traducción",
        "translating": "Traduciendo...",
        
        // ContentView strings
        "what_would_you_like_to_do": "¿Qué te gustaría hacer?",
        "report_safety_issue": "Reportar problema de seguridad",
        "please_enter_address": "Por favor ingresa una dirección",
        "searching_address": "Buscando dirección...",
        "found": "Encontrado",
        "address_not_found": "Dirección no encontrada",
        "speech_recognition_not_available": "Reconocimiento de voz no disponible",
        "speech_recognition_coming_soon": "Reconocimiento de voz próximamente...",
        "showing": "Mostrando",
        "unable_to_get_location": "No se puede obtener la ubicación",
        "safety_report_submitted": "Reporte de seguridad enviado",
        "added_to_favorites": "agregado a favoritos",
        "edit_functionality_coming_soon": "Funcionalidad de edición próximamente",
        "removed_from_favorites": "eliminado de favoritos",
        "security_warning_jailbroken": "Advertencia de Seguridad: El dispositivo parece estar liberado",
        "safety_issue_near_favorite": "Problema de seguridad cerca de ubicación favorita",
        "safety_issue_in_area": "Problema de seguridad en tu área",
        "long_press_instructions": "Mantén presionado en cualquier lugar del mapa para reportar problemas de seguridad o agregar lugares favoritos",
        "view_user_guide": "Ver Guía del Usuario"
    ]
}