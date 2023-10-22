//
//  Broadcast+Redis.swift
//  PioneerRedisPubSub
//
//  Created by d-exclaimation on 18:13.
//

import Foundation
import class Pioneer.Broadcast
import protocol RediStack.RedisClient
import enum RediStack.RESPValue
import struct RediStack.RedisChannelName

///
/// This code needed to be updated when RediStack reaches v2.0.0
/// ```swift
/// try await subscribe(to: channel) { event in
///     switch (event) {
///         case .message(publisher:_, message: .bulkString(.some(let buffer))):
///             let data = Data(buffer: buffer)
///             Task {
///                 await broadcast.publish(data)
///             }  
///         case .unsubscribed(key: _, currentSubscriptionCount: _, source: _):
///             Task {
///                 await broadcast.close()
///             }
///         default:
///             break;
///     }
/// }.get()
/// ```

extension RedisClient {
    /// Subscribes the client to the specified Redis channels and publish the messages into a broadcast
    /// - Parameter channel: The name of channels to subscribe to 
    /// - Returns: The broadcast to published the message to
    @discardableResult
    public func broadcast(given broadcast: Broadcast<Data> = .init(), for channel: RedisChannelName) async throws -> Broadcast<Data> {
        do {
            let future = subscribe(
                to: channel,
                messageReceiver: { _, msg in
                    guard case .bulkString(.some(let buffer)) = msg else { return }
                    let data = Data(buffer: buffer)
                    Task {
                        await broadcast.publish(data)
                    } 
                }, 
                onUnsubscribe: { _, _ in 
                    Task {
                        await broadcast.close()
                    }
                }
            )
            try await future.get()
        } catch {
            await broadcast.close()
            throw error
        }
        return broadcast
    }
}