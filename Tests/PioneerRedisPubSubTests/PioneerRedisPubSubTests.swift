import XCTest
import NIO
import RediStack
import Foundation
@testable import PioneerRedisPubSub

final class PioneerRedisPubSubTests: XCTestCase {
    private var eventLoopGroup: EventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 4) 
    private var client: RedisConnectionPool!


    override func setUp() async throws {
        let hostname = ProcessInfo.processInfo.environment["REDIS_HOSTNAME"] ?? "127.0.0.1"
        let port = Int(ProcessInfo.processInfo.environment["REDIS_PORT"] ?? "6379") ?? RedisConnection.Configuration.defaultPort

        // For RediStack v2 or higher
        // client = try RedisConnectionPool(
        //     configuration: .init(
        //         initialServerConnectionAddresses: [
        //             .makeAddressResolvingHost(hostname, port: port)
        //         ], 
        //         connectionCountBehavior: .strict(maximumConnectionCount: 10, minimumConnectionCount: 0),
        //         connectionConfiguration: .init(defaultLogger: .init(label: "TestLogger"))
        //     ), 
        //     boundEventLoop: eventLoopGroup.next()
        // )


        client = try RedisConnectionPool(
            configuration: .init(
                initialServerConnectionAddresses: [
                    .makeAddressResolvingHost(hostname, port: port)
                ], 
                maximumConnectionCount: .maximumActiveConnections(2), 
                connectionFactoryConfiguration: .init()
            ),
            boundEventLoop: eventLoopGroup.next()
        )
    }

    override func tearDown() async throws {
        let promise = eventLoopGroup.next().makePromise(of: Void.self)
        client.close(promise: promise)
        try await promise.futureResult.get()
    }

    /// RedisPubSub getting `AsyncThrowingStream` and publishing data
    /// - Should be able to receive data from all AsyncStream with the same trigger
    /// - Should be able to publish data after the consumers were set up
    /// - Should be able to close subscribers after the channel has closed
    func testPublishingConsumingAndClosing() async throws {
        let pubsub = RedisPubSub(client)
        let trigger = "initial"
        let exp0 = XCTestExpectation(description: "Expected to receive `0` for stream0")
        let exp1 = XCTestExpectation(description: "Expected to receive `0` for stream1")
        let exp2 = XCTestExpectation(description: "Expected stream0 to be closed")
        let exp3 = XCTestExpectation(description: "Expected stream1 to be closed")
        let stream0 = pubsub.asyncStream(Int.self, for: trigger)
        let stream1 = pubsub.asyncStream(Int.self, for: trigger)
        
        let task = Task {
            for try await each in stream0 {
                if each == 0 {
                    exp0.fulfill()
                } else {
                    break
                }
            }
            exp2.fulfill()
        }
        
        let task1 = Task {
            for try await each in stream1 {
                if each == 0 {
                    exp1.fulfill()
                } else {
                    break
                }
            }
            exp3.fulfill()
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000)
        
        try await pubsub.publish(for: trigger, payload: 0)
        
        await fulfillment(of: [exp0, exp1], timeout: 2)
        
        try await pubsub.close(for: trigger)

        wait(for: [exp2, exp3], timeout: 1)

        task.cancel()
        task1.cancel()
    }

    /// RedisPubSub getting `AsyncThrowingStream` and publishing data
    /// - Should throw an error when publishing data that cannot be encoded
    func testPublishingWrongDataType() async throws {
        let pubsub = RedisPubSub(client)
        let trigger = "initial"
        let exp0 = XCTestExpectation(description: "Expected to not receive `\"invalid\"` for stream0")
        let stream0 = pubsub.asyncStream(Int.self, for: trigger)
        
        let task = Task {
            do {
                for try await _ in stream0 {
                    return
                }
            } catch {
                exp0.fulfill()
            } 
        }
        
 
        try? await Task.sleep(nanoseconds: 1_000_000)
        
        try await pubsub.publish(for: trigger, payload: "invalid")
        
        wait(for: [exp0], timeout: 2)
        
        try await pubsub.close(for: trigger)

        task.cancel()
    }
}
