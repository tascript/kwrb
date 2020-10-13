# kwrb   [![Build Status](https://travis-ci.org/wataru-script/kwrb.svg?branch=master)](https://travis-ci.org/wataru-script/kwrb)
Kwrb class
## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'wataru-script/kwrb'
end
```
## example
```ruby
p Kwrb.hi
#=> "hi!!"
t = Kwrb.new "hello"
p t.hello
#=> "hello"
p t.bye
#=> "hello bye"
```

## License
under the MIT License:
- see LICENSE file
