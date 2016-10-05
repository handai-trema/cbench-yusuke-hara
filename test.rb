require 'ruby-prof'

RubyProf.start

(1..10000).each do |i|
  case 0
  when i % 15
    print :FizzBuzz
  when i % 3
    print :Fizz
  when i % 5
    print :Buzz
  else
    print i
  end
end
result = RubyProf.stop
RubyProf::FlatPrinter.new(result).print(STDOUT)

