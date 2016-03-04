# Hold a variable name (not a reference or value)
class VariableName < AbstractToken
  def self.init?(text)
    /\A[A-Z]\d?\z/.match(text)
  end

  def initialize(text)
    super()
    fail(BASICException, "'#{text}' is not a variable name") unless
      VariableName.init?(text)
    @var_name = text
    @variable = true
    @operand = true
    @precedence = 6
  end

  def eql?(other)
    @var_name == other.to_s
  end

  def ==(other)
    @var_name == other.to_s
  end

  def hash
    @var_name.hash
  end

  def to_s
    @var_name
  end
end

# Hold a variable (name with possible subscripts and value)
class Variable < AbstractToken
  attr_reader :subscripts

  def initialize(variable_name)
    super()
    fail(BASICException, "'#{variable_name}' is not a variable name") if
      variable_name.class.to_s != 'VariableName'
    @variable_name = variable_name
    @subscripts = []
    @variable = true
    @operand = true
    @precedence = 6
  end

  def name
    @variable_name
  end

  def to_s
    if subscripts.length > 0
      @variable_name.to_s + '(' + @subscripts.join(',') + ')'
    else
      @variable_name.to_s
    end
  end
end

# Scalar value (not a matrix)
class ScalarValue < Variable
  def initialize(variable_name)
    super
  end

  private

  def previous_is_array(stack)
    stack.size > 0 && stack[-1].class.to_s == 'Array'
  end

  def get_subscripts(stack)
    subscripts = stack.pop
    num_args = subscripts.length
    fail(Exception,
         'Variable expects subscripts, found empty parentheses') if
      num_args == 0
    subscripts
  end

  def eval_var_name(name, subscripts)
    name.to_s + '(' + subscripts.join(',') + ')'
  end

  public

  # return a single value
  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      @subscripts = get_subscripts(stack)
      interpreter.check_subscripts(@variable_name, @subscripts)
      evaled_var_name = eval_var_name(@variable_name, @subscripts)
      interpreter.get_value(evaled_var_name)
    else
      interpreter.get_value(@variable_name.to_s)
    end
  end
end

# Scalar reference (not a matrix)
class ScalarReference < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  # return a single value, a reference to this object
  def evaluate(interpreter, stack)
    if stack.size > 0 && stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(BASICException,
           'Variable expects subscripts, found empty parentheses') if
        num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

