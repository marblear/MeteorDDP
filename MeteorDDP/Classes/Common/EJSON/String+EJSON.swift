//
//  String+EJSON.swift
//
//  Created by Tom Brückner on 2024-01-31.
//

import Foundation

/// This extension is used to convert mock documents retrieved from MongoDB into Meteor's EJSON format.
/// NumberInt(1) is converted to 1, NumberFloat(1.1) to 1.1
/// ISODate(<date>) is converted to { "$date": <unix-timestamp> }

fileprivate let numberRegex = #"Number\w+\((\d+)\)"#
fileprivate let isoDateRegex = #"ISODate\("([^"]+)"\)"#

public extension String {
    var ejson: String {
        var transformedString = replacingOccurrences(of: numberRegex, with: "$1", options: .regularExpression)
        let matches = transformedString.matches(for: isoDateRegex)
        for match in matches {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = dateFormatter.date(from: match) {
                let timestamp = Int(date.timeIntervalSince1970 * 1000)
                transformedString = transformedString.replacingOccurrences(of: "ISODate(\"\(match)\")", with: "{ \"$date\": \(timestamp) }")
            }
        }
        return transformedString
    }

    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            return results.map {
                String(self[Range($0.range(at: 1), in: self)!])
            }
        } catch {
            print("Invalid regex: \(error.localizedDescription)")
            return []
        }
    }
}
