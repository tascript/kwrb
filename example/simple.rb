# publish

s = Kwrb::Client.connect(host: 'host', username: 'username', password: 'password')
s.publish('a/b', 'Hello')
s.disconnect

# subscribe

s = Kwrb::Client.connect(host: 'host', username: 'username', password: 'password')
s.subscribe('a/b')
