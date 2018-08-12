# fix_cr

A FIX ( Financial Information eXchange ) library written in pure Crystal.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  fix_cr:
    github: NeuraLegion/fix_cr
```

## Usage

```crystal
require "fix_cr"
```

Implement `FIXApplication`, create a `FIXSession` object with it and start the loop

Example:
1. Run [PyFIX](<https://github.com/wannabegeek/PyFIX>) server_example.py
2. Run examples/simple_client.cr

## Development

TODO: Add all message type and blocks structures

## Contributing

1. Fork it (<https://github.com/sekkr1/fix_cr/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [sekkr1](https://github.com/sekkr1) Dekel - creator, maintainer
