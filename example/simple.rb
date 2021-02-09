s = Kwrb::Client.connect('localhost')
s.publish('a/b', 'Hello')
