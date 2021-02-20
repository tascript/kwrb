s = Kwrb::Client.connect('host')
s.publish('a/b', 'Hello')
s.disconnect
