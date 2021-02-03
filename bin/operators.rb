# Unary scalar operators
class UnaryOperator < AbstractElement
  @operators = [ '+', '-', '#' ]

  def self.operators
    @operators
  end

  attr_reader :content_type
  attr_reader :arguments
  attr_reader :precedence

  def initialize(text)
    super()
    @op = text.to_s
    @content_type = :unknown
    @precedence = 9
    @arguments = nil
    @operator = true
  end

  def set_arguments(arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.empty?

    @arguments = arg_stack.slice(-1, 1)
    pop_stack(arg_stack)

    @content_type = @arguments[0].content_type if @content_type == :unknown

    raise(BASICExpressionError, 'Bad expression') if @content_type == :unknown
  end

  def pop_stack(stack)
    stack.pop
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.empty?

    type = type_stack.pop

    raise(BASICExpressionError, 'Bad expression') if type != :numeric
    
    @content_type = :numeric
    type_stack.push(@content_type)
  end

  def dump
    self.class.to_s + ':' + @op + ' ' + @content_type.to_s
  end

  def unary?
    true
  end

  def binary?
    false
  end

  def pound?
    false
  end

  def to_s
    @op
  end
end

# Binary scalar operators
class BinaryOperator < AbstractElement
  def self.accept?(token)
    classes = %w[OperatorToken]

    classes.include?(token.class.to_s)
  end

  @operators = [
    '=', '<>', '>', '>=', '<', '<=',
    '+', '-', '*', '/', '^'
  ]

  def self.operators
    @operators
  end

  attr_reader :content_type
  attr_reader :arguments
  attr_reader :precedence

  def initialize(text)
    super()

    @op = text.to_s
    @content_type = :unknown
    @arguments = nil
    @operator = true
  end

  def set_arguments(arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    @arguments = arg_stack.slice(-2, 2)
    pop_stack(arg_stack)

    this_type = @arguments[0].content_type

    raise(BASICExpressionError, 'Bad expression') if this_type == :unknown

    other_type = @arguments[1].content_type

    raise(BASICExpressionError, 'Bad expression') if other_type == :unknown

    raise(BASICExpressionError, 'Type mismatch') unless
      compatible(this_type, other_type)

    @content_type = @arguments[0].content_type if @content_type == :unknown
  end

  def pop_stack(stack)
    stack.pop
    stack.pop
  end

  def dump
    self.class.to_s + ':' + @op + ' ' + @content_type.to_s
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

  def to_s
    @op
  end

  private

  def compatible(type1, type2)
    return true if type1 == type2

    numerics = [:numeric, :integer, :boolean]

    return true if numerics.include?(type1) && numerics.include?(type2)

    false
  end
  
  def op_scalar_matrix_1(op, a, b)
    dims = b.dimensions
    n_cols = dims[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
      b_value = b.get_value_1(col)
      coords = AbstractElement.make_coord(col)
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
        coords = AbstractElement.make_coords(row, col)
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
      coords = AbstractElement.make_coord(col)
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
        coords = AbstractElement.make_coords(row, col)
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
      coords = AbstractElement.make_coord(col)
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
        coords = AbstractElement.make_coords(row, col)
        values[coords] = a_value.send(:add, b_value)
      end
    end

    values
  end

  def add_matrix_matrix(a, b)
    # verify dimensions match
    a_dims = a.dimensions
    b_dims = b.dimensions

    raise(BASICExpressionError, 'Matrix dimensions do not match') if
      a_dims != b_dims

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
      coords = AbstractElement.make_coord(col)
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
        coords = AbstractElement.make_coords(row, col)
        values[coords] = a_value.send(:subtract, b_value)
      end
    end

    values
  end

  def subtract_matrix_matrix(a, b)
    # verify dimensions match
    a_dims = a.dimensions
    b_dims = b.dimensions

    raise(BASICExpressionError, 'Matrix dimensions do not match') if
      a_dims != b_dims

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
      coords = AbstractElement.make_coords(base, col)
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
      coords = AbstractElement.make_coord(col)
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
      coords = AbstractElement.make_coords(col, base)
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
      coords = AbstractElement.make_coord(row)
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
        coords = AbstractElement.make_coords(r_row, r_col)
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
      raise(BASICExpressionError,
            'Matrix multiplication must have two matrices')
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
    raise BASICRuntimeError.new(:te_arr_dif_siz) if a.dimensions != dims
    n_cols = dims[0].to_i
    values = {}
    (base..n_cols).each do |col|
      a_value = a.get_value(col)
      b_value = b.get_value(col)
      coords = AbstractElement.make_coord(col)
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
      coords = AbstractElement.make_coord(col)
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
      coords = AbstractElement.make_coord(col)
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

class UnaryOperatorPlus < UnaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '+'
  end

  def initialize(text)
    super

    @precedence = 6
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.empty?

    x = arg_stack.pop

    if x.matrix?
      posate_matrix(x)
    elsif x.array?
      posate_array(x)
    else
      posate(x)
    end
  end

  private

  def posate_a(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
      value = source.get_value(col)
      coords = AbstractElement.make_coord(col)
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
      coords = AbstractElement.make_coord(col)
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
        coords = AbstractElement.make_coords(row, col)
        values[coords] = posate(value)
      end
    end

    values
  end

  def posate(a)
    f = a.to_f
    NumericConstant.new(f)
  end

  def posate_array(a)
    dims = a.dimensions
    values = posate_a(a)
    BASICArray.new(dims, values)
  end

  def posate_matrix(a)
    dims = a.dimensions
    values = posate_1(a) if dims.size == 1
    values = posate_2(a) if dims.size == 2

    Matrix.new(dims, values)
  end
end

class UnaryOperatorMinus < UnaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '-'
  end

  def initialize(text)
    super

    @precedence = 6
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.empty?

    x = arg_stack.pop

    if x.matrix?
      negate_matrix(x)
    elsif x.array?
      negate_array(x)
    else
      negate(x)
    end
  end

  private
  
  def negate_a(source)
    n_cols = source.dimensions[0].to_i
    values = {}
    base = $options['base'].value

    (base..n_cols).each do |col|
      value = source.get_value(col)
      coords = AbstractElement.make_coord(col)
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
      coords = AbstractElement.make_coord(col)
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
        coords = AbstractElement.make_coords(row, col)
        values[coords] = negate(value)
      end
    end

    values
  end

  def negate(a)
    f = -a.to_f
    NumericConstant.new(f)
  end

  def negate_array(a)
    dims = a.dimensions
    values = negate_a(a)

    BASICArray.new(dims, values)
  end

  def negate_matrix(a)
    dims = a.dimensions
    values = negate_1(a) if dims.size == 1
    values = negate_2(a) if dims.size == 2

    Matrix.new(dims, values)
  end
end

class UnaryOperatorHash < UnaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '#'
  end

  def initialize(text)
    super

    @content_type = :filehandle
    @precedence = 4
  end

  def pound?
    true
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.empty?

    type = type_stack.pop

    raise(BASICExpressionError, 'Bad expression') if type != :numeric
    
    @content_type = :filehandle
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.empty?

    x = arg_stack.pop

    if x.matrix?
    elsif x.array?
    else
      file_handle(x)
    end
  end

  private

  def file_handle(a)
    num = a.to_i
    FileHandle.new(num)
  end
end

class BinaryOperatorPlus < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '+'
  end

  def self.operator?(op)
    op == '+'
  end

  def self.precedence(op)
    3
  end

  def initialize(text)
    super

    @precedence = 3
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands +') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a + #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression + b #{b_type}") if
      b_type != :numeric
    
    @content_type = :numeric
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:add, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:add, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:add, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:add, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:add, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:add, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:add, y)
  end
end

class BinaryOperatorMinus < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '-'
  end

  def self.operator?(op)
    op == '-'
  end

  def self.precedence(op)
    3
  end

  def initialize(text)
    super

    @precedence = 3
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands -') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a - #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression - b #{b_type}") if
      b_type != :numeric
    
    @content_type = :numeric
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:subtract, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:subtract, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:subtract, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:subtract, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:subtract, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:subtract, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:subtract, y)
  end
end

class BinaryOperatorMultiply < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '*'
  end

  def self.operator?(op)
    op == '*'
  end

  def self.precedence(op)
    4
  end

  def initialize(text)
    super

    @precedence = 4
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands *') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a * #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression * b #{b_type}") if
      b_type != :numeric
    
    @content_type = :numeric
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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

  def matrix_matrix(x, y)
    op_matrix_matrix(:multiply, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:multiply, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:multiply, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:multiply, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:multiply, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:multiply, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:multiply, y)
  end
end

class BinaryOperatorDivide < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '/'
  end

  def self.operator?(op)
    op == '/'
  end

  def self.precedence(op)
    4
  end

  def initialize(text)
    super

    @precedence = 4
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands /') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a / #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression / b #{b_type}") if
      b_type != :numeric
   
    @content_type = :numeric
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:divide, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:divide, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:divide, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:divide, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:divide, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:divide, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:divide, y)
  end
end

class BinaryOperatorPower < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '^'
  end

  def self.operator?(op)
    op == '^'
  end

  def self.precedence(op)
    5
  end

  def initialize(text)
    super

    @precedence = 5
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a ^ #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression ^ b #{b_type}") if
      b_type != :numeric

    @content_type = :numeric
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:power, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:power, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:power, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:power, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:power, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:power, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:power, y)
  end
