//
//  MeteorCollection+Type.swift
//  Marbleverse
//
//  Created by Tom Brückner on 2024-01-22.
//

import Foundation

public extension MeteorCollection {
    func findOne<T: EJSONCodable>(id: String, asType: T.Type) -> T? {
        guard let dictionary = findOne(id) else {
            return nil
        }
        do {
            var codable = try EJSONDecoder().decode(type: asType, from: dictionary)
            codable._id = id
            return codable
        } catch {
            logger.logError(.doc, "document \(id) could not be decoded")
            logger.logError(.doc, "error: \(error)")
            return nil
        }
    }

    func find<T: EJSONCodable>(asType: T.Type) -> [T] {
        documents.map { document in
            if let id = document["_id"] as? String {
                return findOne(id: id, asType: T.self)
            } else {
                return nil
            }
        }.filter { spot in
            spot != nil
        } as! [T]
    }
}
