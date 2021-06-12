# kwrb
kwrb is MQTT client for mruby.

## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'tascript/kwrb', :branch => 'main'
end
```

## environment

mruby 2.1.2(recommendation)

## usage

usage of kwrb is simple.

**connect**

```ruby
s = Kwrb::Client.connect(host: 'host')
```

**disconnect**

```ruby
s = Kwrb::Client.connect(host: 'host')
s.disconnect
```

**publish**

```ruby
s = Kwrb::Client.connect(host: 'host')
s.publish(topic: 'a/b', message: 'hello')
```

**subscribe**

```ruby
s = Kwrb::Client.connect(host: 'host')
s.subscribe(topic: 'a/b')
```

## license
under the  License:
- see LICENSE file
