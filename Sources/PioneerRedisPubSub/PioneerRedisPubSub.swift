//
//  PioneerRedisPubSub.swift
//  PioneerRedisPubSub
//
//  Created by d-exclaimation on 17:56.
//

import Foundation
import NIOFoundationCompat
import class Pioneer.Broadcast
import struct RediStack.RedisChannelName
import protocol RediStack.RedisClient

/// RedisPubSub is a Redis channel backed pubsub structure for managing AsyncStreams in a concurrent safe way utilizing Actors.
public struct RedisPubSub {
    /// An actor for dispatching Redis channel subscription to multiple broadcasting
    actor Dispatcher {
        /// RedisClient used to create a channel subscription
        private let redis: RedisClient

        /// All broadcasting for all channels
        private var broadcasting: [String: Broadcast<Data>] = [:]

        init(_ redis: RedisClient) {
            self.redis = redis
        }

        /// Get the AsyncStream for the specific Redis channel
        /// - Parameter channel: The Redis channel name
        /// - Returns: An AsyncStream **just** for the subscriber
        internal func downstream(to channel: String) async throws -> AsyncThrowingStream<Data, Error> {
            let broadcast = try await subscribe(to: channel)
            let downstream = await broadcast.downstream()
            return downstream.stream
        }

        /// Get the appropriate broadcasting for the Redis channel, if hasn't exist yet, create a new one
        /// - Parameter channel: The Redis channel name
        /// - Returns: A broadcast actor for the channel
        private func subscribe(to channel: String) async throws -> Broadcast<Data> {
            if let broadcast = broadcasting[channel] {
                return broadcast
            }
            let broadcast = Broadcast<Data>()
            broadcasting[channel] = broadcast
            try await redis.broadcast(given: broadcast, for: .init(channel))
            return broadcast
        }

        /// Publish a data to a certain Redis channel
        /// - Parameters:
        ///   - channel: The Redis channel name
        ///   - value: The data to be published
        internal func publish(for channel: String, _ value: Data) async throws {
            let _ = try await redis.publish(value, to: .init(channel)).get()
        }

        /// Close Redis subscription and unsubscribed all subscriber for the channel
        /// - Parameter channel: The Redis channel name
        internal func close(for channel: String) async throws {
            try? await redis.unsubscribe(from: .init(channel)).get()
            await broadcasting[channel]?.close()
        }

    }

    /// The internal dispatcher for Dispatcher
    internal let dispatcher: Dispatcher

    public init(_ redis: RedisClient) {
        self.dispatcher = .init(redis)
    }
}
