//
//  EJSONCodable.swift
//  Marbleverse
//
//  Created by Tom Brückner on 2024-01-21.
//

import Foundation

/// Codeable extension that allows to parse an object to and from Meteor's EJSON
/// Also supports
/// - partial updating using a partial EJSON that only includes some of the model object properties
/// - parsing of EJSON's date format { $date: <UnixTimeStamp> }

protocol EJSONCodable: Codable, Equatable {
    var _id: String? { get set }
    func updatedInstance(updatedJSON: Data, clearedJSON: Data?) throws -> Self
}

extension EJSONCodable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs._id == rhs._id
    }
}

extension EJSONCodable {
    func updatedInstance(updatedJSON: MeteorKeyValue, clearedJSON: [String: Any]? = nil) throws -> Self {
        let updatedData = try JSONSerialization.data(withJSONObject: updatedJSON, options: [])
        let clearedData = try clearedJSON.map { try JSONSerialization.data(withJSONObject: $0, options: []) }
        return try updatedInstance(updatedJSON: updatedData, clearedJSON: clearedData)
    }

    func updatedInstance(updatedJSON: Data, clearedJSON: Data? = nil) throws -> Self {
        // 1. Encode the original object to a dictionary
        let originalData = try EJSONEncoder().encode(self)
        var originalDict = try JSONSerialization.jsonObject(with: originalData, options: []) as? [String: Any] ?? [:]

        // 2. Parse and merge updated values
        let updatedDict = try JSONSerialization.jsonObject(with: updatedJSON, options: []) as? [String: Any] ?? [:]
        mergeDictionaries(original: &originalDict, updated: updatedDict)

        // 3. Remove cleared keys
        let clearedKeys = (try clearedJSON.map { try JSONSerialization.jsonObject(with: $0, options: []) as? [String] }) ?? []
        clearedKeys?.forEach { originalDict.removeValue(forKey: $0) }

        // 4. Decode to an updated object
        let finalData = try JSONSerialization.data(withJSONObject: originalDict, options: [])
        
        let decoder = EJSONDecoder()

        let updatedObject = try decoder.decode(Self.self, from: finalData)
        return updatedObject
    }

    private func mergeDictionaries(original: inout MeteorKeyValue, updated: [String: Any], deep: Bool = false) {
        for (key, value) in updated {
            if deep == true, var originalSubDict = original[key] as? [String: Any], let updatedSubDict = value as? [String: Any] {
                mergeDictionaries(original: &originalSubDict, updated: updatedSubDict)
                original[key] = originalSubDict
            } else {
                original[key] = value
            }
        }
    }

    func toJsonString(pretty: Bool = false) -> String? {
        let encoder = EJSONEncoder()
        if pretty {
            encoder.outputFormatting = .prettyPrinted
        }
        do {
            let jsonData = try encoder.encode(self)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            } else { }
        } catch {
        }
        return nil
    }
}