# Matrix with values
class Matrix
  attr_reader :dimensions

  def initialize(dimensions, values)
    @dimensions = dimensions
    @values = values
  end

  def clone
    Matrix.new(@dimensions.clone, @values.clone)
  end

  def matrix?
    true
  end

  def values_2
    values = {}
    (1..@dimensions[0].to_i).each do |row|
      (1..@dimensions[1].to_i).each do |col|
        value = get_value_2(row, col)
        coords = make_coords(row, col)
        values[coords] = value
      end
    end
    values
  end

  def get_value_1(col)
    coords = make_coord(col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def get_value_2(row, col)
    coords = make_coords(row, col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def to_s
    'MATRIX: ' + @values.to_s
  end

  def print(printer, interpreter, carriage)
    case @dimensions.size
    when 0
      fail BASICException, 'Need dimensions in matrix'
    when 1
      print_1(printer, interpreter, carriage)
    when 2
      print_2(printer, interpreter, carriage)
    else
      fail BASICException, 'Too many dimensions in matrix'
    end
  end

  def transpose_values
    fail(BASICException, 'TRN requires matrix') unless @dimensions.size == 2
    new_values = {}
    (1..@dimensions[0].to_i).each do |row|
      (1..@dimensions[1].to_i).each do |col|
        value = get_value_2(row, col)
        coords = make_coords(col, row)
        new_values[coords] = value
      end
    end
    new_values
  end

  def determinant
    fail(BASICException, 'DET requires matrix') unless @dimensions.size == 2
    fail(BASICException, 'DET requires square matrix') if
      @dimensions[1] != @dimensions[0]
    case @dimensions[0].to_i
    when 1
      get_value_2(1, 1)
    when 2
      determinant_2
    else
      determinant_n
    end
  end

  def inverse_values
    # set all values
    values = values_2

    # create identity matrix
    i_matrix = Matrix.new(@dimensions, {})
    inv_values = i_matrix.identity_values

    n_rows = @dimensions[0].to_i
    n_cols = @dimensions[1].to_i

    # convert to upper triangular form
    upper_triangle(n_cols, n_rows, values, inv_values)
    # convert to lower triangular form
    lower_triangle(n_cols, values, inv_values)
    # normalize to ones
    unitize(n_cols, n_rows, values, inv_values)

    inv_values
  end

  def zero_values
    x = make_array(@dimensions, NumericConstant.new(0)) if
      @dimensions.size == 1
    x = make_matrix(@dimensions, NumericConstant.new(0)) if
      @dimensions.size == 2
    x
  end

  def one_values
    x = make_array(@dimensions, NumericConstant.new(1)) if
      @dimensions.size == 1
    x = make_matrix(@dimensions, NumericConstant.new(1)) if
      @dimensions.size == 2
    x
  end

  def identity_values
    new_values = make_matrix(@dimensions, NumericConstant.new(0))
    one = NumericConstant.new(1)
    (1..@dimensions[0].to_i).each do |row|
      coords = make_coords(row, row)
      new_values[coords] = one
    end
    new_values
  end

  private

  def make_coord(c)
    '(' + c.to_s + ')'
  end

  def make_coords(r, c)
    '(' + r.to_s + ',' + c.to_s + ')'
  end

  def make_array(dims, init_value)
    values = {}
    (1..dims[0].to_i).each do |col|
      coords = make_coord(col)
      values[coords] = init_value
    end
    values
  end

  def make_matrix(dims, init_value)
    values = {}
    (1..dims[0].to_i).each do |row|
      (1..dims[1].to_i).each do |col|
        coords = make_coords(row, col)
        values[coords] = init_value
      end
    end
    values
  end

  def print_1(printer, interpreter, carriage)
    n_cols = @dimensions[0].to_i

    (1..n_cols).each do |col|
      value = get_value_1(col)
      value.print(printer)
      carriage.print(printer, interpreter)
    end
    printer.newline
    printer.newline
  end

  def print_2(printer, interpreter, carriage)
    n_rows = @dimensions[0].to_i
    n_cols = @dimensions[1].to_i

    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = get_value_2(row, col)
        value.print(printer)
        carriage.print(printer, interpreter)
      end
      printer.newline
    end
    printer.newline
  end

  def determinant_2
    a = get_value_2(1, 1)
    b = get_value_2(1, 2)
    c = get_value_2(2, 1)
    d = get_value_2(2, 2)
    (a * d) - (b * c)
  end

  def determinant_n
    minus_one = NumericConstant.new(-1)
    sign = NumericConstant.new(1)
    det = NumericConstant.new(0)
    # for each element in first row
    (1..@dimensions[1].to_i).each do |col|
      v = get_value_2(1, col)
      # create submatrix
      subm = submatrix(1, col)
      d = v * subm.determinant * sign
      det += d
      sign *= minus_one
    end
    det
  end

  def submatrix(exclude_row, exclude_col)
    one = NumericConstant.new(1)
    new_dims = [@dimensions[0] - one, @dimensions[1] - one]
    new_values = {}
    new_row = 1
    (1..@dimensions[0].to_i).each do |row|
      new_col = 1
      next if row == exclude_row
      (1..@dimensions[1].to_i).each do |col|
        next if col == exclude_col
        value = get_value_2(row, col)
        coords = make_coords(new_row, new_col)
        new_values[coords] = value
        new_col += 1
      end
      new_row += 1
    end
    Matrix.new(new_dims, new_values)
  end

  def calc_factor(values, row, col)
    denom_coords = make_coords(col, col)
    denominator = values[denom_coords]
    numer_coords = make_coords(row, col)
    numerator = values[numer_coords]
    numerator / denominator
  end

  def adjust_matrix_entry(values, row, col, wcol, factor)
    value_coords = make_coords(row, wcol)
    minuend_coords = make_coords(col, wcol)
    subtrahend = values[value_coords]
    minuend = values[minuend_coords]
    new_value = subtrahend - minuend * factor
    values[value_coords] = new_value
  end

  def upper_triangle(n_cols, n_rows, values, inv_values)
    (1..n_cols - 1).each do |col|
      (col + 1..n_rows).each do |row|
        # adjust values for this row
        factor = calc_factor(values, row, col)
        (1..n_cols).each do |wcol|
          adjust_matrix_entry(values, row, col, wcol, factor)
          adjust_matrix_entry(inv_values, row, col, wcol, factor)
        end
      end
    end
  end

  def lower_triangle(n_cols, values, inv_values)
    n_cols.downto(2) do |col|
      (col - 1).downto(1).each do |row|
        # adjust values for this row
        factor = calc_factor(values, row, col)
        (1..n_cols).each do |wcol|
          adjust_matrix_entry(values, row, col, wcol, factor)
          adjust_matrix_entry(inv_values, row, col, wcol, factor)
        end
      end
    end
  end

  def unitize(n_cols, n_rows, values, inv_values)
    (1..n_rows).each do |row|
      denom_coords = make_coords(row, row)
      denominator = values[denom_coords]
      (1..n_cols).each do |col|
        unitize_matrix_entry(values, row, col, denominator)
        unitize_matrix_entry(inv_values, row, col, denominator)
      end
    end
  end

  def unitize_matrix_entry(values, row, col, denominator)
    coords = make_coords(row, col)
    numerator = values[coords]
    new_value = numerator / denominator
    values[coords] = new_value
  end
end

# Matrix value
class MatrixValue < Variable
  def initialize(variable_name)
    super
  end

  def evaluate(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)
    fail(BASICException, 'Variable has no dimensions') if dims.nil?
    values = {}
    if dims.size == 1
      n_cols = dims[0].to_i
      values = evaluate_1(interpreter, n_cols)
    end
    if dims.size == 2
      n_rows = dims[0].to_i
      n_cols = dims[1].to_i
      values = evaluate_2(interpreter, n_rows, n_cols)
    end
    Matrix.new(dims, values)
  end

  private

  def evaluate_1(interpreter, n_cols)
    values = {}
    (1..n_cols).each do |col|
      coords = make_coord(col)
      var_name = @variable_name.to_s + coords
      values[coords] = interpreter.get_value(var_name)
    end
    values
  end

  def evaluate_2(interpreter, n_rows, n_cols)
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        coords = make_coords(row, col)
        var_name = @variable_name.to_s + coords
        values[coords] = interpreter.get_value(var_name)
      end
    end
    values
  end
end

# Matrix reference
class MatrixReference < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  def dimensions?
    @subscripts.size > 0
  end

  def dimensions
    @subscripts
  end

  # return a single value, a reference to this object
  def evaluate(interpreter, stack)
    if stack.size > 0 && stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(BASICException,
           'Variable expects subscripts, found empty parentheses') if
        num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

# Dimensions to a variable
class VariableDimension < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  # return a single value, a reference to this object
  def evaluate(_, stack)
    if stack.size > 0 && stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(BASICException,
           'Variable expects subscripts, found empty parentheses') if
        num_args == 0
    end
    self
  end
end

# A list (needed because it has precedence value)
class List < AbstractToken
  def initialize(parsed_expressions)
    super()
    @parsed_expressions = parsed_expressions
    @variable = true
    @precedence = 6
  end

  def list
    @parsed_expressions
  end

  def evaluate(interpreter, _)
    eval_scalar(interpreter, @parsed_expressions)
  end

  def to_s
    "[#{@parsed_expressions.join('] [')}]"
  end
end

# Scalar function (provides a scalar)
class Function < AbstractToken
  def initialize(text)
    super()
    @name = text
    @function = true
    @operand = true
    @precedence = 6
  end

  private

  def check_args(args)
    fail(BASICException, 'No arguments for function') if
      args.class.to_s != 'Array'
  end

  def check_value(value, type)
    fail(BASICException,
         "Argument #{x} #{x.class} not of type #{type.class}") if
      value.class.to_s != type
  end

  def check_arg_types(args, types)
    check_args(args)
    n_types = types.size
    n_args = args.size
    fail(BASICException,
         "Function #{@name} expects #{n_types} argument, found #{n_args}") if
      n_args != n_types
    (0..types.size - 1).each do |i|
      check_value(args[i], types[i])
    end
  end
end

# Function that expects scalar parameters
class AbstractScalarFunction < Function
  def initialize(text)
    super
  end

  def default_type
    ScalarValue
  end
end

# Function that expects matrix parameters
class AbstractMatrixFunction < Function
  def initialize(text)
    super
  end

  def default_type
    MatrixValue
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'INT requires single value') if args.size != 1
    check_arg_types(args, ['NumericConstant'])
    args[0].truncate
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop
    fail(BASICException, 'Zero or one argument required for RND()') unless
      args.size == 1 || args.size == 2
    x = NumericConstant.new(100) if args.size == 0
    if args.size == 1
      check_arg_types(args, ['NumericConstant'])
      x = args[0]
    end
    interpreter.rand(x)
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for EXP()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].exp
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for LOG()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].log
  end
