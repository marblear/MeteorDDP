//
//  EJSONDecoder.swift
//
//  Created by Tom Brückner on 2024-01-25.
//

import Foundation

public class EJSONDecoder: JSONDecoder {

    public override init() {
        super.init()
        self.dateDecodingStrategy = ejsonDateDecodingStrategy()
    }

    public func decode<T: Codable>(type: T.Type, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decode(T.self, from: data)
    }
    
    func ejsonDateDecodingStrategy() -> JSONDecoder.DateDecodingStrategy {
        return .custom { decoder -> Date in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode([String: TimeInterval].self)

            guard let timestamp = dateString["$date"] else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Date format not valid")
            }

            return Date(timeIntervalSince1970: timestamp / 1000)
        }
    }
}
