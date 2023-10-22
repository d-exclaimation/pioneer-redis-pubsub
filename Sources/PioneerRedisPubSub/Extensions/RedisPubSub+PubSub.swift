//
//  RedisPubSub+PubSub.swift
//  PioneerRedisPubSub
//
//  Created by d-exclaimation on 18:32.
//

import Foundation
import protocol Pioneer.PubSub
import struct Pioneer.PubSubConversionError

extension RedisPubSub: PubSub {
    /// Returns a new AsyncStream with the correct type and for a specific trigger
    /// - Parameters:
    ///   - type: DataType of this AsyncStream
    ///   - trigger: The topic string used to differentiate what data should this stream be accepting
    /// - Returns: A Redis-backed subscriber for a specific channel that can be detached and unsubscribed individually 
    public func asyncStream<DataType: Sendable & Decodable>(_ type: DataType.Type = DataType.self, for trigger: String) -> AsyncThrowingStream<DataType, Error> {
        AsyncThrowingStream<DataType, Error> { con in
            let task = Task {
                do {
                    let broadcast = try await dispatcher.downstream(to: trigger)
                    for try await data in broadcast {
                        guard let event = try? JSONDecoder().decode(DataType.self, from: data) else { 
                            con.finish(throwing: PubSubConversionError(reason: "Failed to decode data to \(DataType.self)"))
                            continue
                        }
                        con.yield(event)
                    }
                } catch {
                    con.finish(throwing: error)
                }
                con.finish()
            }
            con.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func publish<DataType: Sendable & Encodable>(for trigger: String, payload: DataType) async throws {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try await dispatcher.publish(for: trigger, data)
    }

    public func close(for trigger: String) async throws {
        try await dispatcher.close(for: trigger)
    }
}
