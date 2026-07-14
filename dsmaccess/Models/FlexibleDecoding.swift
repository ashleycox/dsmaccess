//
//  FlexibleDecoding.swift
//  dsmaccess
//
//  Décodage défensif des valeurs DSM dont le type JSON varie selon la version.
//

import Foundation

extension KeyedDecodingContainer {
    func flexInt(_ key: Key) -> Int? {
        if let value = try? decode(Int.self, forKey: key) { return value }
        if let value = try? decode(Int64.self, forKey: key) { return Int(exactly: value) }
        if let value = try? decode(Double.self, forKey: key) { return Int(value.rounded()) }
        if let value = try? decode(String.self, forKey: key) {
            if let integer = Int(value) { return integer }
            if let number = Double(value) { return Int(number.rounded()) }
        }
        return nil
    }

    func flexInt64(_ key: Key) -> Int64? {
        if let value = try? decode(Int64.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return Int64(value) }
        if let value = try? decode(Double.self, forKey: key) { return Int64(value.rounded()) }
        if let value = try? decode(String.self, forKey: key) {
            if let integer = Int64(value) { return integer }
            if let number = Double(value) { return Int64(number.rounded()) }
        }
        return nil
    }

    func flexBool(_ key: Key) -> Bool? {
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = flexInt(key) { return value != 0 }
        if let value = try? decode(String.self, forKey: key) {
            switch value.lowercased() {
            case "true", "yes", "on", "enabled": return true
            case "false", "no", "off", "disabled": return false
            default: return nil
            }
        }
        return nil
    }

    func flexString(_ key: Key) -> String? {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int64.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return value.formatted() }
        if let value = try? decode(Bool.self, forKey: key) { return value ? "true" : "false" }
        return nil
    }
}