end

class BinaryOperatorEqual < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '='
  end

  def self.operator?(op)
    op == '='
  end

  def self.precedence(op)
    2
  end

  def initialize(text)
    super

    @precedence = 2
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a = #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression = b #{b_type}") if
      b_type != :numeric

    @content_type = :boolean
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:b_eq, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:b_eq, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:b_eq, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:b_eq, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:b_eq, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:b_eq, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:b_eq, y)
  end
end

class BinaryOperatorNotEqual < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '<>'
  end

  def self.operator?(op)
    op == '<>'
  end

  def self.precedence(op)
    2
  end

  def initialize(text)
    super

    @precedence = 2
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a <> #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression <> b #{b_type}") if
      b_type != :numeric
 
    @content_type = :boolean
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:b_ne, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:b_ne, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:b_ne, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:b_ne, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:b_ne, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:b_ne, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:b_ne, y)
  end
end

class BinaryOperatorLess < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '<'
  end

  def self.operator?(op)
    op == '<'
  end

  def self.precedence(op)
    2
  end

  def initialize(text)
    super

    @precedence = 2
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a < #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression < b #{b_type}") if
      b_type != :numeric

    @content_type = :boolean
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:b_lt, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:b_lt, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:b_lt, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:b_lt, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:b_lt, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:b_lt, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:b_lt, y)
  end
