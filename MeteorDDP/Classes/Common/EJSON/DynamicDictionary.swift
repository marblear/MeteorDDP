//
//  DynamicDictionary.swift
//
//  Created by Tom Brückner on 2024-01-29.
//

import Foundation

public struct DynamicDictionary: Codable {
    private var data: [String: CodableValue]

    public init(data: [String: CodableValue]) {
        self.data = data
    }

    public subscript(key: String) -> DynamicDictionary? {
        if case let .dictionary(dict) = data[key] {
            return DynamicDictionary(data: dict)
        }
        return nil
    }

    public func stringValue(forKey key: String) -> String? {
        if case let .string(value) = data[key] {
            return value
        }
        return nil
    }

    public func intValue(forKey key: String) -> Int? {
        if case let .int(value) = data[key] {
            return value
        }
        return nil
    }

    public func boolValue(forKey key: String) -> Bool? {
        if case let .bool(value) = data[key] {
            return value
        }
        return nil
    }

    public func floatValue(forKey key: String) -> Float? {
        if case let .float(value) = data[key] {
            return value
        }
        return nil
    }

    public func dateValue(forKey key: String) -> Date? {
        if case let .dictionary(dict) = data[key],
           let timestampValue = dict["$date"],
           case let .int(timestamp) = timestampValue {
            return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
        }
        return nil
    }

    public func arrayValue(forKey key: String) -> [CodableValue]? {
        if case let .array(array) = data[key] {
            return array
        }
        return nil
    }

    // Implement `init(from decoder: Decoder)` to decode each key-value pair
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)
        var tempData = [String: CodableValue]()
        for key in container.allKeys {
            let value = try container.decode(CodableValue.self, forKey: key)
            tempData[key.stringValue] = value
        }
        data = tempData
    }

    // Implement `encode(to encoder: Encoder)` to encode each key-value pair
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (key, value) in data {
            try container.encode(value, forKey: DynamicCodingKeys(stringValue: key)!)
        }
    }
}

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.intValue = intValue
        stringValue = String(intValue)
    }
}

/// allows an easier access to properties that are [String: CodableValue] dictionaries

/// Example for a structure like this:
/// {
///  name: {
///         firstName: 'Tom'
///         lastName: 'Brückner'
///  }
/// }
///
/// that we want to parse it into
///
/// struct Spot: EJSONCodable {
///     properties: <Type>
/// }

/// if <Type> was [String: CodableValue]?, one would have to access the properties like so:
///
/// if let nameProperty = spot.properties?["name"],
///      case .dictionary(let nameDict) = nameProperty,
///      let lastNameProperty = nameDict["lastName"],
///      case .string(let lastName) = lastNameProperty {
///     // Now we have lastName as a String
///     print("Last Name: \(lastName)")
///  }

/// if <Type> is DynamicDictionary?, values can be accessed by subscripting
/// spot.properties?["name"]?.stringValue(forKey: "lastName")
