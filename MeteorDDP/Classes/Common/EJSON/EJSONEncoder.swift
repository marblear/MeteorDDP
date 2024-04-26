//
//  EJSONEncoder.swift
//
//  Created by Tom Brückner on 2024-01-25.
//

import Foundation

public class EJSONEncoder: JSONEncoder {
    public override init() {
        super.init()
        dateEncodingStrategy = ejsonDateEncodingStrategy()
    }

    public func encodeToDictionary<T: Codable>(_ value: T) throws -> [String: Any] {
        let data = try encode(value)
        guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: [], debugDescription: "Expected to encode to a dictionary but found a different type instead"))
        }
        return dictionary
    }
    
    func ejsonDateEncodingStrategy() -> JSONEncoder.DateEncodingStrategy {
        return .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(["$date": date.timeIntervalSince1970 * 1000])
        }
    }
}
