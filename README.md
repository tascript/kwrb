# kwrb
kwrb is MQTT client for mruby.

## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'wataru-script/kwrb'
end
```

## Usage

```ruby
s = Kwrb::Client.connect('host')
s.publish('a/b', 'Hello')
s.disconnect
```
