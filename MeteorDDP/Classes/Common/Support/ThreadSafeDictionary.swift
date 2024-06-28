//
//  ThreadSafeDictionary.swift
//
//
//  Created by Tom Brückner on 2024-06-28.
//

import Foundation

final class ThreadSafeDictionary<Key: Hashable, Value> {
    private var dictionary: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "MeteorDDP.ThreadSafeDictionary", attributes: .concurrent)

    func value(forKey key: Key) -> Value? {
        return queue.sync {
            dictionary[key]
        }
    }

    func setValue(_ value: Value, forKey key: Key) {
        queue.async(flags: .barrier) {
            self.dictionary[key] = value
        }
    }

    func removeValue(forKey key: Key) {
        queue.async(flags: .barrier) {
            self.dictionary.removeValue(forKey: key)
        }
    }

    func forEach(_ body: ((key: Key, value: Value)) throws -> Void) rethrows {
        try queue.sync {
            try dictionary.forEach(body)
        }
    }

    subscript(key: Key) -> Value? {
        get {
            return queue.sync {
                dictionary[key]
            }
        }
        set {
            queue.async(flags: .barrier) {
                self.dictionary[key] = newValue
            }
        }
    }

    var keys: [Key] {
        return queue.sync {
            Array(dictionary.keys)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.dictionary.removeAll()
        }
    }
}
