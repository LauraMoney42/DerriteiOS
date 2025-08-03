//  MLKitCompatibleTranslationService.swift
//  Derrite
//  iOS equivalent of Android MLKit Translation with dictionary fallback

import Foundation
import Translation
import NaturalLanguage

@available(iOS 17.4, *)
class MLKitCompatibleTranslationService {
    static let shared = MLKitCompatibleTranslationService()

    private var cache: [String: String] = [:]
    private let simpleTranslator = SimpleTranslationFallback()

    private init() {}

    // Dictionary fallback matching Android app exactly
    private class SimpleTranslationFallback {
        func detectLanguage(_ text: String) -> String {
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)

            if let language = recognizer.dominantLanguage {
                return language.rawValue.hasPrefix("es") ? "es" : "en"
            }

            // Fallback using same logic as Android
            let spanishWords = Set(["el", "la", "de", "que", "y", "a", "en", "un", "es", "se", "no", "te", "lo", "le", "da", "su", "por", "son", "con", "para", "al", "del", "está", "una", "su", "las", "los", "como", "pero", "sus", "le", "ha", "me", "si", "sin", "sobre", "este", "ya", "todo", "esta", "cuando", "muy", "sin", "puede", "están", "también", "hay"])

            let words = text.lowercased().split { !$0.isLetter }.map(String.init)
            let spanishMatches = words.filter { spanishWords.contains($0) }.count

            return spanishMatches > words.count * 3 / 10 ? "es" : "en"
        }

        func translateText(_ text: String, from fromLang: String, to toLang: String) -> String {
            // Basic keyword translation matching Android exactly
            let translations: [String: String]

            if fromLang == "es" && toLang == "en" {
                translations = [
                    "emergencia": "emergency",
                    "peligro": "danger",
                    "ayuda": "help",
                    "accidente": "accident",
                    "robo": "robbery",
                    "asalto": "assault",
                    "perdido": "lost",
                    "encontrado": "found",
                    "fiesta": "party",
                    "evento": "event",
                    "reunión": "meeting",
                    "problema": "problem",
                    "urgente": "urgent",
                    "seguridad": "safety",
                    "policía": "police",
                    "bomberos": "firefighters",
                    "hospital": "hospital",
                    "aquí": "here",
                    "ahora": "now",
                    "rápido": "quick",
                    "cuidado": "careful",
                    "prueba": "test",
                    "cerca": "near"
                ]
            } else if fromLang == "en" && toLang == "es" {
                translations = [
                    "emergency": "emergencia",
                    "danger": "peligro",
                    "help": "ayuda",
                    "accident": "accidente",
                    "robbery": "robo",
                    "assault": "asalto",
                    "lost": "perdido",
                    "found": "encontrado",
                    "party": "fiesta",
                    "event": "evento",
                    "meeting": "reunión",
                    "problem": "problema",
                    "urgent": "urgente",
                    "safety": "seguridad",
                    "police": "policía",
                    "firefighters": "bomberos",
                    "hospital": "hospital",
                    "here": "aquí",
                    "now": "ahora",
                    "quick": "rápido",
                    "careful": "cuidado",
                    "test": "prueba",
                    "near": "cerca",
                    "issue": "problema",
                    "me": "mí"
                ]
            } else {
                translations = [:]
            }

            var translatedText = text
            for (original, translation) in translations {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    translatedText = regex.stringByReplacingMatches(
                        in: translatedText,
                        range: NSRange(location: 0, length: translatedText.count),
                        withTemplate: translation
                    )
                }
            }

            return translatedText != text ? translatedText :
                (toLang == "es" ? "[Traducción no disponible] \(text)" : "[Translation unavailable] \(text)")
        }
    }

    func detectLanguage(_ text: String) -> String {
        return simpleTranslator.detectLanguage(text)
    }

    func translateText(_ text: String, from fromLang: String, to toLang: String) async -> Result<String, Error> {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return .failure(MLKitTranslationError.emptyText)
        }

        // Check cache first
        let cacheKey = "\(cleanText)_\(fromLang)_\(toLang)"
        if let cached = cache[cacheKey] {
            return .success(cached)
        }

        // Don't translate if same language
        if fromLang == toLang {
            return .success(cleanText)
        }

        // Use dictionary translation (matches Android fallback exactly)
        // Apple's Translation framework requires UI presentation, so we'll stick with dictionary approach
        return fallbackToSimpleTranslation(cleanText, from: fromLang, to: toLang, cacheKey: cacheKey)
    }


    private func fallbackToSimpleTranslation(_ text: String, from fromLang: String, to toLang: String, cacheKey: String) -> Result<String, Error> {
        let result = simpleTranslator.translateText(text, from: fromLang, to: toLang)
        cache[cacheKey] = result
        return .success(result)
    }

    func translateUserContent(_ text: String, toCurrentLanguage: Bool) async -> Result<String, Error> {
        let currentLanguage = PreferencesManager.shared.currentLanguage
        let sourceLanguage = toCurrentLanguage ? (currentLanguage == "es" ? "en" : "es") : currentLanguage
        let targetLanguage = toCurrentLanguage ? currentLanguage : (currentLanguage == "es" ? "en" : "es")

        return await translateText(text, from: sourceLanguage, to: targetLanguage)
    }

    func autoTranslateToCurrentLanguage(_ text: String) async -> String {
        let currentLanguage = PreferencesManager.shared.currentLanguage
        let detectedLanguage = detectLanguage(text)

        if detectedLanguage == currentLanguage {
            return text
        }

        let result = await translateText(text, from: detectedLanguage, to: currentLanguage)
        switch result {
        case .success(let translatedText):
            return translatedText
        case .failure:
            return text
        }
    }

    func clearCache() {
        cache.removeAll()
    }
}