end

# function ABS
class FunctionAbs < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for ABS()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].abs
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for SQR()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].sqrt
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for SIN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].sin
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for COS()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].cos
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for TAN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].tan
  end
end

# function ATN
class FunctionAtn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for ATN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].atn
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for SGN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].sign
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for TRN()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
    dims = args[0].dimensions
    new_dims = [dims[1], dims[0]]
    Matrix.new(new_dims, args[0].transpose_values)
  end
end

# function ZER
class FunctionZer < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One or two arguments required for ZER()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    matrix = Matrix.new(args.clone, {})
    Matrix.new(matrix.dimensions, matrix.zero_values)
  end
end

# function CON
class FunctionCon < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One or two arguments required for CON()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    matrix = Matrix.new(args.clone, {})
    Matrix.new(matrix.dimensions, matrix.one_values)
  end
end

# function IDN
class FunctionIdn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One or two arguments required for IDN()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    fail(BASICException, 'IDN requires square matrix') if
      args.size == 2 && args[1] != args[0]
    dims = [args[0]] * 2
    matrix = Matrix.new(dims, {})
    Matrix.new(dims, matrix.identity_values)
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for DET()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
    args[0].determinant
  end
end

# function INV
class FunctionInv < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    fail(BASICException, 'One argument required for INV()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
    dims = args[0].dimensions
    fail(BASICException, 'INV requires matrix') unless dims.size == 2
    fail(BASICException, 'INV requires square matrix') if dims[1] != dims[0]
    Matrix.new(dims.clone, args[0].inverse_values)
  end
end

# class to make functions, given the name
class FunctionFactory
  def initialize
    @functions = {
      'INT' => FunctionInt,
      'RND' => FunctionRnd,
      'EXP' => FunctionExp,
      'LOG' => FunctionLog,
      'ABS' => FunctionAbs,
      'SQR' => FunctionSqr,
      'SIN' => FunctionSin,
      'COS' => FunctionCos,
      'TAN' => FunctionTan,
      'ATN' => FunctionAtn,
      'SGN' => FunctionSgn,
      'TRN' => FunctionTrn,
      'ZER' => FunctionZer,
      'CON' => FunctionCon,
      'IDN' => FunctionIdn,
      'DET' => FunctionDet,
      'INV' => FunctionInv
    }
  end

  def valid?(text)
    @functions.key?(text)
  end

  def make(text)
    @functions[text].new(text) if @functions.key?(text)
  end
end

# User-defined function (provides a scalar value)
class UserFunction < AbstractScalarFunction
  def self.init?(text)
    /\AFN[A-Z]\z/.match(text)
  end

  def initialize(text)
    fail(BASICException, "'#{text}' is not a valid function") unless
      UserFunction.init?(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    expression = interpreter.get_user_function(@name)
    # verify function is defined
    fail(BASICException, "Function #{@name} not defined") if expression.nil?
    user_var_names = interpreter.get_user_var_names(@name)

    # verify arguments
    user_var_values = stack.pop
    fail(BASICException, 'No arguments for function') if
      user_var_values.class.to_s != 'Array'
    num_values = user_var_names.length
    num_args = user_var_values.length
    fail(BASICException,
         "Function #{@name} expects #{num_values} args, found #{num_args}") if
      num_args != num_values
    types = ['NumericConstant'] * num_args
    check_arg_types(user_var_values, types)

    # dummy variable names and their (now known) values
    names_and_values = Hash[user_var_names.zip(user_var_values)]
    interpreter.set_user_var_values(names_and_values)
    result = expression.evaluate(interpreter)
    interpreter.clear_user_var_values
    result[0]
  end
end

# split a line into arguments
def split_args(text, keep_separators)
  args = []
  current_arg = ''
  in_string = false
  parens_level = 0
  text.each_char do |c|
    if in_string
      current_arg += c
      if c == '"'
        args << current_arg
        current_arg = ''
      end
    else
      if [',', ';'].include?(c) && parens_level == 0
        args << current_arg if current_arg.length > 0
        current_arg = ''
        args << c if keep_separators
      elsif c == '('
        current_arg += c
        parens_level += 1
      elsif c == ')'
        current_arg += c
        parens_level -= 1 if parens_level > 0
      else
        current_arg += c
      end
    end
    in_string = !in_string if c == '"'
  end
  args << current_arg if current_arg.size > 0
  args
end

# returns an Array of values
def eval_scalar(interpreter, parsed_expressions)
  # expected = parsed_expressions[0].length
  result_values = []
  parsed_expressions.each do |parsed_expression|
    stack = []
    parsed_expression.each do |token|
      value = token.evaluate(interpreter, stack)
      stack.push value
    end
    # should be only one item on stack
    # actual = stack.length
    # fail(Exception,
    #      "Expected #{expected} items, "
    #      "#{actual} remaining on evaluation stack") if
    #  actual != expected
    # very each item is of correct type
    item = stack[0]
    # fail(Exception,
    #      "Expected item #{expected_result_class}, "
    #      "found item type #{item.class} remaining on evaluation stack") if
    #  item.class.to_s != expected_result_class
    result_values << item unless item.nil?
  end
  # actual = result_values.length
  # fail(Exception,
  #      "Expected #{expected} items, "
  #      "#{actual} remaining on evaluation stack") if
  #   actual != expected
  result_values
end

# Expression parser
class Parser
  def initialize(default_type)
    @parsed_expressions = []
    @operator_stack = []
    @expression_stack = []
    @current_expression = []
    @parens_stack = []
    @type_stack = [default_type]
    @parens_group = []
    @previous_token = InitialOperator.new
  end

  def parse(token)
    fail(BASICException, 'Function requires parentheses') if
      !token.group_start? && @previous_token.function?
    if token.group_start? && @previous_token.function?
      # start parsing the list of function arguments
      @expression_stack.push(@current_expression)
      @current_expression = []
      @operator_stack.push(ParamStart.new)
      @parens_stack << @parens_group
      @parens_group = []
      @type_stack.push(@previous_token.default_type)
    elsif token.group_start? && @previous_token.variable?
      # start parsing the list of subscripts
      @expression_stack.push(@current_expression)
      @current_expression = []
      @operator_stack.push(ParamStart.new)
      @parens_stack << @parens_group
      @parens_group = []
      @type_stack.push(ScalarValue)
    elsif token.group_start?
      # neither arguments or subscripts; just a grouping parens
      @operator_stack.push(token)
      @parens_stack << @parens_group
      @parens_group = []
      @type_stack.push(ScalarValue)
    elsif token.separator?
      # pop the operator stack until the corresponding left paren is found
      # Append each operator to the end of the output list
      stack_to_expression(@operator_stack, @current_expression)
      @parens_group << @current_expression
      @current_expression = []
    elsif token.group_end?
      # pop the operator stack until the corresponding left paren is removed
      # Append each operator to the end of the output list
      stack_to_expression(@operator_stack, @current_expression)
      @parens_group << @current_expression
      start_op = @operator_stack.pop  # remove the '(' or '[' starter
      if start_op.param_start?
        list = List.new(@parens_group)
        @operator_stack.push(list)
        @current_expression = @expression_stack.pop
      end
      @parens_group = @parens_stack.pop
      @type_stack.pop
    elsif token.operator?
      # remove operators already on the stack that have higher
      # or equal precedence
      # append them to the output list
      stack_to_precedence(@operator_stack, @current_expression, token)
      # push the operator onto the operator stack
      @operator_stack.push(token) unless token.terminal?
    elsif token.function?
      # remove operators already on the stack that have higher
      # or equal precedence
      # append them to the output list
      stack_to_precedence(@operator_stack, @current_expression, token)
      # push the function onto the operator stack
      @operator_stack.push(token)
    elsif token.variable?
      # remove operators already on the stack that have higher
      # or equal precedence
      # append them to the output list
      stack_to_precedence(@operator_stack, @current_expression, token)
      # push the variable onto the operator stack
      variable_name = @type_stack[-1].new(token)
      @operator_stack.push(variable_name)
    else
      # the token is an operand, append it to the output list
      @current_expression << token
    end
    @previous_token = token
  end

  def expressions
    fail(BASICException, 'Expression error') if @operator_stack.size > 0
    @parsed_expressions << @current_expression
    @parsed_expressions
  end

  def stack_to_expression(stack, expression)
    until stack[-1].starter?
      op = stack.pop
      expression << op
      fail(BASICException, 'Expression error') if stack.size == 0
    end
  end

  def stack_to_precedence(stack, expression, token)
    while stack.size > 0 &&
          !stack[-1].starter? &&
          stack[-1].precedence >= token.precedence
      op = stack.pop
      expression << op
    end
  end
end

# base class for expressions
class AbstractExpression
  def initialize(text, default_type)
    fail(Exception, 'Expression cannot be empty') if text.length == 0
    @unparsed_expression = text

    split_words = split_input(text)
    # we have split a value like '12E+3' into three parts (12E + 3)
    # put them back into a single item
    words = regroup(split_words)
    tokens = tokenize(words)
    parser = Parser.new(default_type)
    tokens.each do |token|
      parser.parse(token)
    end
    @parsed_expressions = parser.expressions
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  # returns an Array of values
  def evaluate(interpreter)
    values = eval_scalar(interpreter, @parsed_expressions)
    fail(Exception, 'Expected some values') if values.length == 0
    values
  end

  private

  def split_input(text)
    # split the input infix string
    parts = text.split(%r{([\+\-\*\/\(\)\^,])})
    # remove empty elements
    parts.reject(&:empty?)
  end

  def regroup(short_parts)
    regrouped_parts = []
    while short_parts.size > 0
      first_three = short_parts[0..2].join('')
      if short_parts.size >= 3 && NumericConstant.init?(first_three)
        regrouped_parts << first_three
        short_parts = short_parts[3..-1]
      else
        regrouped_parts << short_parts[0]
        short_parts = short_parts[1..-1]
      end
    end
    regrouped_parts
  end

  def tokenize(words)
    tokens = []
    # convert tokens to objects
    words.each do |word|
      follows_operand = tokens.size > 0 && tokens[-1].operand?
      tokens << make_token(word, follows_operand)
    end
    tokens << TerminalOperator.new
  end

  def make_token(word, follows_operand)
    ff = FunctionFactory.new
    return ff.make(word) if ff.valid?(word)

    token = nil
    classes = follows_operand ? binary_classes : unary_classes
    classes.each do |c|
      token = c.new(word) if token.nil? && c.init?(word)
    end
    fail(BASICException, "'#{word}' is not a value or operator") if token.nil?
    token
  end

  def binary_classes
    # first match is used; select order with care
    # UserFunction before VariableName
    [
      GroupStart,
      GroupEnd,
      ParamSeparator,
      BinaryOperator,
      NumericConstant,
      UserFunction,
      VariableName
    ]
  end

  def unary_classes
    # first match is used; select order with care
    # UserFunction before VariableName
    [
      GroupStart,
      GroupEnd,
      ParamSeparator,
      UnaryOperator,
      NumericConstant,
      UserFunction,
      VariableName
    ]
  end
end

# Value scalar expression (an R-value)
class ValueScalarExpression < AbstractExpression
  def initialize(text)
    super(text, ScalarValue)
  end

  def printable?
    true
  end

  def print(printer, interpreter)
    numeric_constants = evaluate(interpreter)
    numeric_constant = numeric_constants[0]
    numeric_constant.print(printer)
  end
end

# Value matrix expression (an R-value)
class ValueMatrixExpression < AbstractExpression
  def initialize(text)
    super(text, MatrixValue)
  end

  def printable?
    true
  end

  def print(printer, interpreter, carriage)
    matrices = evaluate(interpreter)
    matrix = matrices[0]
    matrix.print(printer, interpreter, carriage)
  end
end

# Target expression
class TargetExpression < AbstractExpression
  def initialize(text, type)
    super(text, ScalarValue)

    check_length
    check_all_lengths
    check_resolve_types

    @parsed_expressions.each do |parsed_expression|
      parsed_expression[-1] = type.new(parsed_expression[-1])
    end
  end

  private

  def check_length
    fail(BASICException, 'Value list is empty (length 0)') if
      @parsed_expressions.length == 0
  end

  def check_all_lengths
    @parsed_expressions.each do |parsed_expression|
      fail(BASICException, 'Value is not assignable (length 0)') if
        parsed_expression.length == 0
    end
  end

  def check_resolve_types
    @parsed_expressions.each do |parsed_expression|
      fail(BASICException,
           "Value is not assignable (type #{parsed_expression[-1].class})") if
        parsed_expression[-1].class.to_s != 'ScalarValue'
    end
  end
end

# User function definition
# Define the user function name, arguments, and expression
class UserFunctionDefinition
  attr_reader :name
  attr_reader :arguments
  attr_reader :template

  def initialize(text)
    # parse into name '=' expression
    parts = text.split('=', 2)
    fail(BASICException, "'#{text}' is not a valid assignment") if
      parts.size != 2
    user_function_prototype = UserFunctionPrototype.new(parts[0])
    @name = user_function_prototype.name
    @arguments = user_function_prototype.arguments
    @template = ValueScalarExpression.new(parts[1])
  end
end

# User function prototype
# Define the user function name and arguments
class UserFunctionPrototype
  attr_reader :name
  attr_reader :arguments

  def initialize(text)
    fail(BASICException, "Invalid function specification #{text}") unless
      /\AFN[A-Z]\([A-Z](,[A-Z])*\)\z/.match(text)
    @name = text[0..2]
    args = text[4..-2]
    @arguments = args.split(',')
    # arguments must be unique
    fail(BASICException, 'Duplicate parameters') unless
      @arguments.uniq.size == @arguments.size
  end

  def to_s
    @name
  end
end

# Boolean expression
class BooleanExpression
  attr_reader :operator
  attr_reader :a_value
  attr_reader :b_value
  attr_reader :result

  def initialize(text)
    parts = text.split(/([=<>]+)/)
    fail(BASICException, "'#{text}' is not a boolean expression") if
      parts.size != 3
    @operators = make_operators

    @a = ValueScalarExpression.new(parts[0])
    @a_value = 'undefined'
    @operator = make_boolean_operator(parts[1])
    @b = ValueScalarExpression.new(parts[2])
    @b_value = 'undefined'
    @result = 'undefined'
  end

  def evaluate(interpreter)
    avs = @a.evaluate(interpreter)
    @a_value = avs[0]
    bvs = @b.evaluate(interpreter)
    @b_value = bvs[0]
    @result = @operator.evaluate(@a_value, @b_value)
  end

  def to_s
    @a.to_s + ' ' + @operator.to_s + ' ' + @b.to_s
  end

  private

  def make_operators
    {
      '=' => BooleanOperatorEq,
      '<>' => BooleanOperatorNotEq,
      '>' => BooleanOperatorGreater,
      '>=' => BooleanOperatorGreaterEq,
      '<' => BooleanOperatorLess,
      '<=' => BooleanOperatorLessEq
    }
  end

  def make_boolean_operator(text)
    fail(BASICException, "'#{text}' is not an operator") unless
      @operators.key?(text)

    @operators[text].new
  end
end

# Abstract assignment
class AbstractAssignment
  def initialize(text)
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    fail(BASICException, "'#{text}' is not a valid assignment") if
      parts.size != 2
  end

  def count_target
    @target.count
  end

  def eval_target(interpreter)
    @target.evaluate(interpreter)
  end

  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end

  def to_postfix_s
    @expression.to_postfix_s
  end
end

# An assignment (part of a LET statement)
class ScalarAssignment < AbstractAssignment
  def initialize(text)
    super
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    @target = TargetExpression.new(parts[0], ScalarReference)
    @expression = ValueScalarExpression.new(parts[1])
  end

  def count_value
    @expression.count
  end

  def eval_value(interpreter)
    @expression.evaluate(interpreter)
  end
end

# An assignment (part of a MAT LET statement)
class MatrixAssignment < AbstractAssignment
  def initialize(text)
    super
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    @target = TargetExpression.new(parts[0], MatrixReference)
    @functions = {
      'CON' => FunctionCon,
      'ZER' => FunctionZer,
      'IDN' => FunctionIdn
    }
    @special_form = @functions.key?(parts[1])
    if @special_form
      @expression = parts[1]
    else
      @expression = ValueMatrixExpression.new(parts[1])
    end
  end

  def count_value
    if @special_form
      1
    else
      @expression.count
    end
  end

  def eval_value(interpreter)
    if @special_form
      # special form obtains variable name and dimensions at run-time
      vs = @target.evaluate(interpreter)
      v = vs[0]
      fail(Exception, 'Expected matrix reference') if
        v.class.to_s != 'MatrixReference'
      name = v.name
      dims = interpreter.get_dimensions(name)

      f = @functions[@expression].new('')
      matrix = f.evaluate(interpreter, [dims])
      [matrix]
    else
      @expression.evaluate(interpreter)
    end
  end
end
