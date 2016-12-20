#Rebar-friendly fork of Rabbit common

This is a fork of the rabbit_common dependency, which is needed by the official [RabbitMQ/AMQP Erlang client][1].

It's meant to be included in your rebar projects in your rebar.config file:

```Erlang
{deps, [
  {rabbit_common, ".*", {git, "git://github.com/qingchuwudi/rabbit_common.git", {tag, "v3_7_0_milestone8"}}}
]}.
```

The "rebar2" branch of this port is a simple re-packaging of the rabbit_common AMQP client dependency, which can be compiled with [rebar2][3] but not [rebar3][4]. And it corresponding to [rabbitmq-common][2] version **rabbitmq_v3_7_0_milestone8**.

License

This package, just like the the RabbitMQ server, is licensed under the MPL. For the MPL, please see LICENSE-MPL-RabbitMQ.


[1]: https://github.com/rabbitmq/rabbitmq-erlang-client
[2]: https://github.com/rabbitmq/rabbitmq-common
[3]: https://github.com/rebar/rebar.git
[4]: https://github.com/erlang/rebar3.git
