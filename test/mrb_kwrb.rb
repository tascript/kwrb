assert('Queue#enqueue, Queue#dequeue') do
  q = Queue.new
  q.enqueue('hi')
  q.enqueue('hello')
  q.enqueue('bye')
  assert_equal('hi', q.dequeue)
  assert_equal('hello', q.dequeue)
  assert_equal('bye', q.dequeue)
end

assert('Queue#get') do
  q = Queue.new
  q.enqueue('hello')
  assert_equal(['hello'], q.get)
end
