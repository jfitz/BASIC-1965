# Unary scalar operators
class UnaryOperator < AbstractElement
  def self.accept?(token)
    classes = %w(OperatorToken)
    classes.include?(token.class.to_s)
  end

  @operators = { '+' => 6, '-' => 6, '#' => 4 }

  def self.operator?(op)
    @operators.key?(op)
  end

  def self.precedence(op)
    @operators[op]
  end

  def self.operators
    @operators.keys
  end

  attr_reader :content_type
  attr_reader :arguments

  def initialize(text)
    super()
    @op = text.to_s
    @content_types = { '#' => :filehandle, ':' => :filehandle }
    @content_type = @content_types[@op]
    @content_type = :unknown if @content_type.nil?
    @arguments = nil

    raise(BASICExpressionError, "'#{text}' is not an operator") unless
      self.class.operator?(@op)

    @precedence = self.class.precedence(@op)
    @operator = true
  end

  def set_arguments(stack)
    raise(BASICExpressionError, 'Bad expression') if stack.empty?

    @arguments = stack.slice(-1, 1)
    pop_stack(stack)

    @content_type = @arguments[0].content_type if @content_type == :unknown

    raise(BASICExpressionError, 'Bad expression') if
      @content_type == :unknown
  end

  def pop_stack(stack)
    stack.pop
  end

  def dump
    self.class.to_s + ':' + @op
  end

  def unary?
    true
  end

  def binary?
    false
  end

  def pound?
    @op == '#'
  end
  
  def evaluate(_, stack)
    raise(BASICExpressionError, 'Not enough operands') if stack.empty?
    x = stack.pop
    if x.matrix?
      case @op
      when '+'
        posate_matrix(x)
      when '-'
        negate_matrix(x)
      end
    elsif x.array?
      case @op
      when '+'
        posate_array(x)
      when '-'
        negate_array(x)
      end
    else
      case @op
      when '+'
        posate(x)
      when '-'
        negate(x)
      when '#'
        file_handle(x)
      end
    end
  end

  def to_s
    @op
  end

  private

  def posate_a(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
      value = source.get_value(col)
      coords = make_coord(col)
      values[coords] = posate(value)
    end
    values
  end

  def posate_1(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
        value = source.get_value_2(row, col)
        coords = make_coords(row, col)
        values[coords] = posate(value)
      end
    end
    values
  end

  def negate_a(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
      value = source.get_value(col)
      coords = make_coord(col)
      values[coords] = negate(value)
    end
    values
  end

  def negate_1(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
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

  def file_handle(a)
    num = a.to_i
    FileHandle.new(num)
  end

  def posate_array(a)
    dims = a.dimensions
    values = posate_a(a)
    BASICArray.new(dims, values)
  end

  def negate_array(a)
    dims = a.dimensions
    values = negate_a(a)
    BASICArray.new(dims, values)
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

  @operators = {
    '=' => 2, '<>' => 2,
    '>' => 2, '>=' => 2,
    '<' => 2, '<=' => 2,
    '+' => 3, '-' => 3, '*' => 4, '/' => 4, '^' => 5
  }

  def self.operator?(op)
    @operators.key?(op)
  end

  def self.precedence(op)
    @operators[op]
  end

  def self.operators
    @operators.keys
  end

  attr_reader :content_type
  attr_reader :arguments

  def initialize(text)
    super()
    @op = text.to_s
    @content_types = {
      '=' => :boolean, '<>' => :boolean,
      '>' => :boolean, '>=' => :boolean,
      '<' => :boolean, '<=' => :boolean
    }
    @content_type = @content_types[@op]
    @content_type = :unknown if @content_type.nil?
    @arguments = nil

    raise(BASICExpressionError, "'#{text}' is not an operator") unless
      self.class.operator?(@op)

    @precedence = self.class.precedence(@op)
    @operator = true
  end

  def set_arguments(stack)
    raise(BASICExpressionError, 'Bad expression') if stack.size < 2

    @arguments = stack.slice(-2, 2)
    pop_stack(stack)

    this = @arguments[0].content_type

    raise(BASICExpressionError, 'Bad expression') if this == :unknown

    other = @arguments[1].content_type

    raise(BASICExpressionError, 'Bad expression') if other == :unknown

    raise(BASICExpressionError, 'Type mismatch') if other != this

    @content_type = @arguments[0].content_type if @content_type == :unknown
  end

  def pop_stack(stack)
    stack.pop
    stack.pop
  end

  def dump
    self.class.to_s + ':' + @op
  end

  def unary?
    false
  end

  def binary?
    true
  end
  
  def pound?
    @op == '#'
  end
  
  def evaluate(interpreter, stack)
    raise(BASICExpressionError, 'Not enough operands') if stack.size < 2

    y = stack.pop
    x = stack.pop

    base = interpreter.base

    if x.matrix? && y.matrix?
      matrix_matrix(x, y)
    elsif x.matrix? && y.scalar?
      matrix_scalar(x, y)
    elsif x.scalar? && y.matrix?
      scalar_matrix(x, y)
    elsif x.array? && y.array?
      array_array(x, y, base)
    elsif x.array? && y.scalar?
      array_scalar(x, y, base)
    elsif x.scalar? && y.array?
      scalar_array(x, y, base)
    elsif x.content_type == y.content_type
      op_scalar_scalar(x, y)
    else
      raise(BASICExpressionError, 'Type mismatch')
    end
  end

  def to_s
    @op
  end

  private

  def matrix_matrix(x, y)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    op_matrix_matrix(op_sym, x, y)
  end

  def matrix_scalar(x, y)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    op_matrix_scalar(op_sym, x, y)
  end

  def scalar_matrix(x, y)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    op_scalar_matrix(op_sym, x, y)
  end

  def array_array(x, y, base)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    op_array_array(op_sym, x, y, base)
  end

  def array_scalar(x, y, base)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    op_array_scalar(op_sym, x, y, base)
  end

  def scalar_array(x, y, base)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    op_scalar_array(op_sym, x, y, base)
  end

  def op_scalar_scalar(x, y)
    op_table = {
      '+' => :add,
      '-' => :subtract,
      '*' => :multiply,
      '/' => :divide,
      '^' => :power,
      '=' => :b_eq,
      '<>' => :b_ne,
      '<' => :b_lt,
      '<=' => :b_le,
      '>' => :b_gt,
      '>=' => :b_ge
    }

    op_sym = op_table[@op]

    raise BASICExpressionError, 'Invalid operation' if op_sym.nil?

    x.public_send(op_sym, y)
  end

  def op_scalar_matrix_1(op, a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_cols).each do |col|
      a_value = a.get_value_1(col)
      b_value = b.get_value_1(col)
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
    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
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
    raise(BASICExpressionError, 'Matrix dimensions do not match') if a_dims != b_dims
    values = add_matrix_matrix_1(a, b) if a_dims.size == 1
    values = add_matrix_matrix_2(a, b) if a_dims.size == 2
    Matrix.new(a_dims, values)
  end

  def subtract_matrix_matrix_1(a, b)
    a_dims = a.dimensions
    n_cols = a_dims[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
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
    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
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
    raise(BASICExpressionError, 'Matrix dimensions do not match') if a_dims != b_dims
    values = subtract_matrix_matrix_1(a, b) if a_dims.size == 1
    values = subtract_matrix_matrix_2(a, b) if a_dims.size == 2
    Matrix.new(a_dims, values)
  end

  def array_to_horizontal(a)
    base = $options['base'].value
    a_dims = a.dimensions
    new_dims = [NumericConstant.new(base), a_dims[0]]
    n_cols = a_dims[0].to_i
    new_values = {}

    (base..n_cols).each do |col|
      value = a.get_value_1(col)
      coords = make_coords(base, col)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def horizontal_to_array(m)
    m_dims = m.dimensions
    new_dims = [m_dims[1]]
    new_values = {}
    n_cols = new_dims[0].to_i
    base = $options['base'].value
    row = base

    (base..n_cols).each do |col|
      value = m.get_value_2(row, col)
      coords = make_coord(col)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def array_to_vertical(a)
    base = $options['base'].value
    a_dims = a.dimensions
    new_dims = [a_dims[0], NumericConstant.new(base)]
    n_cols = a_dims[0].to_i
    new_values = {}

    (base..n_cols).each do |col|
      value = a.get_value_1(col)
      coords = make_coords(col, base)
      new_values[coords] = value
    end
    Matrix.new(new_dims, new_values)
  end

  def vertical_to_array(m)
    m_dims = m.dimensions
    new_dims = [m_dims[0]]
    new_values = {}
    n_rows = new_dims[0].to_i
    base = $options['base'].value
    col = base

    (base..n_rows).each do |row|
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
    base = $options['base'].value

    (base..a_cols).each do |a_col|
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
    base = $options['base'].value

    (base..r_rows).each do |r_row|
      (base..r_cols).each do |r_col|
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
    raise(BASICExpressionError, 'Matrix dimensions do not match') if
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
    raise(BASICExpressionError, 'Matrix dimensions do not match') if
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
    raise(BASICExpressionError, 'Matrix dimensions do not match') if
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
      raise(BASICExpressionError, 'Matrix multiplication must have two matrices')
    end
  end

  def divide_matrix_matrix(_, _)
    raise BASICExpressionError, 'Cannot divide matrix by matrix'
  end

  def power_matrix_matrix(_, _)
    raise BASICExpressionError, 'Cannot raise matrix to matrix power'
  end

  def op_array_array(op, a, b, base)
    dims = b.dimensions
    raise(BASICRuntimeError, 'Arrays of different size') if a.dimensions != dims
    n_cols = dims[0].to_i
    values = {}
    (base..n_cols).each do |col|
      a_value = a.get_value(col)
      b_value = b.get_value(col)
      coords = make_coord(col)
      values[coords] = a_value.send(op, b_value)
    end
    BASICArray.new(dims, values)
  end

  def op_scalar_array(op, a, b, base)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    (base..n_cols).each do |col|
      b_value = b.get_value(col)
      coords = make_coord(col)
      values[coords] = a.send(op, b_value)
    end
    BASICArray.new(dims, values)
  end

  def op_array_scalar(op, a, b, base)
    dims = a.dimensions
    n_cols = dims[0].to_i
    values = {}
    (base..n_cols).each do |col|
      a_value = a.get_value(col)
      coords = make_coord(col)
      values[coords] = a_value.send(op, b)
    end
    BASICArray.new(dims, values)
  end

  def op_matrix_matrix(op_sym, a, b)
    case op_sym
    when :add
      add_matrix_matrix(a, b)
    when :subtract
      subtract_matrix_matrix(a, b)
    when :multiply
      multiply_matrix_matrix(a, b)
    when :divide
      divide_matrix_matrix(a, b)
    when :power
      power_matrix_matrix(a, b)
    end
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
