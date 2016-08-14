# Unary scalar operators
class UnaryOperator < AbstractElement
  def self.accept?(token)
    classes = %w(OperatorToken)
    classes.include?(token.class.to_s)
  end

  def initialize(text)
    super()
    @op = text.to_s
    operators = { '+' => 5, '-' => 5 }
    raise(BASICException, "'#{text}' is not an operator") unless
      operators.key?(@op)
    @precedence = operators[@op]
    @operator = true
  end

  def evaluate(_, stack)
    raise(BASICException, 'Not enough operands') if stack.empty?
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
      coords = make_coord(col)
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
        coords = make_coords(row, col)
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
      coords = make_coord(col)
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
        coords = make_coords(row, col)
        values[coords] = negate(value)
      end
    end
    values
  end

  def posate(a)
    f = a.to_f
    NumericConstant.new(f)
  end

  def negate(a)
    f = -a.to_f
    NumericConstant.new(f)
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
class BinaryOperator < AbstractElement
  def self.accept?(token)
    classes = %w(OperatorToken)
    classes.include?(token.class.to_s)
  end

  def initialize(text)
    super()
    @op = text.to_s
    operators = {
      '=' => 2, '<>' => 2, '>' => 2, '>=' => 2, '<' => 2, '<=' => 2,
      '+' => 3, '-' => 3, '*' => 4, '/' => 4, '^' => 5
    }
    raise(BASICException, "'#{text}' is not an operator") unless
      operators.key?(@op)
    @precedence = operators[@op]
    @operator = true
  end

  def evaluate(_, stack)
    raise(BASICException, 'Not enough operands') if stack.size < 2
    y = stack.pop
    x = stack.pop
    if x.matrix? && y.matrix?
      matrix_matrix(x, y)
    elsif x.matrix?
      matrix_scalar(x, y)
    elsif y.matrix?
      scalar_matrix(x, y)
    else
      op_scalar_scalar(x, y)
    end
  end

  def to_s
    @op
  end

  private

  def matrix_matrix(x, y)
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
    else
      raise BASICException, 'Invalid operation'
    end
  end

  def matrix_scalar(x, y)
    case @op
    when '+'
      op_matrix_scalar(:add, x, y)
    when '-'
      op_matrix_scalar(:subtract, x, y)
    when '*'
      op_matrix_scalar(:multiply, x, y)
    when '/'
      op_matrix_scalar(:divide, x, y)
    when '^'
      op_matrix_scalar(:power, x, y)
    else
      raise BASICException, 'Invalid operation'
    end
  end

  def scalar_matrix(x, y)
    case @op
    when '+'
      op_scalar_matrix(:add, x, y)
    when '-'
      op_scalar_matrix(:subtract, x, y)
    when '*'
      op_scalar_matrix(:multiply, x, y)
    when '/'
      op_scalar_matrix(:divide, x, y)
    when '^'
      op_scalar_matrix(:power, x, y)
    else
      raise BASICException, 'Invalid operation'
    end
  end

  def op_scalar_scalar(x, y)
    case @op
    when '+'
      x.add(y)
    when '-'
      x.subtract(y)
    when '*'
      x.multiply(y)
    when '/'
      x.divide(y)
    when '^'
      x.power(y)
    when '='
      x.b_eq(y)
    when '<>'
      x.b_ne(y)
    when '<'
      x.b_lt(y)
    when '<='
      x.b_le(y)
    when '>'
      x.b_gt(y)
    when '>='
      x.b_ge(y)
    end
  end

  def op_scalar_matrix_1(op, a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = make_coord(col)
      values[coords] = a.send(op, b_value)
    end
    values
  end

  def op_scalar_matrix_2(op, a, b)
    dims = b.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        b_value = b.get_value_2(row, col)
        coords = make_coords(row, col)
        values[coords] = a.send(op, b_value)
      end
    end
    values
  end

  def op_scalar_matrix(op, a, b)
    dims = b.dimensions
    values = op_scalar_matrix_1(op, a, b) if dims.size == 1
    values = op_scalar_matrix_2(op, a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def op_matrix_scalar_1(op, a, b)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_1(col)
      coords = make_coord(col)
      values[coords] = a_value.send(op, b)
    end
    values
  end

  def op_matrix_scalar_2(op, a, b)
    dims = a.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        a_value = a.get_value_2(row, col)
        coords = make_coords(row, col)
        values[coords] = a_value.send(op, b)
      end
    end
    values
  end

  def op_matrix_scalar(op, a, b)
    dims = a.dimensions
    values = op_matrix_scalar_1(op, a, b) if dims.size == 1
    values = op_matrix_scalar_2(op, a, b) if dims.size == 2
    Matrix.new(dims, values)
  end

  def add_matrix_matrix_1(a, b)
    a_dims = a.dimensions
    n_cols = a_dims[0].to_i
    values = {}
    (1..n_cols).each do |col|
      a_value = a.get_value_(col)
      b_value = b.get_value_(col)
      coords = make_coord(col)
      values[coords] = a_value.send(:add, b_value)
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
        coords = make_coords(row, col)
        values[coords] = a_value.send(:add, b_value)
      end
    end
    values
  end

  def add_matrix_matrix(a, b)
    # verify dimensions match
    a_dims = a.dimensions
    b_dims = b.dimensions
    raise(BASICException, 'Matrix dimensions do not match') if a_dims != b_dims
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
      coords = make_coord(col)
      values[coords] = a_value.send(:subtract, b_value)
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
        coords = make_coords(row, col)
        values[coords] = a_value.send(:subtract, b_value)
      end
    end
    values
  end

  def subtract_matrix_matrix(a, b)
    # verify dimensions match
    a_dims = a.dimensions
    b_dims = b.dimensions
    raise(BASICException, 'Matrix dimensions do not match') if a_dims != b_dims
    values = subtract_matrix_matrix_1(a, b) if a_dims.size == 1
    values = subtract_matrix_matrix_2(a, b) if a_dims.size == 2
    Matrix.new(a_dims, values)
  end

  def array_to_horizontal(a)
    a_dims = a.dimensions
    new_dims = [NumericConstant.new(1), a_dims[0]]
    n_cols = a_dims[0].to_i
    new_values = {}
    (1..n_cols).each do |col|
      value = a.get_value_1(col)
      coords = make_coords(1, col)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def horizontal_to_array(m)
    m_dims = m.dimensions
    new_dims = [m_dims[1]]
    new_values = {}
    n_cols = new_dims[0].to_i
    row = 1
    (1..n_cols).each do |col|
      value = m.get_value_2(row, col)
      coords = make_coord(col)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def array_to_vertical(a)
    a_dims = a.dimensions
    new_dims = [a_dims[0], NumericConstant.new(1)]
    n_cols = a_dims[0].to_i
    new_values = {}
    (1..n_cols).each do |col|
      value = a.get_value_1(col)
      coords = make_coords(col, 1)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def vertical_to_array(m)
    m_dims = m.dimensions
    new_dims = [m_dims[0]]
    new_values = {}
    n_rows = new_dims[0].to_i
    col = 1
    (1..n_rows).each do |row|
      value = m.get_value_2(row, col)
      coords = make_coord(row)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def multiply_matrix_matrix_value(a, b, r_row, r_col)
    a_dims = a.dimensions
    a_cols = a_dims[1].to_i
    f = 0
    (1..a_cols).each do |a_col|
      a_value = a.get_value_2(r_row, a_col)
      b_value = b.get_value_2(a_col, r_col)
      f += a_value.to_f * b_value.to_f
    end
    NumericConstant.new(f)
  end

  def multiply_matrix_matrix_work(a, b)
    r_dims = [a.dimensions[0], b.dimensions[1]]
    r_rows = r_dims[0].to_i
    r_cols = r_dims[1].to_i
    values = {}
    (1..r_rows).each do |r_row|
      (1..r_cols).each do |r_col|
        coords = make_coords(r_row, r_col)
        values[coords] = multiply_matrix_matrix_value(a, b, r_row, r_col)
      end
    end
    values
  end

  def multiply_matrix_matrix_2_2(a, b)
    a_dims = a.dimensions
    b_dims = b.dimensions
    # number of columns in a must match number of rows in b
    raise(BASICException, 'Matrix dimensions do not match') if
      a_dims[1] != b_dims[0]
    r_dims = [a_dims[0], b_dims[1]]
    values = multiply_matrix_matrix_work(a, b)
    Matrix.new(r_dims, values)
  end

  def multiply_matrix_matrix_2_1(a, b)
    a_dims = a.dimensions
    new_b = array_to_vertical(b)
    new_b_dims = new_b.dimensions
    # number of columns in a must match number of rows in b
    raise(BASICException, 'Matrix dimensions do not match') if
      a_dims[1] != new_b_dims[0]
    r_dims = [a_dims[0], new_b_dims[1]]
    values = multiply_matrix_matrix_work(a, new_b)
    m = Matrix.new(r_dims, values)
    vertical_to_array(m)
  end

  def multiply_matrix_matrix_1_2(a, b)
    new_a = array_to_horizontal(a)
    new_a_dims = new_a.dimensions
    b_dims = b.dimensions
    # number of columns in a must match number of rows in b
    raise(BASICException, 'Matrix dimensions do not match') if
      new_a_dims[1] != b_dims[0]
    r_dims = [new_a_dims[0], b_dims[1]]
    values = multiply_matrix_matrix_work(new_a, b)
    m = Matrix.new(r_dims, values)
    horizontal_to_array(m)
  end

  def multiply_matrix_matrix(a, b)
    dim_counts = [a.dimensions.size, b.dimensions.size]
    if dim_counts == [2, 1]
      multiply_matrix_matrix_2_1(a, b)
    elsif dim_counts == [1, 2]
      multiply_matrix_matrix_1_2(a, b)
    elsif dim_counts == [2, 2]
      multiply_matrix_matrix_2_2(a, b)
    else
      raise(BASICException, 'Matrix multiplication must have two matrices')
    end
  end

  def divide_matrix_matrix(_, _)
    raise BASICException, 'Cannot divide matrix by matrix'
  end

  def power_matrix_matrix(_, _)
    raise BASICException, 'Cannot raise matrix to matrix power'
  end
end

# Initial operator
# not a real operator, used only for parsing
class InitialOperator < AbstractElement
  def initialize
    super()
    @operator = true
    @terminal = true
    @precedence = 0
  end

  def to_s
    'INIT'
  end
end

# Terminal operator
# not a real operator, used only for parsing
class TerminalOperator < AbstractElement
  def initialize
    super()
    @operator = true
    @terminal = true
    @precedence = 0
  end

  def to_s
    'TERM'
  end
end
