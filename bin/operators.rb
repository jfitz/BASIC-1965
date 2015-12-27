def float_to_possible_int(f)
  i = f.to_i
  (f - i).abs < 1e-8 ? i : f
end

# Unary scalar operators
class UnaryOperator < AbstractToken
  def self.init?(text)
    operators = { '+' => 5, '-' => 5 }
    operators.key?(text)
  end

  attr_reader :precedence

  def initialize(text)
    operators = { '+' => 5, '-' => 5 }
    fail(BASICException, "'#{text}' is not an operator") unless
      operators.key?(text)
    @op = text
    @precedence = operators[@op]
    @operator = true
  end

  def evaluate(_, stack)
    x = stack.pop
    case @op
    when '+'
      z = posate(x)
    when '-'
      z = negate(x)
    end
    NumericConstant.new(z)
  end

  def posate(a)
    f = a.to_f
    float_to_possible_int(f)
  end

  def negate(a)
    f = -a.to_f
    float_to_possible_int(f)
  end

  def to_s
    @op
  end
end

def make_boolean_operator(text)
  if text == '='
    BooleanOperatorEq.new
  elsif text == '<>'
    BooleanOperatorNotEq.new
  elsif text == '>'
    BooleanOperatorGreater.new
  elsif text == '>='
    BooleanOperatorGreaterEq.new
  elsif text == '<'
    BooleanOperatorLess.new
  elsif text == '<='
    BooleanOperatorLessEq.new
  else
    fail(BASICException, "'#{text}' is not an operator") unless
      operators.key?(text)
  end
end

# Binary scalar operators
class BinaryOperator < AbstractToken
  def self.init?(text)
    operators = { '+' => 2, '-' => 2, '*' => 3, '/' => 3, '^' => 4 }
    operators.key?(text)
  end

  attr_reader :precedence

  def initialize(text)
    operators = { '+' => 2, '-' => 2, '*' => 3, '/' => 3, '^' => 4 }
    fail(BASICException, "'#{text}' is not an operator") unless
      operators.key?(text)
    @op = text
    @precedence = operators[@op]
    @operator = true
  end

  def evaluate(_, stack)
    y = stack.pop
    x = stack.pop
    case @op
    when '+'
      NumericConstant.new(add(x, y))
    when '-'
      NumericConstant.new(subtract(x, y))
    when '*'
      NumericConstant.new(multiply(x, y))
    when '/'
      NumericConstant.new(divide(x, y))
    when '^'
      NumericConstant.new(power(x, y))
    end
  end

  def add(a, b)
    f = a.to_f + b.to_f
    float_to_possible_int(f)
  end

  def subtract(a, b)
    f = a.to_f - b.to_f
    float_to_possible_int(f)
  end

  def multiply(a, b)
    f = a.to_f * b.to_f
    float_to_possible_int(f)
  end

  def divide(a, b)
    fail(BASICException, 'Division by zero') if b.to_f == 0
    f = a.to_f / b.to_f
    float_to_possible_int(f)
  end

  def power(a, b)
    f = a.to_f**b.to_f
    float_to_possible_int(f)
  end

  def to_s
    @op
  end
end

# Boolean operator - equal
class BooleanOperatorEq
  def evaluate(av, bv)
    av == bv
  end

  def to_s
    '='
  end
end

# Boolean operator - not equal
class BooleanOperatorNotEq
  def evaluate(av, bv)
    av != bv
  end

  def to_s
    '<>'
  end
end

# Boolean operator - greater than
class BooleanOperatorGreater
  def evaluate(av, bv)
    av > bv
  end

  def to_s
    '>'
  end
end

# Boolean operator - greater or equal
class BooleanOperatorGreaterEq
  def evaluate(av, bv)
    av >= bv
  end

  def to_s
    '>='
  end
end

# Boolean operator - less than
class BooleanOperatorLess
  def evaluate(av, bv)
    av < bv
  end

  def to_s
    '<'
  end
end

# Boolean operator - less or equal
class BooleanOperatorLessEq
  def evaluate(av, bv)
    av <= bv
  end

  def to_s
    '<='
  end
end

# Terminal operator
# not a real operator, used only for parsing
class TerminalOperator < AbstractToken
  def initialize
    @operator = true
    @terminal = true
  end

  def precedence
    0
  end

  def to_s
    'TERM'
  end
end
