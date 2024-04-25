//
//  MeteorClient+Sub.swift
//  MeteorDDP
//
//  Created by engrahsanali on 2020/04/17.
//  Copyright (c) 2020 engrahsanali. All rights reserved.
//
/*

 Copyright (c) 2020 Muhammad Ahsan Ali, AA-Creations

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.

 */

// MARK: - 🚀 MeteorClient+Sub - interacting with basic Meteor server-side services

import Foundation

internal extension MeteorClient {
    /// Iterates over the Dictionary of subscriptions to find a subscription by name
    /// - Parameter name: name

    func findSubscriptionId(byName name: String) -> String? {
        subRequests[name]?.id
    }

    func findSubscription(byCollection name: String) -> SubHolder? {
        subCollections[name]
    }

    /// Sub Ready
    /// - Parameter subs: sub IDs array
    func ready(_ subs: [String]) {
        subs.forEach { id in
            if let sub = subHandlers[id] {
                sub.completion?()
                subHandlers[id]?.completion = nil
            }
        }
    }

    /// UnSub
    /// - Parameters:
    ///   - id: ID
    ///   - error: error
    func nosub(_ id: String, error: MeteorError?) {
        guard let error = error else {
            if let sub = subHandlers[id] {
                sub.completion?()
                subHandlers.removeValue(forKey: id)
            }
            return
        }
        error.log(.unsub)
    }

    /// Subcscrption
    /// - Parameters:
    ///   - id: ID
    ///   - name: sub name
    ///   - params: dictionary
    ///   - callback: callback
    @discardableResult
    func sub(_ id: String, name: String, params: [Any]?, collectionName: String?, callback: MeteorCollectionCallback?, completion: MeteorCompletionVoid?) -> String {
        
//        log("\(id): Subscribing to \(name) for \(String(describing: collectionName)) \(String(describing: params))")
        
        var messages: [MessageOut] = [.msg(.sub), .name(name), .id(id)]
        if let p = params { messages.append(.params(p)) }
        
        var previousId: String?

        if let subRequest = subRequests[name] { /// Previously bound messages with same callbacks
            if subRequest.id == id {
                /// We want to re-subscribe to an existing subscription after a connection broke up and was re-connected,
                /// see MeteorClient.restoreSubscription()
                /// So we re-send the original messages, including the original parameters.
                messages = subRequest.messages
            }
            else {
                /// We have a new sub with a different id for the same sub name.
                /// Thus, we have to unsub after sub to get rid of unwanted documents.
                /// So we store the id of the original sub here to use it for the unsub later.
                previousId = subRequest.id
                // TODO: Check when this can be cleared
                subRequests[name]?.id = id
                // TODO: Check if this can be unified with the code below
                subHandlers[id] = SubHolder(name: name, collectionName: collectionName, completion: completion, callback: callback)
            }
        } else {
            /// We have a completely new subscription with the given name
            subRequests[name] = SubRequest(id: id, messages: messages) // Request object from sub name
            let subHolder = SubHolder(name: name, collectionName: collectionName, completion: completion, callback: callback)
            subHandlers[id] = subHolder
            if let collectionName = collectionName {
                subCollections[collectionName] = subHolder
            }
        }
        
        /// Subscribe
        let subOperation = BlockOperation { [weak self] in
            if let self = self {
                self.sendMessage(msgs: messages)
            } else {
                logger.logError(.sub, "MeteorClient destroyed or not initiated yet. Message ignored")
            }
        }
//        log("Subscribing sub \(id)")
        queues.subSend.addOperation(subOperation)

        /// If there was a previous subscription with the same name, but a different id,
        /// we have to unsubscribe from the previous sub after subscribing to the new one;
        /// this makes Meteor send remove messages for documents that are not in scope anymore
        /// In contrast to the original implemention, we're using a BlockOperation with a dependency
        /// on the subOperation to ensure that unsub comes after sub.
        if let unsubId = previousId {
            let unsubOperation = BlockOperation { [weak self] in
                guard let self = self else { return }
//                log("\(unsubId): Unsubscribing from \(name) for \(String(describing: collectionName))")
                self.sendMessage(msgs: [.msg(.unsub), .id(unsubId)])
                /// the sub handler for unsubId will be removed once the unsub message is received, see nosub()
            }
            unsubOperation.addDependency(subOperation)
//            log("Unsubscribing sub \(previousId)")
            queues.subSend.addOperation(unsubOperation)
        }

        return id
    }

//    func clearSubRequestData(with id: String) {
//        guard let handler = subHandlers[id] else { return }
//        logger.log(.sub, "Clear sub request data \(handler.name) for id:\(id)", .debug)
//        subRequests[handler.name] = nil
//        subHandlers[id] = nil
//    }
}

// MARK: - MeteorClient Sub for interacting with basic Meteor server-side services

