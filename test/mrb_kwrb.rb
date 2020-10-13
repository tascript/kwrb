##
## Kwrb Test
##

assert("Kwrb#hello") do
  t = Kwrb.new "hello"
  assert_equal("hello", t.hello)
end

assert("Kwrb#bye") do
  t = Kwrb.new "hello"
  assert_equal("hello bye", t.bye)
end

assert("Kwrb.hi") do
  assert_equal("hi!!", Kwrb.hi)
end
