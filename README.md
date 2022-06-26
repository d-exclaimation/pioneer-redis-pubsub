# PioneerRedisPubSub

This package implements the PubSub protocol from the [Pioneer](https://github.com/d-exclaimation/pioneer) package. It allows you to use a Redis-backed PubSub woth similar interface with the [AsyncPubSub](https://pioneer-graphql.netlify.app/guides/advanced/subscriptions/#asyncpubsub) and use it for your subscription resolvers.

## Setup

```swift
.package(url: "https://github.com/d-exclaimation/pioneer-redis-pubsub", from: "0.1.0")
```

## Usage

Create a RedisPubSub instance (Here is an example using [Vapor's Redis integration](https://docs.vapor.codes/redis/overview/)):

```swift
import Vapor
import struct PioneerRedisPubSub.RedisPubSub
import Redis

let app = try Application(.detect())

app.redis.configuration = try RedisConfiguration(hostname: "localhost")

struct Resolver {
    let pubsub: PubSub = RedisPubSub(app.redis)
}
```

Now, implement your subscription resolver function, using the `pubsub.asyncIterator` to map the event you need:

```swift
let SOMETHING_CHANGED_TOPIC = "something_changed"

extension Resolver {
    func somethingChanged(_: Context, _: NoArguments) -> EventStream<Message> {
        pubsub.asyncStream(Message.self, for: SOMETHING_CHANGED_TOPIC).toEventStream()
    }
}
```

Calling the method `asyncStream` of the RedisPubSub instance will send redis a `SUBSCRIBE` message to the topic provided if have not previously subscribed.

RedisPubSub manages internally a collection of subscribers (using Actors) which can be individually unsubscribe without having to close all other subcriber of the same topic. Every time the `publish` method is called, RedisPubSub will `PUBLISH` the event over redis which will be picked up by the RedisPubSub if there exist subscriber(s) for that topic.

Now, call `publish` method whenever you want to push an event to the subscriber(s).

```swift
await pubsub.publish(for: SOMETHING_CHANGED_TOPIC, payload: Message(id: "123"))
```

### More information

- [Pioneer](https://github.com/d-exclaimation/pioneer)
- [Pioneer's PubSub](https://pioneer-graphql.netlify.app/guides/advanced/subscriptions/#pubsub-as-protocol)
- [RediStack](https://gitlab.com/Mordil/RediStack/)
