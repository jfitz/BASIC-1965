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
    if x.matrix?
      case @op
      when '+'
        posate_matrix(x)
      when '-'
        negate_matrix(x)
      end
    else
      case @op
      when '+'
        posate(x)
      when '-'
        negate(x)
      end
    end
  end

  def to_s
    @op
  end

  private

  def posate(a)
    f = a.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
  end

  def negate(a)
    f = -a.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
  end

  def posate_matrix(a)
    dims = a.dimensions
    values = {}
    if dims.size == 1
      n_cols = dims[0]
      (1..n_cols).each do |col|
        coords = '(' + col.to_s + ')'
        value = a.get_value_1(col)
        values[coords] = posate(value)
      end
    end
    if dims.size == 2
      n_rows = dims[0].to_i
      n_cols = dims[1].to_i
      (1..n_rows).each do |row|
        (1..n_cols).each do |col|
          coords = '(' + row.to_s + ',' + col.to_s + ')'
          value = a.get_value_2(row, col)
          values[coords] = posate(value)
        end
      end
    end
    Matrix.new(dims, values)
  end

  def negate_matrix(a)
    dims = a.dimensions
    values = {}
    if dims.size == 1
      n_cols = dims[0]
      (1..n_cols).each do |col|
        coords = '(' + col.to_s + ')'
        value = a.get_value_1(col)
        values[coords] = negate(value)
      end
    end
    if dims.size == 2
      n_rows = dims[0].to_i
      n_cols = dims[1].to_i
      (1..n_rows).each do |row|
        (1..n_cols).each do |col|
          coords = '(' + row.to_s + ',' + col.to_s + ')'
          value = a.get_value_2(row, col)
          values[coords] = negate(value)
        end
      end
    end
    Matrix.new(dims, values)
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
      add(x, y)
    when '-'
      subtract(x, y)
    when '*'
      multiply(x, y)
    when '/'
      divide(x, y)
    when '^'
      power(x, y)
    end
  end

  def to_s
    @op
  end

  private

  def add(a, b)
    f = a.to_f + b.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
  end

  def subtract(a, b)
    f = a.to_f - b.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
  end

  def multiply(a, b)
    f = a.to_f * b.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
  end

  def divide(a, b)
    fail(BASICException, 'Division by zero') if b.to_f == 0
    f = a.to_f / b.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
  end

  def power(a, b)
    f = a.to_f**b.to_f
    f2 = float_to_possible_int(f)
    NumericConstant.new(f2)
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

# Initial operator
# not a real operator, used only for parsing
class InitialOperator < AbstractToken
  def initialize
    @operator = true
    @terminal = true
  end

  def precedence
    0
  end

  def to_s
    'INIT'
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
