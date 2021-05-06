# publish

s = Kwrb::Client.connect('host')
s.publish('a/b', 'Hello')
s.disconnect

# subscribe

s = Kwrb::Client.connect('host')
s.subscribe('a/b')
