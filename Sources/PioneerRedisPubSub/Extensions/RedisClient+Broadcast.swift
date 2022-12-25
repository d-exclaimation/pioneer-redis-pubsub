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
import typealias RediStack.RedisPubSubEventReceiver

extension RedisClient {
    /// Subscribes the client to the specified Redis channels and publish the messages into a broadcast
    /// - Parameter channel: The name of channels to subscribe to 
    /// - Returns: The broadcast to published the message to
    @discardableResult
    public func broadcast(given broadcast: Broadcast<Data> = .init(), for channel: RedisChannelName) async -> Broadcast<Data> {
        do {
            try await subscribe(to: channel) { event in
                switch (event) {
                    case .message(publisher:_, message: .bulkString(.some(let buffer))):
                        let data = Data(buffer: buffer)
                        Task {
                            await broadcast.publish(data)
                        }  
                    case .unsubscribed(key: _, currentSubscriptionCount: _, source: _):
                        Task {
                            await broadcast.close()
                        }
                    default:
                        break;
                }

            }.get()
        } catch {
            await broadcast.close()
        }
        return broadcast
    }
}