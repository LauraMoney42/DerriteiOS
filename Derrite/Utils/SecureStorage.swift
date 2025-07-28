//
//  SecureStorage.swift
//  Derrite
//
//  Created by Claude on 7/27/25.
//

import Foundation
import Security

class SecureStorage {
    static let shared = SecureStorage()
    
    private let keyPrefix = "com.derrite.secure."
    
    private init() {}
    
    // MARK: - Keychain Operations
    func save(_ data: Data, for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyPrefix + key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func load(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyPrefix + key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else { return nil }
        return dataTypeRef as? Data
    }
    
    func delete(for key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyPrefix + key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - Convenience Methods
    func saveSecureObject<T: Codable>(_ object: T, for key: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(object)
            
            // Encrypt the data before storing
            let encryptionKey = getOrCreateEncryptionKey()
            guard let encryptedData = SecurityManager.shared.encryptData(data, key: encryptionKey) else {
                return false
            }
            
            return save(encryptedData, for: key)
        } catch {
            print("Failed to encode object: \(error)")
            return false
        }
    }
    
    func loadSecureObject<T: Codable>(_ type: T.Type, for key: String) -> T? {
        guard let encryptedData = load(for: key) else { return nil }
        
        // Decrypt the data
        let encryptionKey = getOrCreateEncryptionKey()
        guard let decryptedData = SecurityManager.shared.decryptData(encryptedData, key: encryptionKey) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: decryptedData)
        } catch {
            print("Failed to decode object: \(error)")
            return nil
        }
    }
    
    // MARK: - Encryption Key Management
    private func getOrCreateEncryptionKey() -> String {
        let keyName = "master_encryption_key"
        
        if let keyData = load(for: keyName),
           let key = String(data: keyData, encoding: .utf8) {
            return key
        }
        
        // Generate new key
        let key = generateRandomKey()
        if let keyData = key.data(using: .utf8) {
            _ = save(keyData, for: keyName)
        }
        
        return key
    }
    
    private func generateRandomKey() -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<32).map{ _ in letters.randomElement()! })
    }
    
    // MARK: - Clear All Secure Data
    func clearAllSecureData() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyPrefix
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}