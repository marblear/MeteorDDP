//
//  MeteorClient.swift
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

//
// This software uses CryptoSwift: https://github.com/krzyzanowskim/CryptoSwift/
//

import Foundation

// MARK: - 🚀 Meteor Client - Responsible to manage DDP interaction with provided websocket events

public class MeteorClient {
    /// ddp version
    var version: String
    /// ddp support
    var support: [String]
    /// web sockets
    var socket: MeteorWebSockets
    /// subscription handler for subscription ids
    var subHandlers = [String: SubHolder]()
    /// subscription holder for collection names
    var subCollections = [String: SubHolder]()
    /// mongo collection observers
    var observers = [String: NSObjectProtocol]()
    // subscription requests against names
    var subRequests = [String: SubRequest]()
    /// methods handler
    var methodHandler: [String: MethodHolder]?
    /// own user, as saved and retrieved from UserDefaults
    public var ownUser: MeteorOwnUser?
    /// is user logged in
    var isLoggedIn = false
    /// ddp ping pong
    var server: (ping: Date?, pong: Date?) = (nil, nil)
    /// collections handler with name
    var collections = [String: MeteorCollection]()
    /// session connected callback; will only be called once, when first connection is established
    var onSessionConnected: ((String) -> Void)?
    /// session disconnected callback
    public var onSessionDisconnected: ((String?) -> Void)?
    /// session reconnected callback
    public var onSessionReconnected: ((String) -> Void)?
    /// Session id for reconnection
    public var sessionId: String?
    /// auto-resubscribe all subscriptions if a websocket connection has bee re-established
    public var autoSubReconnect: Bool = true
    /// will be set to false on first successful connect
    public var firstConnect: Bool = true
    /// flag for auto connection if websocket disconnect
    public var autoReconnect: Bool = true
    /// flag if auto-reconnect is in progress
    public var tryingToReconnect: Bool = false
    /// timer used for auto-reconnect
    var reconnectionTimer: Timer?
    /// meteor ddp and websocket events delegate
    public weak var delegate: MeteorDelegate?

    let queues = MeteorQueues()

    // Warning to avoid synchronous operations on main UI thread
    let syncWarning = { (name: String) in
        if Thread.isMainThread {
            logger.logError(.mainThread, "\(name) is running synchronously on the main thread. It should run on a background thread")
        }
    }

    let methodInvokeGroup = DispatchGroup()

    /// Flag to check the socket connection
    public var isSocketConnected: Bool {
        socket.isConnectedToNetwork && socket.isConnected
    }

    /// Meteor connection flag
    public var isConnected: Bool {
        isSocketConnected && sessionId != nil
    }

    /// DDP client to init with websocket interface and configurations
    /// - Parameters:
    ///   - url: websocket url
    ///   - webSocket: websocket method for preference
    ///   - requestTimeout: network request max timeout
    ///   - version: ddp version
    ///   - support: ddp support
    public init(url: String,
                webSocket: WebSocketMethod = .starscream,
                requestTimeout: Double = 15,
                version: String = "1",
                support: [String] = ["1"]) {
        self.version = version
        self.support = support
        socket = MeteorWebSockets(url, webSocket, requestTimeout)
    }

    /// DDP client to init with websocket interface and configurations
    /// - Parameters:
    ///   - url: websocket url
    ///   - webSocket: websocket interface
    ///   - requestTimeout: network request max timeout
    ///   - version: ddp version
    ///   - support: ddp support
    public init(url: String,
                webSocket: MeteorWebSockets,
                requestTimeout: Double = 15,
                version: String = "1",
                support: [String] = ["1"]) {
        self.version = version
        self.support = support
        socket = webSocket
    }

    /// Connects the ddp server and bind websocket events with the provided websocket interfacxe
    /// - Parameter callback: ddp session
    public func connect(callback: ((String) -> Void)?) {
        methodHandler = [:]
        onSessionConnected = callback
        bindEvent()
        socket.configureWebSocket()
    }

    /// Disconnects and remove events for provided websocket interface
    /// - Parameters:
    ///   - forced: Remove last session id and not suppose to reconnect
    ///   - receiveEvents: receive disconnect events
    public func disconnect(forced: Bool = true, receiveEvents: Bool = false) {
        if !receiveEvents {
            socket.onEvent = nil
            delegate = nil
            notificationCenter.removeObserver(self)
        }
        if forced {
            sessionId = nil
        }
        socket.disconnect()
    }

    /// Auto trigger reconnection
    public func triggerReconnect(callback: ((String) -> Void)? = nil) {
        guard !isConnected else {
            logger.log(.socket, "MeteorDDP is already connected", .info)
            return
        }
        guard !tryingToReconnect else {
            logger.log(.socket, "MeteorDDP is already trying to reconnect", .info)
            return
        }
        tryingToReconnect = true
        broadcastEvent(MeteorEvents.reconnection.rawValue, event: .reconnection, value: callback as Any)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                guard let self = self else { return }
                self.connect { [weak self] sessionId in
                    guard let self = self else { return }
                    /// Caution: Do not call onSessionConnected here, since this will be set to this closure in connect(),
                    /// so we would create an infinite loop
                    self.onSessionReconnected?(sessionId)
                    self.tryingToReconnect = false
                    timer.invalidate()
                }
                self.ping()
            }
        }
    }
}

// MARK: - 🚀 Meteor Client -

internal extension MeteorClient {
    /// Send ddp message
    /// - Parameter msgs: list of ddp outgoing messages
    func sendMessage(msgs: [MessageOut], log: Bool = true) {
        syncWarning("Socket Message send")
        let msg = makeMessage(msgs).toJson!
        if log { logger.log(.socket, msg, .info) }
        socket.send(msg)
    }

    /// Bind websocket events
    fileprivate func bindEvent() {
        let events: ((WebSocketEvent) -> Void) = { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .connected:
                self.eventOnOpen()
                /// onSessionConnected() will be called when DDP connection is fully established
                /// see messageInHandle()

            case .disconnected:
                self.onSessionDisconnected?(self.sessionId)
                if self.autoReconnect {
                    self.triggerReconnect(callback: self.onSessionConnected)
                }

            case let .text(text):
                self.handleResponse(text)

            case let .error(error):
                if let error = error {
                    logger.logError(.socket, "\(String(describing: error.localizedDescription))")
                }
                if self.autoReconnect && !self.tryingToReconnect {
                    self.triggerReconnect()
                }
            }
            self.delegate?.didReceive(name: .websocket, event: event)
        }
        socket.onEvent = events
    }

    /// Handle response in queue
    /// - Parameter text: Incomming message
    func handleResponse(_ text: String) {
//        log("handleResponse: \(text.prefix(100))")
        queues.background.addOperation {
            self.messageInHandle(text)
        }
    }

    /// DDP connection open event
    fileprivate func eventOnOpen() {
        queues.heartbeat.addOperation {
            var messages: [MessageOut] = [.msg(.connect), .version(self.version), .support(self.support)]
            if let sessionId = self.sessionId {
                messages.append(.session(sessionId))
            }
            self.sendMessage(msgs: messages)
        }
    }

    /// Will be called after a socket connection has been restored after a connection breakup
    /// to restore all previous subscriptions (if autoSubReconnect is true)
    func restoreSubscriptions() {
        if !autoSubReconnect { return }
        subRequests.forEach { name, req in
            logger.log(.login, "auto sub reconnect \(name)", .debug)
            sub(req.id, name: name, params: nil, collectionName: nil, callback: nil, completion: nil)
        }
    }
}