public extension MeteorClient {
    /// Sends a subscription request to the server. If a callback is passed, the callback asynchronously runs when the client receives a 'ready' message indicating that the initial subset of documents contained in the subscription has been sent by the server.
    /// - Parameters:
    ///   - name: The name of the subscription
    ///   - params: An object containing method arguments, if any
    ///   - collectionName: The closure of events against this collection name if provided
    ///   - callback: The closure to be executed when the server sends a 'ready' message
    @discardableResult
    func subscribe(_ name: String, params: [Any]?, collectionName: String? = nil, callback: MeteorCollectionCallback? = nil, completion: MeteorCompletionVoid? = nil) -> String {
        let id = String.randomString
        logger.log(.sub, "Collection [\(name)] with id [\(id)] and params \(params?.debugDescription ?? "[]")", .info)
        return sub(id, name: name, params: params, collectionName: collectionName, callback: callback, completion: completion)
    }

    /// Sends an unsubscribe request to the server. If a callback is passed, the callback asynchronously runs when the client receives a 'ready' message indicating that the subset of documents contained in the subscription have been removed.
    /// - Parameters:
    ///   - id: The name of the subscription
    ///   - callback: The closure to be executed when the server sends a 'ready' message
    func unsubscribe(_ id: String, completion: MeteorCompletionVoid?) {
        queues.background.addOperation {
            self.sendMessage(msgs: [.msg(.unsub), .id(id)])
        }
        subHandlers[id]?.completion = completion
        logger.log(.unsub, "with id [\(id)]", .info)
    }

    /// UnSub All
    /// - Parameter callback: completion
    func unsubscribeAll(_ completion: MeteorCompletionVoid?) {
        subHandlers.keys.forEach { unsubscribe($0, completion: completion) }
    }

    /// Unsubscribe Sends an unsubscribe request to the server.
    /// - Parameters:
    ///   - name: The name of the subscription
    ///   - allowRemove:  Auto remove messages after unsub
    ///   - callback: The closure to be executed when the server sends a 'ready' message
    func unsubscribe(withName name: String, allowRemove: Bool = true, callback: MeteorCompletionVoid?) {
        guard let id = findSubscriptionId(byName: name) else {
            logger.log(.unsub, "Cannot find name \(name)", .info)
            callback?()
            return
        }
        if !allowRemove {
            subHandlers[id]?.callback = nil
            removeEventObservers(name, event: MeteorEvents.collection)
        }
        unsubscribe(id) {
            logger.log(.unsub, "Removed data due to unsubscribe \(name)", .debug)
            self.subRequests[name] = nil
            DispatchQueue.main.async { callback?() }
        }
    }

    /// Unsubscribe collection
    /// - Parameters:
    ///   - name: name of the collection
    ///   - allowRemove: flag to allow document remove
    ///   - callback: completion callback
    func unsubscribe(withCollection name: String, allowRemove: Bool = true, callback: MeteorCompletionVoid?) {
        if let sub = findSubscription(byCollection: name) {
            unsubscribe(withName: sub.name, allowRemove: allowRemove, callback: callback)
        } else {
            callback?()
        }
    }

    /// Update Collection
    /// - Parameters:
    ///   - collection: name
    ///   - type: operation type
    ///   - documents: documents data
    ///   - callback: completion
    @discardableResult
    func updateCollection(_ collection: String, type: CollectionMethod, documents: [Any], callback: MeteorMethodCallback? = nil) -> String {
        let callName = "/\(collection)/\(type.rawValue)"
        return call(callName, params: documents, callback: callback)
    }

    /// Check if the collection name or subscription name is already subscribed
    /// - Parameter name: collection name or subscription name
    /// - Returns:isSubcribed flag
    func isSubcribed(_ name: String) -> Bool {
        findSubscriptionId(byName: name) != nil ||
            findSubscription(byCollection: name) != nil
    }

    func subscribe(name: String, of collection: String, params: [String: Any]?, allowRemove: Bool, callback: @escaping ((MeteorDocumentChange, MeteorCollectionEvents) -> Void)) {
        removeEventObservers(collection, event: [.dataAdded, .dataRemove, .dataChange])

        addEventObserver(collection, event: .dataAdded) {
            let value = $0 as! MeteorDocumentChange
            callback(value, .dataAdded)
        }

        addEventObserver(collection, event: .dataChange) {
            let value = $0 as! MeteorDocumentChange
            callback(value, .dataChange)
        }

        addEventObserver(collection, event: .dataRemove) {
            let value = $0 as! MeteorDocumentChange
            callback(value, .dataRemove)
        }

        unsubscribe(withCollection: collection, allowRemove: allowRemove) {
            self.subscribe(name, params: [params as Any], collectionName: collection, callback: nil, completion: nil)
        }
    }
}
