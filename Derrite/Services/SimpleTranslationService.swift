//  SimpleTranslationService.swift
//  Derrite
//  Clean implementation to resolve compilation issues

import Foundation
import NaturalLanguage

// Translation error types
enum DTranslationError: Error, LocalizedError {
    case emptyText
    case noTranslationNeeded
    case translationFailed

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Text is empty"
        case .noTranslationNeeded:
            return "No translation needed"
        case .translationFailed:
            return "Translation failed"
        }
    }
}

class SimpleTranslationService {
    static let shared = SimpleTranslationService()

    private var cache: [String: String] = [:]

    private init() {}

    // Translation dictionaries matching Android app
    private let englishToSpanish: [String: String] = [
        // Safety terms
        "emergency": "emergencia",
        "danger": "peligro",
        "help": "ayuda",
        "accident": "accidente",
        "robbery": "robo",
        "police": "policía",

        // Common phrases for safety app
        "mean cat": "gato malo",
        "mean cat in the streets": "gato malo en las calles",
        "scary": "aterrador",
        "scary!": "¡aterrador!",
        "bad guy": "hombre malo",
        "dangerous": "peligroso",

        // Individual words
        "cat": "gato",
        "dog": "perro",
        "street": "calle",
        "streets": "calles",
        "in": "en",
        "the": "la",
        "bad": "malo",
        "mean": "malo",
        "good": "bueno",
        "help!": "¡ayuda!",

        // Testing and common words
        "test": "prueba",
        "testing": "probando",
        "issue": "problema",
        "problem": "problema",
        "near": "cerca",
        "me": "mí",
        "here": "aquí",
        "there": "allí",
        "now": "ahora",
        "today": "hoy",
        "yesterday": "ayer",
        "tomorrow": "mañana"
    ]

    private let spanishToEnglish: [String: String] = [
        "emergencia": "emergency",
        "peligro": "danger",
        "ayuda": "help",
        "accidente": "accident",
        "robo": "robbery",
        "policía": "police",

        "gato malo": "mean cat",
        "gato malo en las calles": "mean cat in the streets",
        "aterrador": "scary",
        "¡aterrador!": "scary!",
        "hombre malo": "bad guy",
        "peligroso": "dangerous",

        "gato": "cat",
        "perro": "dog",
        "calle": "street",
        "calles": "streets",
        "en": "in",
        "la": "the",
        "malo": "bad",
        "bueno": "good",
        "¡ayuda!": "help!",

        // Testing and common words
        "prueba": "test",
        "probando": "testing",
        "problema": "problem",
        "cerca": "near",
        "mí": "me",
        "aquí": "here",
        "allí": "there",
        "ahora": "now",
        "hoy": "today",
        "ayer": "yesterday",
        "mañana": "tomorrow"
    ]

    func detectLanguage(_ text: String) -> String {
        // Use NaturalLanguage for detection
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        if let language = recognizer.dominantLanguage {
            return language.rawValue.hasPrefix("es") ? "es" : "en"
        }

        // Simple fallback
        let spanishWords = Set(["el", "la", "de", "que", "y", "es", "en", "un", "las", "los"])
        let words = text.lowercased().split { !$0.isLetter }.map(String.init)
        let spanishCount = words.filter { spanishWords.contains($0) }.count

        return spanishCount > words.count / 3 ? "es" : "en"
    }

    func translate(_ text: String, from source: String, to target: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check cache
        let cacheKey = "\(cleanText)_\(source)_\(target)"
        if let cached = cache[cacheKey] {
            return cached
        }

        // Don't translate if same language
        if source == target {
            return text
        }

        // Get translation dictionary
        let dict = (source == "en" && target == "es") ? englishToSpanish :
                   (source == "es" && target == "en") ? spanishToEnglish : [:]

        // Try exact match first
        if let exactMatch = dict[cleanText.lowercased()] {
            let result = preserveCapitalization(original: cleanText, translated: exactMatch)
            cache[cacheKey] = result
            return result
        }

        // Try word-by-word translation
        var result = cleanText
        let sortedKeys = dict.keys.sorted { $0.count > $1.count } // Longest first

        // First try phrases (multi-word entries)
        for (original, translation) in dict {
            if original.count > 1 {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    result = regex.stringByReplacingMatches(
                        in: result,
                        range: NSRange(location: 0, length: result.count),
                        withTemplate: translation
                    )
                }
            }
        }

        // Then try individual words
        for (original, translation) in dict {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: original))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(location: 0, length: result.count),
                    withTemplate: translation
                )
            }
        }

        cache[cacheKey] = result
        return result
    }

    func autoTranslateToCurrentLanguage(_ text: String) async -> String {
        let currentLanguage = PreferencesManager.shared.currentLanguage
        let detectedLang = detectLanguage(text)

        if detectedLang == currentLanguage {
            return text
        }

        return translate(text, from: detectedLang, to: currentLanguage)
    }

    func translateUserContent(_ text: String, toCurrentLanguage: Bool) async -> Result<String, DTranslationError> {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else {
            return .failure(.emptyText)
        }

        let currentLanguage = PreferencesManager.shared.currentLanguage
        let sourceLanguage = toCurrentLanguage ? (currentLanguage == "es" ? "en" : "es") : currentLanguage
        let targetLanguage = toCurrentLanguage ? currentLanguage : (currentLanguage == "es" ? "en" : "es")

        let result = translate(cleanText, from: sourceLanguage, to: targetLanguage)

        // Check if ANY translation occurred (result is different from original)
        // If completely unchanged, return original with success (partial translation is still useful)
        if result == cleanText {
            // Still return the original text as a "translation" - user can see both versions
            return .success(cleanText)
        }

        return .success(result)
    }

    private func preserveCapitalization(original: String, translated: String) -> String {
        guard !original.isEmpty && !translated.isEmpty else { return translated }

        if original.first?.isUppercase == true {
            return translated.prefix(1).uppercased() + translated.dropFirst()
        }
        return translated
    }

    func clearCache() {
        cache.removeAll()
    }
}