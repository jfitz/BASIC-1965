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

  def posate_1(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    (1..n_cols).each do |col|
      value = source.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = posate(value)
    end
    values
  end

  def posate_2(source)
    n_rows = source.dimensions[0].to_i
    n_cols = source.dimensions[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = source.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = posate(value)
      end
    end
    values
  end

  def negate_1(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    (1..n_cols).each do |col|
      value = source.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = negate(value)
    end
    values
  end

  def negate_2(source)
    n_rows = source.dimensions[0].to_i
    n_cols = source.dimensions[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = source.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = negate(value)
      end
    end
    values
  end

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
    values = posate_1(a) if dims.size == 1
    values = posate_2(a) if dims.size == 2
    Matrix.new(dims, values)
  end

  def negate_matrix(a)
    dims = a.dimensions
    values = negate_1(a) if dims.size == 1
    values = negate_2(a) if dims.size == 2
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
    if x.matrix? && y.matrix?
      case @op
      when '+'
        add_matrix_matrix(x, y)
      when '-'
        subtract_matrix_matrix(x, y)
      when '*'
        multiply_matrix_matrix(x, y)
      when '/'
        divide_matrix_matrix(x, y)
      when '^'
        power_matrix_matrix(x, y)
      end
    elsif x.matrix?
      case @op
      when '+'
        add_matrix_scalar(x, y)
      when '-'
        subtract_matrix_scalar(x, y)
      when '*'
        multiply_matrix_scalar(x, y)
      when '/'
        divide_matrix_scalar(x, y)
      when '^'
        power_matrix_scalar(x, y)
      end
    elsif y.matrix?
      case @op
      when '+'
        add_scalar_matrix(x, y)
      when '-'
        subtract_scalar_matrix(x, y)
      when '*'
        multiply_scalar_matrix(x, y)
      when '/'
        divide_scalar_matrix(x, y)
      when '^'
        power_scalar_matrix(x, y)
      end
    else
      case @op
      when '+'
        x + y
      when '-'
        x - y
      when '*'
        x * y
      when '/'
        x / y
      when '^'
        x ** y
      end
    end
  end

  def to_s
    @op
  end

  private

  def add_scalar_matrix_1(a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a + b_value
    end
    values
  end

  def add_scalar_matrix_2(a, b)
    dims = b.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a + b_value
      end
    end
    values
  end

  def add_scalar_matrix(a, b)
    dims = b.dimensions
    values = add_scalar_matrix_1(a, b) if dims.size == 1
    values = add_scalar_matrix_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def subtract_scalar_matrix_1(a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a - b_value
    end
    values
  end

  def subtract_scalar_matrix_2(a, b)
    dims = b.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a - b_value
      end
    end
    values
  end

  def subtract_scalar_matrix(a, b)
    dims = b.dimensions
    values = subtract_scalar_matrix_1(a, b) if dims.size == 1
    values = subtract_scalar_matrix_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def multiply_scalar_matrix_1(a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a * b_value
    end
    values
  end

  def multiply_scalar_matrix_2(a, b)
    dims = b.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a * b_value
      end
    end
    values
  end

  def multiply_scalar_matrix(a, b)
    dims = b.dimensions
    values = multiply_scalar_matrix_1(a, b) if dims.size == 1
    values = multiply_scalar_matrix_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def divide_scalar_matrix_1(a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a / b_value
    end
    values
  end

  def divide_scalar_matrix_2(a, b)
    dims = b.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a / b_value
      end
    end
    values
  end

  def divide_scalar_matrix(a, b)
    dims = b.dimensions
    values = divide_scalar_matrix_1(a, b) if dims.size == 1
    values = divide_scalar_matrix_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def power_scalar_matrix_1(a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a ** b_value
    end
    values
  end

  def power_scalar_matrix_2(a, b)
    dims = b.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a ** b_value
      end
    end
    values
  end

  def power_scalar_matrix(a, b)
    dims = b.dimensions
    values = power_scalar_matrix_1(a, b) if dims.size == 1
    values = power_scalar_matrix_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def add_matrix_scalar_1(a, b)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a_value + b
    end
    values
  end

  def add_matrix_scalar_2(a, b)
    dims = a.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value + b
      end
    end
    values
  end

  def add_matrix_scalar(a, b)
    dims = a.dimensions
    values = add_matrix_scalar_1(a, b) if dims.size == 1
    values = add_matrix_scalar_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def subtract_matrix_scalar_1(a, b)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a_value - b
    end
    values
  end

  def subtract_matrix_scalar_2(a, b)
    dims = a.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value - b
      end
    end
    values
  end

  def subtract_matrix_scalar(a, b)
    dims = a.dimensions
    values = subtract_matrix_scalar_1(a, b) if dims.size == 1
    values = subtract_matrix_scalar_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def multiply_matrix_scalar_1(a, b)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a_value * b
    end
    values
  end

  def multiply_matrix_scalar_2(a, b)
    dims = a.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value * b
      end
    end
    values
  end

  def multiply_matrix_scalar(a, b)
    dims = a.dimensions
    values = multiply_matrix_scalar_1(a, b) if dims.size == 1
    values = multiply_matrix_scalar_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def divide_matrix_scalar_1(a, b)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a_value / b
    end
    values
  end

  def divide_matrix_scalar_2(a, b)
    dims = a.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value / b
      end
    end
    values
  end

  def divide_matrix_scalar(a, b)
    dims = a.dimensions
    values = divide_matrix_scalar_1(a, b) if dims.size == 1
    values = divide_matrix_scalar_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def power_matrix_scalar_1(a, b)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a_value ** b
    end
    values
  end

  def power_matrix_scalar_2(a, b)
    dims = a.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value ** b
      end
    end
    values
  end

  def power_matrix_scalar(a, b)
    dims = a.dimensions
    values = power_matrix_scalar_1(a, b) if dims.size == 1
    values = power_matrix_scalar_2(a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def add_matrix_matrix_1(a, b)
    a_dims = a.dimensions
    n_cols = a_dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      coords = '(' + col.to_s + ')'
      values[coords] = a_value + b_value
    end
    values
  end

  def add_matrix_matrix_2(a, b)
    a_dims = a.dimensions
    n_rows = a_dims[0].to_i
    n_cols = a_dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value + b_value
      end
    end
    values
  end

  def add_matrix_matrix(a, b)
    # verify dimensions match
    a_dims = a.dimensions
    b_dims = b.dimensions
    fail(BASICException, 'Matrix dimensions do not match') if a_dims != b_dims
    values = add_matrix_matrix_1(a, b) if a_dims.size == 1
    values = add_matrix_matrix_2(a, b) if a_dims.size == 2
    Matrix.new(a_dims, values)
  end

  def subtract_matrix_matrix_1(a, b)
    a_dims = a.dimensions
    n_cols = a_dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      b_value = b.get_value_1(col)
      coords = '(' + col.to_s + ')'
      values[coords] = a_value - b_value
    end
    values
  end

  def subtract_matrix_matrix_2(a, b)
    a_dims = a.dimensions
    n_rows = a_dims[0].to_i
    n_cols = a_dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        b_value = b.get_value_2(row, col)
        coords = '(' + row.to_s + ',' + col.to_s + ')'
        values[coords] = a_value - b_value
      end
    end
    values
  end

  def subtract_matrix_matrix(a, b)
    # verify dimensions match
    a_dims = a.dimensions
    b_dims = b.dimensions
    fail(BASICException, 'Matrix dimensions do not match') if a_dims != b_dims
    values = subtract_matrix_matrix_1(a, b) if a_dims.size == 1
    values = subtract_matrix_matrix_2(a, b) if a_dims.size == 2
    Matrix.new(a_dims, values)
  end

  def multiply_matrix_matrix_w(a, b, r_dims)
    r_rows = r_dims[0].to_i
    r_cols = r_dims[1].to_i
    a_dims = a.dimensions
    a_rows = a_dims[0].to_i
    a_cols = a_dims[1].to_i
    values = {}
    (1..r_rows).each do |r_row|
      (1..r_cols).each do |r_col|
        f = 0
        (1..a_cols).each do |a_col|
          a_value = a.get_value_2(r_row, a_col)
          b_value = b.get_value_2(a_col, r_col)
          f += a_value.to_f * b_value.to_f
        end
        f2 = float_to_possible_int(f)
        coords = '(' + r_row.to_s + ',' + r_col.to_s + ')'
        values[coords] = NumericConstant.new(f2)
      end
    end
    values
  end

  def multiply_matrix_matrix(a, b)
    # verify dimensions are acceptable
    a_dims = a.dimensions
    b_dims = b.dimensions
    fail(BASICException, 'Matrix multiplication must have two matrices') if
      a_dims.size != 2 || b_dims.size != 2
    # number of columns in a must match number of rows in b
    fail(BASICException, 'Matrix dimensions do not match') if
      a_dims[1] != b_dims[0]
    # result has number of rows in a and number of columns in b
    r_dims = [a_dims[0], b_dims[1]]
    values = multiply_matrix_matrix_w(a, b, r_dims)
    Matrix.new(r_dims, values)
  end

  def divide_matrix_matrix(a, b)
    fail BASICException, 'Cannot divide matrix by matrix'
  end

  def power_matrix_matrix(a, b)
    fail BASICException, 'Cannot raise matrix to matrix power'
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
