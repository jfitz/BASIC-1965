def float_to_possible_int(f)
  i = f.to_i
  (f - i).abs < 1e-8 ? i : f
end

class UnaryOperator
  attr_reader :precedence

  def initialize(text)
    operators = { '+' => 5, '-' => 5 }
    fail(BASICException, "'#{text}' is not an operator") unless operators.key?(text)
    @op = text
    @precedence = operators[@op]
  end

  def operator?
    true
  end

  def function?
    false
  end

  def variable?
    false
  end

  def terminal?
    false
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

class BinaryOperator
  attr_reader :precedence

  def initialize(text)
    operators = { '+' => 2, '-' => 2, '*' => 3, '/' => 3, '^' => 4 }
    fail(BASICException, "'#{text}' is not an operator") unless operators.key?(text)
    @op = text
    @precedence = operators[@op]
  end

  def operator?
    true
  end

  def function?
    false
  end

  def variable?
    false
  end

  def terminal?
    false
  end

  def evaluate(_, stack)
    y = stack.pop
    x = stack.pop
    case @op
    when '+'
      z = add(x, y)
    when '-'
      z = subtract(x, y)
    when '*'
      z = multiply(x, y)
    when '/'
      z = divide(x, y)
    when '^'
      z = power(x, y)
    end
    NumericConstant.new(z)
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

class BooleanOperator
  attr_reader :precedence

  def initialize(text)
    valid_operators = ['=', '<', '>', '>=', '<=', '<>']
    fail(BASICException, "'#{text}' is not a valid boolean operator") unless valid_operators.include?(text)
    @value = text
    @precedence = 1
  end

  def operator?
    true
  end

  def function?
    false
  end

  def variable?
    false
  end

  def terminal?
    false
  end

  def to_s
    @value
  end
end

class TerminalOperator
  def operator?
    true
  end

  def function?
    false
  end

  def terminal?
    true
  end

  def variable?
    false
  end

  def precedence
    0
  end

  def to_s
    'TERM'
  end
end
