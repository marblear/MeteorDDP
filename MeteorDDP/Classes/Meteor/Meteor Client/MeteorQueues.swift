//
//  MeteorQueues.swift
//  Marbleverse
//
//  Created by Tom Brückner on 2024-02-09.
//

import Foundation

struct MeteorQueues {
    // Background data queue
    let background: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) Background Data Queue"
        /// Fixed: DDP messages have to be in order to make subscriptions reliable
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()
    
    // Callbacks execute in the order they're received
    let methodResult: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) Callback Queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // Sub requests are sent in the order they are created
    let subSend: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) Sub Queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // Callbacks execute in the order they're received
    let subResult: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) Sub Callback Queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // Document messages are processed in the order that they are received, separately from callbacks
    let documentMessages: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) Background Queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .background
        return queue
    }()
    
    // Queue for server ping pong handling
    let heartbeat: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) Heartbeat Queue"
        queue.qualityOfService = .utility
        return queue
    }()
    
    // Background queue for current user
    let userBackground: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "\(METEOR_DDP) High Priority Background Queue"
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    // Main queue for current user
    let userMain: OperationQueue = {
        let queue = OperationQueue.main
        queue.name = "\(METEOR_DDP) High Priorty Main Queue"
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
//    // Subscription queue
//    let subQueue: DispatchQueue = {
//        DispatchQueue(label: "\(METEOR_DDP)-subscription-handler", attributes: .concurrent)
//    }()
}
