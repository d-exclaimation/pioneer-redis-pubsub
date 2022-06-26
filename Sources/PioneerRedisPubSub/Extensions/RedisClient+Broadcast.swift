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

extension RedisClient {
    /// Subscribes the client to the specified Redis channels and publish the messages into a broadcast
    /// - Parameter channel: The name of channels to subscribe to 
    /// - Returns: The broadcast to published the message to
    public func broadcast(for channel: RedisChannelName) async -> Broadcast<Data> {
        let broadcast = Broadcast<Data>()
        do {
            try await subscribe(
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
            .get()
        } catch {
            await broadcast.close()
        }
        return broadcast
    }
}