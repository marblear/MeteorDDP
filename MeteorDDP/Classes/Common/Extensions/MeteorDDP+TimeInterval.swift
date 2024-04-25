//
//  MeteorDDP+TimeInterval.swift
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

import Foundation

// MARK:- 🚀 MeteorDDP - TimeInterval internal extension
internal extension TimeInterval {
    
    
    /// Event fire helper
    /// - Parameters:
    ///   - queue: Queue type
    ///   - action: action closure
    func debounce( _ queue: DispatchQueue, action: @escaping (()->()) ) {
        
        guard self > 0 else {
            action()
            return
        }
        
        var lastFireTime = DispatchTime(uptimeNanoseconds: 0)
        let dispatchDelay = Int64(self * Double(NSEC_PER_SEC))
        lastFireTime = DispatchTime.now() + Double(0) / Double(NSEC_PER_SEC)
        queue.asyncAfter(
            deadline: DispatchTime.now() + Double(dispatchDelay) / Double(NSEC_PER_SEC)) {
                let now = DispatchTime.now() + Double(0) / Double(NSEC_PER_SEC)
                let when = lastFireTime + Double(dispatchDelay) / Double(NSEC_PER_SEC)
                if now >= when {
                    action()
                }
        }
    }
}
