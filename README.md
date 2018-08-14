# fix

A FIX ( Financial Information eXchange ) library written in pure Crystal.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  fix_cr:
    github: NeuraLegion/fix
```

## Usage

```crystal
require "fix_cr"
```

Require `FIX`, create a `Session` object ,hook to its callbacks(`on_connect`, `on_logon`, `on_logout`, `on_error`, `from_admin`, `to_admin`, `from_app`, and `to_app`), connect to server with `connect` and then `loop`.

You can find examples in the `examples/` folder

## Development

TODO: Repeating groups decoding
TODO: Encryption
TODO: Server side

## Contributing

1. Fork it (<https://github.com/sekkr1/fix/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [sekkr1](https://github.com/sekkr1) Dekel - creator, maintainer
