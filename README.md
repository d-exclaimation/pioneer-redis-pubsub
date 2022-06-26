# PioneerRedisPubSub

This package implements the PubSub protocol from the [Pioneer](https://github.com/d-exclaimation/pioneer) package. It allows you to use a Redis-backed PubSub woth similar interface with the [AsyncPubSub](https://pioneer-graphql.netlify.app/guides/advanced/subscriptions/#asyncpubsub) and use it for your subscription resolvers.

## Setup

```swift
.package(url: "https://github.com/d-exclaimation/pioneer-redis-pubsub", from: "0.8.2")
```

## Usage

Define your GraphQL schema with a Subscription type:

```swift
let schema = try Schema<Resolver, Context> {
    Query { ... }
    Mutation { ... }
    Subscription {
        SubscriptionField("somethingChanged", as: Message.self, atSub: Resolver.somethingChanged)
    }
}
```
Now, let's create a RedisPubSub instance from the `app.redis`:

```
import struct PioneerRedisPubSub.RedisPubSub

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
> Subscription resolver must a return an instance of the type EventStream from the [GraphQLSwift/GraphQL](https://github.com/GraphQLSwift/GraphQL). Here, we are using [Pioneer](https://github.com/d-exclaimation/pioneer)'s [AsyncEventStream](https://pioneer-graphql.netlify.app/features/async-event-stream/) that can be built from any AsyncSequence (e.g. AsyncStream and AsyncThrowingStream)

Calling the method `asyncStream` of the RedisPubSub instance will send redis a `SUBSCRIBE` message to the topic provided if have not previously subscribed. RedisPubSub manages internally a collection of subscribers (using Actors) which can be individually unsubscribe without having to close all other subcriber of the same topic. Every time the `publish` method is called, RedisPubSub will `PUBLISH` the event over redis which will be picked up by the RedisPubSub if there exist subscriber(s) for that topic.

```swift
await pubsub.publish(for: SOMETHING_CHANGED_TOPIC, payload: Message(id: "123"))
```

### More information

- [Pioneer](https://github.com/d-exclaimation/pioneer)
- [Pioneer's PubSub](https://pioneer-graphql.netlify.app/guides/advanced/subscriptions/#pubsub-as-protocol)
- [RediStack](https://gitlab.com/Mordil/RediStack/)