end

class BinaryOperatorLessEqual < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '<='
  end

  def self.operator?(op)
    op == '<='
  end

  def self.precedence(op)
    2
  end

  def initialize(text)
    super

    @precedence = 2
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a <= #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression <= b #{b_type}") if
      b_type != :numeric
 
    @content_type = :boolean
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:b_le, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:b_le, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:b_le, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:b_le, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:b_le, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:b_le, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:b_le, y)
  end
end

class BinaryOperatorGreater < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '>'
  end

  def self.operator?(op)
    op == '>'
  end

  def self.precedence(op)
    2
  end

  def initialize(text)
    super

    @precedence = 2
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a > #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression > b #{b_type}") if
      b_type != :numeric

    @content_type = :boolean
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:b_gt, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:b_gt, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:b_gt, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:b_gt, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:b_gt, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:b_gt, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:b_gt, y)
  end
end

class BinaryOperatorGreaterEqual < BinaryOperator
  def self.accept?(token)
    classes = %w[OperatorToken]
    classes.include?(token.class.to_s) && token.to_s == '>='
  end

  def self.operator?(op)
    op == '>='
  end

  def self.precedence(op)
    2
  end

  def initialize(text)
    super

    @precedence = 2
  end

  def set_content_type(type_stack)
    raise(BASICExpressionError, 'Not enough operands') if type_stack.size < 2

    a_type = type_stack.pop
    b_type = type_stack.pop
    
    raise(BASICExpressionError, "Bad expression a >= #{a_type}") if
      a_type != :numeric
    
    raise(BASICExpressionError, "Bad expression >= b #{b_type}") if
      b_type != :numeric

    @content_type = :boolean
    type_stack.push(@content_type)
  end

  def evaluate(_, arg_stack)
    raise(BASICExpressionError, 'Not enough operands') if arg_stack.size < 2

    y = arg_stack.pop
    x = arg_stack.pop

    base = $options['base'].value

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
    else
      op_scalar_scalar(x, y)
    end
  end

  def matrix_matrix(x, y)
    op_matrix_matrix(:b_ge, x, y)
  end

  def matrix_scalar(x, y)
    op_matrix_scalar(:b_ge, x, y)
  end

  def scalar_matrix(x, y)
    op_scalar_matrix(:b_ge, x, y)
  end

  def array_array(x, y, base)
    op_array_array(:b_ge, x, y, base)
  end

  def array_scalar(x, y, base)
    op_array_scalar(:b_ge, x, y, base)
  end

  def scalar_array(x, y, base)
    op_scalar_array(:b_ge, x, y, base)
  end

  def op_scalar_scalar(x, y)
    x.public_send(:b_ge, y)
  end
end
