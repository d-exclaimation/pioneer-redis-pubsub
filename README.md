# PioneerRedisPubSub

This package implements the PubSub protocol from the [Pioneer](https://github.com/d-exclaimation/pioneer) package. It allows you to use a Redis-backed Pub/Sub with similar interface as the [AsyncPubSub](https://pioneer-graphql.netlify.app/guides/advanced/subscriptions/#asyncpubsub) and use it for your subscription resolvers.

## Setup

```swift
.package(url: "https://github.com/d-exclaimation/pioneer-redis-pubsub", from: "1.0.0")
```

## Usage

Create a RedisPubSub instance (Here is an example using [Vapor's Redis integration](https://docs.vapor.codes/redis/overview/)):

```swift
import Vapor
import Redis
import Pioneer
import PioneerRedisPubSub

let app = try Application(.detect())

app.redis.configuration = try RedisConfiguration(hostname: "localhost")

struct Resolver {
    let pubsub: PubSub = RedisPubSub(app.redis)
}
```

Now, implement your subscription resolver function, using the `pubsub.asyncStream` and call `.toEventStream()` to convert into an EventStream using [AsyncEventStream](https://pioneer-graphql.netlify.app/features/async-event-stream/)

Internally calling the method `.asyncStream` of the RedisPubSub will send redis a `SUBSCRIBE` message to the topic provided if there hasn't been a subscription for that topic.

```swift
import Graphiti

extension Resolver {
    var ON_MESSAGE: String {
        "some-redis-channel"
    }

    func somethingChanged(_: Context, _: NoArguments) -> EventStream<Message> {
        pubsub
            .asyncStream(Message.self, for: ON_MESSAGE)
            .toEventStream()
    }
}
```

RedisPubSub manages internally a collection of subscribers (using Actors) which can be individually unsubscribe without having to close all other subcriber of the same topic. Every time the `.publish` method is called, RedisPubSub will `PUBLISH` the event over redis which will be picked up by the RedisPubSub if there exist subscriber(s) for that topic.

Now, call `.publish` method whenever you want to push an event to the subscriber(s).

```swift
extension Resolver {
    func changeSomething(_: Context, args: SomeArgs) async -> Message {
        let message = Message(using: args)
        await pubsub.publish(for: ON_MESSAGE, payload: message)
        return message
    }
}
```

In cases where you no longer want push any message to any subscriber and/or consider a topic closed, you can call the `.close` method for a topic to shutdown all active subcribers for that topic and end the subscription operation.

```swift
extension Resolver {
    func closeSomething(_: Context, _: NoArguments) async -> Bool {
        await pubsub.close(for: ON_MESSAGE)
        return true
    }
}
```

> :warning: RedisPubSub itself does not automatically unsubscribed from any active channels except when `.close` is called, including when it has been disposed / deinitialized!

### More information

- [Pioneer](https://github.com/d-exclaimation/pioneer)
- [Pioneer's PubSub](https://pioneer-graphql.netlify.app/guides/advanced/subscriptions/#pubsub-as-protocol)
- [RediStack](https://gitlab.com/Mordil/RediStack/)
