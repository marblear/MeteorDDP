//
//  CodableValue.swift
//
//  Created by Tom Brückner on 2024-01-29.
//

import Foundation

public enum CodableValue: Codable {
    case int(Int)
    case float(Float)
    case string(String)
    case bool(Bool)
    case dictionary([String: CodableValue])
    case array([CodableValue])
    case date(Date)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let floatValue = try? container.decode(Float.self) {
            self = .float(floatValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let dict = try? container.decode([String: TimeInterval].self),
                  let timestamp = dict["$date"] {
            self = .date(Date(timeIntervalSince1970: timestamp / 1000))
        } else if let dictValue = try? container.decode([String: CodableValue].self) {
            self = .dictionary(dictValue)
        } else if let arrayValue = try? container.decode([CodableValue].self) {
            self = .array(arrayValue)
        } else {
            throw DecodingError.typeMismatch(CodableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Value is not of an expected type"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .int(intValue):
            try container.encode(intValue)
        case let .float(floatValue):
            try container.encode(floatValue)
        case let .string(stringValue):
            try container.encode(stringValue)
        case let .bool(boolValue):
            try container.encode(boolValue)
        case let .date(dateValue):
            try container.encode(["$date": dateValue.timeIntervalSince1970 * 1000])
        case let .dictionary(dictValue):
            try container.encode(dictValue)
        case let .array(array):
            try container.encode(array)
        }
    }
}