// Simple translator fallback - standalone for legacy iOS
class SimpleTranslatorFallback {
    func detectLanguage(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage {
            return language.rawValue.hasPrefix("es") ? "es" : "en"
        }

        // Fallback using same logic as Android
        let spanishWords = Set(["el", "la", "de", "que", "y", "a", "en", "un", "es", "se", "no", "te", "lo", "le", "da", "su", "por", "son", "con", "para", "al", "del", "está", "una", "su", "las", "los", "como", "pero", "sus", "le", "ha", "me", "si", "sin", "sobre", "este", "ya", "todo", "esta", "cuando", "muy", "sin", "puede", "están", "también", "hay"])

        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        let spanishMatches = words.filter { spanishWords.contains($0) }.count

        return spanishMatches > words.count * 3 / 10 ? "es" : "en"
    }

    func translateText(_ text: String, from fromLang: String, to toLang: String) -> String {
        // Basic keyword translation matching Android exactly
        let translations: [String: String]

        if fromLang == "es" && toLang == "en" {
            translations = [
                "emergencia": "emergency",
                "peligro": "danger",
                "ayuda": "help",
                "accidente": "accident",
                "robo": "robbery",
                "asalto": "assault",
                "perdido": "lost",
                "encontrado": "found",
                "fiesta": "party",
                "evento": "event",
                "reunión": "meeting",
                "problema": "problem",
                "urgente": "urgent",
                "seguridad": "safety",
                "policía": "police",
                "bomberos": "firefighters",
                "hospital": "hospital",
                "aquí": "here",
                "ahora": "now",
                "rápido": "quick",
                "cuidado": "careful",
                "prueba": "test",
                "cerca": "near"
            ]
        } else if fromLang == "en" && toLang == "es" {
            translations = [
                "emergency": "emergencia",
                "danger": "peligro",
                "help": "ayuda",
                "accident": "accidente",
                "robbery": "robo",
                "assault": "asalto",
                "lost": "perdido",
                "found": "encontrado",
                "party": "fiesta",
                "event": "evento",
                "meeting": "reunión",
                "problem": "problema",
                "urgent": "urgente",
                "safety": "seguridad",
                "police": "policía",
                "firefighters": "bomberos",
                "hospital": "hospital",
                "here": "aquí",
                "now": "ahora",
                "quick": "rápido",
                "careful": "cuidado",
                "test": "prueba",
                "near": "cerca",
                "issue": "problema",
                "me": "mí"
            ]
        } else {
            translations = [:]
        }

        var translatedText = text
        for (original, translation) in translations {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                translatedText = regex.stringByReplacingMatches(
                    in: translatedText,
                    range: NSRange(location: 0, length: translatedText.count),
                    withTemplate: translation
                )
            }
        }

        return translatedText != text ? translatedText :
            (toLang == "es" ? "[Traducción no disponible] \(text)" : "[Translation unavailable] \(text)")
    }
}

// Fallback for older iOS versions
class LegacyTranslationService {
    static let shared = LegacyTranslationService()
    private let simpleTranslator = SimpleTranslatorFallback()

    private init() {}

    func translateText(_ text: String, from fromLang: String, to toLang: String) async -> Result<String, Error> {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return .failure(MLKitTranslationError.emptyText)
        }

        let result = simpleTranslator.translateText(cleanText, from: fromLang, to: toLang)
        return .success(result)
    }

    func translateUserContent(_ text: String, toCurrentLanguage: Bool) async -> Result<String, Error> {
        let currentLanguage = PreferencesManager.shared.currentLanguage
        let sourceLanguage = toCurrentLanguage ? (currentLanguage == "es" ? "en" : "es") : currentLanguage
        let targetLanguage = toCurrentLanguage ? currentLanguage : (currentLanguage == "es" ? "en" : "es")

        return await translateText(text, from: sourceLanguage, to: targetLanguage)
    }
}

enum MLKitTranslationError: Error, LocalizedError {
    case emptyText
    case translationFailed
    case networkError

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Text is empty"
        case .translationFailed:
            return "Translation failed"
        case .networkError:
            return "Network error"
        }
    }
}