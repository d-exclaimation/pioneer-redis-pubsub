import XCTest
import NIO
import RediStack
import Foundation
@testable import PioneerRedisPubSub

final class PioneerRedisPubSubTests: XCTestCase {
    private let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4)
    private let hostname = ProcessInfo.processInfo.environment["REDIS_HOSTNAME"] ?? "127.0.0.1"
    private let port = Int(ProcessInfo.processInfo.environment["REDIS_PORT"] ?? "6379") ?? RedisConnection.Configuration.defaultPort
    private lazy var client = try! RedisConnectionPool(
            configuration: .init(
                initialServerConnectionAddresses: [.makeAddressResolvingHost(hostname, port: port)], 
                maximumConnectionCount: .maximumActiveConnections(10), 
                connectionFactoryConfiguration: .init(
                    connectionInitialDatabase: nil,
                    connectionPassword: nil,
                    connectionDefaultLogger: .init(label: "TestLogger"),
                    tcpClient: nil
                ),
                minimumConnectionCount: 0,
                connectionBackoffFactor: 2,
                initialConnectionBackoffDelay: .milliseconds(0),
                connectionRetryTimeout: nil
            ), 
            boundEventLoop: eventLoopGroup.next()
        )

    func testConfig() async throws {
        let client = client
        let stream = await client.broadcast(for: "initial").downstream().stream
        let messageReceived0 = XCTestExpectation(description: "Message should be received")
        let closed0 = XCTestExpectation(description: "Channel should be closed")

        let task0 = Task {
            for await _ in stream {
                messageReceived0.fulfill()
            }
            closed0.fulfill()
        }

        let res = try await client.publish("hello", to: "initial").get()
        XCTAssert(res > 0)
        try? await Task.sleep(nanoseconds: 500_000)

        try await client.unsubscribe(from: "initial").get()
        wait(for: [messageReceived0, closed0], timeout: 2)
        task0.cancel()
    }

    /// RedisPubSub getting `AsyncStream` and publishing data
    /// - Should be able to receive data from all AsyncStream with the same trigger
    /// - Should be able to filter published data to only the same type
    /// - Should be able to publish data after the consumers were set up
    func testPublishingConsumingAndClosing() async throws {
        let pubsub = RedisPubSub(client)
        let trigger = "initial"
        let exp0 = XCTestExpectation()
        let exp1 = XCTestExpectation()
        let exp2 = XCTestExpectation()
        let exp3 = XCTestExpectation()
        let stream0 = pubsub.asyncStream(Int.self, for: trigger)
        let stream1 = pubsub.asyncStream(Int.self, for: trigger)
        
        let task = Task {
            for await each in stream0 {
                if each == 0 {
                    exp0.fulfill()
                }
                break
            }
            exp2.fulfill()
        }
        
        let task1 = Task {
            for await each in stream1 {
                if each == 0 {
                    exp1.fulfill()
                }
                break
            }
            exp3.fulfill()
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000)
        
        await pubsub.publish(for: trigger, payload: "invalid")
        await pubsub.publish(for: trigger, payload: 0)
        
        wait(for: [exp0, exp1], timeout: 2)
        
        await pubsub.close(for: trigger)

        wait(for: [exp2, exp3], timeout: 1)

        task.cancel()
        task1.cancel()
    }
    
    // /// AsyncPubSub closing all consumer for a specific trigger
    // /// - Should close all consumer with the same trigger
    // /// - Should never receive anything from any consumer
    // func testClosing() async throws {
    //     let pubsub = RedisPubSub(client)
    //     let trigger = "bad"
    //     let exp0 = XCTestExpectation(description: "Not closed on 1st")
    //     let exp1 = XCTestExpectation(description: "Not closed on 2nd")

    //     let stream = pubsub.asyncStream(Bool.self, for: trigger)
    //     let stream1 = pubsub.asyncStream(Bool.self, for: trigger)


    //     await pubsub.publish(for: trigger, payload: true)

    //     let task = Task {
    //         for await _ in stream {
    //         }
    //         exp0.fulfill()
    //     }
        
    //     let task1 = Task {
    //         for await _ in stream1 {
    //         }
    //         exp1.fulfill()
    //     }
        
    //     try? await Task.sleep(nanoseconds: 500_000)
        
    //     await pubsub.close(for: trigger)
        
    //     wait(for: [exp0, exp1], timeout: 2)
        
    //     task.cancel()
    //     task1.cancel()
    // }

    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
    }
}
