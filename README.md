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
require "fix"
```

Create a `Session` object, hook to its callbacks(`on_connect`, `on_logon`, `on_logout`, `on_error`, `from_admin`, `to_admin`, `from_app`, and `to_app`), connect to server with `connect` and then `loop`.

You can find the below example in the `examples/` folder

```crystal
sess = FIX::Session.new

sess.on_connect do
  puts "CONNECTED"
end

sess.on_logon do
  puts "LOGGED ON"
  spawn do
    cl0rdid = Random.rand(1000..2000)
    loop do
      msg = FIX::Message.new FIX::MESSAGE_TYPES[:NewOrderSingle]
      msg.set_field FIX::TAGS[:Price], "%0.2f" % Random.rand(10.0..13.0).to_s
      msg.set_field FIX::TAGS[:OrderQty], Random.rand(100).to_s
      msg.set_field FIX::TAGS[:Symbol], "VOD.L"
      msg.set_field FIX::TAGS[:SecurityID], "GB00BH4HKS39"
      msg.set_field FIX::TAGS[:SecurityIDSource], "4"
      msg.set_field FIX::TAGS[:Account], "TEST"
      msg.set_field FIX::TAGS[:HandlInst], "1"
      msg.set_field FIX::TAGS[:ExDestination], "XLON"
      msg.set_field FIX::TAGS[:Side], Random.rand(1..2).to_s
      msg.set_field FIX::TAGS[:ClOrdID], cl0rdid.to_s
      cl0rdid += 1
      msg.set_field FIX::TAGS[:Currency], "GBP"
      sess.send_msg msg
      sleep 8.seconds
    end
  end
end

sess.on_logout do
  puts "DISCONNECTED"
end

sess.to_admin do |msg|
  puts "ADMIN ---->: #{msg.data}"
end

sess.to_app do |msg|
  puts "APP ---->: #{msg.data}"
end

sess.from_admin do |msg|
  puts "ADMIN <----: #{msg.data}"
end

sess.from_app do |msg|
  puts "APP <----: #{msg.data}"
end

sess.on_error do |err|
  puts "ERROR: #{err}"
end

sess.connect "localhost", 9898
sess.loop
```

## Development

* [ ] Repeating groups decoding  
* [ ] Encryption  
* [ ] Server side  

## Contributing

1. Fork it (<https://github.com/NeuraLegion/fix/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [sekkr1](https://github.com/sekkr1) Dekel - creator, maintainer
