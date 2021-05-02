assert('Queue#enqueue, Queue#dequeue') do
  q = Queue.new
  q.enqueue('hello')
  assert_equal('hello', q.dequeue)
end

assert('Queue#value') do
  q = Queue.new
  q.enqueue('hello')
  assert_equal(['hello'], q.value)
end
