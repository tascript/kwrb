# publish

s = Kwrb::Client.connect(host: 'host', username: 'username', password: 'password')
s.publish(topic: 'a/b', message: 'Hello')
s.disconnect

# subscribe

s = Kwrb::Client.connect(host: 'host', username: 'username', password: 'password')
s.subscribe(topic: 'a/b')
