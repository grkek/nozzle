# Nozzle

Broadcast PostgreSQL database events to Redis channel subscribers.

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     nozzle:
       github: grkek/nozzle
   ```

2. Run `shards install`

## Usage

```crystal
require "nozzle"

app = Nozzle::Application.new(
  database_url: "DATABASE_URL",
  database_channel: "DATABASE_CHANNEL",
  handlers: [Nozzle::Handlers::Redis.new(url: "REDIS_URL")] of Nozzle::Handlers::Base
)

app.run
```

This can be run in the background using `spawn do` or `spawn {}`.

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/grkek/nozzle/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Giorgi Kavrelishvili](https://github.com/grkek) - creator and maintainer
