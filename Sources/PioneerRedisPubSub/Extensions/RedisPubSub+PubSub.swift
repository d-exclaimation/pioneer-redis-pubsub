//
//  RedisPubSub+PubSub.swift
//  PioneerRedisPubSub
//
//  Created by d-exclaimation on 18:32.
//

import Foundation
import protocol Pioneer.PubSub

extension RedisPubSub: PubSub {
    /// Returns a new AsyncStream with the correct type and for a specific trigger
    /// - Parameters:
    ///   - type: DataType of this AsyncStream
    ///   - trigger: The topic string used to differentiate what data should this stream be accepting
    /// - Returns: A Redis-backed subscriber for a specific channel that can be detached and unsubscribed individually 
    public func asyncStream<DataType: Sendable & Decodable>(_ type: DataType.Type = DataType.self, for trigger: String) -> AsyncStream<DataType> {
        AsyncStream<DataType> { con in
            let task = Task {
                let broadcast = await dispatcher.downstream(to: trigger)
                for await data in broadcast {
                    guard let event = try? JSONDecoder().decode(DataType.self, from: data) else { continue }
                    con.yield(event)
                }
                con.finish()
            }
            con.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    public func publish<DataType: Sendable & Encodable>(for trigger: String, payload: DataType) async {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        await dispatcher.publish(for: trigger, data)
    }

    public func close(for trigger: String) async {
        await dispatcher.close(for: trigger)
    }
}
