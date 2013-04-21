#!/usr/bin/ruby

class Node
  def initialize(token)
    @token = token
    @precedence = 0
    @left = nil
    @right = nil
    @parent = nil
  end
  
  def token
    @token
  end
  
  def precedence
    @precedence
  end

  def set_left(node)
    @left = node
  end
  
  def left
    @left
  end
  
  def set_right(node)
    @right = node
  end
  
  def right
    @right
  end
  
  def parent
    @parent
  end
  
  def set_parent(node)
    @parent = node
  end
end

class NumericConstant < Node
  def initialize(text)
    super
    case
#    when text.class.to_s == 'NumericConstant': @value = text.value
    when text.class.to_s == 'Fixnum': @value = text
    when text =~ /^[+-]?\d+$/: @value = text.to_i
    when text =~ /^[+-]?\d+\.\d*$/: @value = text.to_f
    else raise "'#{text}' is not a number" 
    end
  end

  def value
    @value
  end
  
  def numeric_value
    @value
  end

  def to_s
    @value.to_s
  end
  
  def to_formatted_s
    if @value < 0 then
      @value.to_s
    else
      ' ' + @value.to_s
    end
  end

  def <(rhs)
    @value < rhs.numeric_value
  end
end

class Operator < Node
  @@operators = { '+' => 1, '-' => 1, '*' => 2, '/' => 2 }
  
  def initialize(text)
    super
    raise "'#{text}' is not an operator" if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
    @left = NumericConstant.new(0)
    @right = NumericConstant.new(0)
  end
  
  def evaluate(a, b)
    case
    when @op == '+': NumericConstant.new(a.value + b.value)
    when @op == '-': NumericConstant.new(a.value - b.value)
    when @op == '*': NumericConstant.new(a.value * b.value)
    when @op == '/': NumericConstant.new(a.value / b.value)
    end
  end
  
  def to_s
    @op
  end
end

def infix_string(current_node)
  result = ''
  if current_node.left != nil then
    result += '( ' if current_node.precedence < current_node.left.precedence
    result += infix_string(current_node.left).to_s + ' '
    result += ') ' if current_node.precedence < current_node.left.precedence
  end
  result += current_node.token.to_s
  if current_node.right then
    result += ' (' if current_node.precedence < current_node.right.precedence
    result += ' ' + infix_string(current_node.right).to_s
    result += ' )' if current_node.precedence < current_node.right.precedence
  end
  result
end

def postfix_string(current_node)
  result = ''
  result += postfix_string(current_node.left) + ' ' if current_node.left != nil
  result += postfix_string(current_node.right) + ' ' if current_node.right != nil
  result += current_node.token.to_s

  result
end

def evaluate(current_node)
  result = case
    when current_node.class.to_s == 'Operator':
      a = evaluate(current_node.left)
      b = evaluate(current_node.right)
      current_node.evaluate(a, b)
    when current_node.class.to_s == 'NumericConstant': current_node
    else NumericConstant.new(0)
  end
end

list = Array.new
# read cmd line arguments
ARGV.each do | item |
  items = item.split /\s+/
  items.each do | it |
    begin
      list << NumericConstant.new(it)
    rescue
      begin
        list << Operator.new(it)
      rescue
        raise "'#{it}' is not a value or operator" if it != '(' && it != ')'
      end
    end
  end
end

# verify list is valid
level = 0

list.each do | token |
  case
  when token.class.to_s == 'NumericConstant': level += 1
  when token.class.to_s == 'Operator': level -= 1
  when token == '(': level += 1
  when token == ')': level -= 1
  end
end

level -= 1 if list.size > 0

if level == 0 then
  puts 'LIST OK'
else
  puts "LIST ' #{list.join('-')} ' ERROR"
end

root_node = Node.new('root')
current_node = root_node
stack = Array.new

list.each do | token |
  case
  when token.class.to_s == 'NumericConstant':
    child = token
    current_node.set_right(child)
    child.set_parent(current_node)
  when token.class.to_s == 'Operator':
    op = token
    if op.precedence < current_node.precedence then
      op.set_left(current_node)
      op.set_parent(current_node.parent)
    else
      op.set_left(current_node.right)
      op.set_parent(current_node)
    end
    op.parent.set_right(op)
    op.left.set_parent(op)
    current_node = op
  when token == '(':
    stack << current_node.clone
    current_node = Node.new(token)
  when token == ')':
    new_tree = current_node.clone
    current_node = stack.pop
    current_node.set_right(new_tree)
    new_tree.set_parent(current_node)
  end
end
current_node = root_node.right

# print tree infix
puts 'INFIX: ' + infix_string(current_node)

# print tree postfix
puts 'POSTFIX: ' + postfix_string(current_node)

puts "VALUE: #{evaluate(current_node)}"

puts 'All done!'

