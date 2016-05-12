# accept any characters
class InvalidTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    @token += text.size > 0 ? text[0] : ''
  end

  def count
    @token.size
  end
end

# accept characters to match item in list
class ListTokenizer
  attr_reader :token

  def initialize(legals)
    @legals = legals
  end

  def try(text)
    @token = ''
    @legals.each do |legal|
      @token = legal if text.start_with?(legal) && legal.size > @token.size
    end
  end

  def count
    @token.size
  end
end

# token reader for text constants
class TextTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    /\A".*?"/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end
end

# token reader for numeric constants
class NumberTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    /\A\d+(\.\d+)?(E[+-]?\d+)?/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end
end

# token reader for variables
class VariableTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    /\A[A-Z]/.match(text) { |m| @token = m[0] }
    /\A[A-Z]\d/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end
end

# Hold a variable name (not a reference or value)
class VariableName < AbstractElement
  def self.init?(text)
    /\A[A-Z]\d?\z/.match(text)
  end

  def initialize(text)
    super()
    fail(BASICException, "'#{text}' is not a variable name") unless
      text.class.to_s == 'VariableToken' || VariableName.init?(text)
    @var_name = text
    @variable = true
    @operand = true
    @precedence = 6
  end

  def eql?(other)
    @var_name == other.to_s
  end

  def ==(other)
    @var_name.to_s == other.to_s
  end

  def hash
    @var_name.hash
  end

  def to_s
    @var_name.to_s
  end
end

# Hold a variable (name with possible subscripts and value)
class Variable < AbstractElement
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

  def values_1
    values = {}
    (1..@dimensions[0].to_i).each do |col|
      value = get_value_1(col)
      coords = make_coord(col)
      values[coords] = value
    end
    values
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
    new_values = submatrix_values(exclude_row, exclude_col)
    Matrix.new(new_dims, new_values)
  end

  def submatrix_values(exclude_row, exclude_col)
    new_values = {}
    new_row = 1
    (1..@dimensions[0].to_i).each do |row|
      new_col = 1
      next if row == exclude_row
      (1..@dimensions[1].to_i).each do |col|
        next if col == exclude_col
        new_values[make_coords(new_row, new_col)] = get_value_2(row, col)
        new_col += 1
      end
      new_row += 1
    end
    new_values
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
    values = evaluate_n(interpreter, dims)
    Matrix.new(dims, values)
  end

  private

  def evaluate_n(interpreter, dims)
    values = {}
    values = evaluate_1(interpreter, dims[0].to_i) if dims.size == 1
    values = evaluate_2(interpreter, dims[0].to_i, dims[1].to_i) if
      dims.size == 2
    values
  end

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
class List < AbstractElement
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
class Function < AbstractElement
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
    check(args)
    dims = [args[0]] * 2
    matrix = Matrix.new(dims, {})
    Matrix.new(dims, matrix.identity_values)
  end

  private

  def check(args)
    fail(BASICException, 'One or two arguments required for IDN()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    fail(BASICException, 'IDN requires square matrix') if
      args.size == 2 && args[1] != args[0]
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
    check(args)
    dims = args[0].dimensions
    check_2(dims)
    Matrix.new(dims.clone, args[0].inverse_values)
  end

  private

  def check(args)
    fail(BASICException, 'One argument required for INV()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
  end

  def check_2(dims)
    fail(BASICException, 'INV requires matrix') unless dims.size == 2
    fail(BASICException, 'INV requires square matrix') if dims[1] != dims[0]
  end
end

# class to make functions, given the name
class FunctionFactory
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

  def self.valid?(text)
    @functions.key?(text)
  end

  def self.make(text)
    @functions[text].new(text) if @functions.key?(text)
  end

  def self.function_names
    @functions.keys
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

    # verify arguments
    user_var_values = stack.pop
    fail(BASICException, 'No arguments for function') if
      user_var_values.class.to_s != 'Array'
    check_arg_types(user_var_values,
                    ['NumericConstant'] * user_var_values.length)

    # dummy variable names and their (now known) values
    result = expression.evaluate_with_vars(interpreter, @name, user_var_values)
    result[0]
  end
end

# returns an Array of values
def eval_scalar(interpreter, parsed_expressions)
  # expected = parsed_expressions[0].length
  result_values = []
  parsed_expressions.each do |parsed_expression|
    stack = []
    parsed_expression.each do |element|
      value = element.evaluate(interpreter, stack)
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
    @previous_element = InitialOperator.new
  end

  def parse(element)
    fail(BASICException, 'Function requires parentheses') if
      !element.group_start? && @previous_element.function?

    if element.group_separator?
      group_separator(element)
    elsif element.operator?
      operator_higher(element)
    elsif element.function_variable?
      function_variable(element)
    else
      # the element is an operand, append it to the output list
      @current_expression << element
    end

    @previous_element = element
  end

  def expressions
    fail(BASICException, 'Expression error') if @operator_stack.size > 0
    @parsed_expressions.concat @parens_group if @parens_group.size > 0
    @parsed_expressions << @current_expression
    @parsed_expressions
  end

  private

  def stack_to_expression(stack, expression)
    until stack.size == 0 || stack[-1].starter?
      op = stack.pop
      expression << op
    end
  end

  def stack_to_precedence(stack, expression, element)
    while stack.size > 0 &&
          !stack[-1].starter? &&
          stack[-1].precedence >= element.precedence
      op = stack.pop
      expression << op
    end
  end

  def group_separator(element)
    if element.group_start?
      start_group(element)
    elsif element.separator?
      pop_to_group_start
    elsif element.group_end?
      end_group
    end
  end

  def start_group(element)
    if @previous_element.function?
      start_associated_group(@previous_element.default_type)
    elsif @previous_element.variable?
      start_associated_group(ScalarValue)
    else
      start_simple_group(element)
    end
  end

  # a group associated with a function or variable
  # (arguments or subscripts)
  def start_associated_group(type)
    @expression_stack.push(@current_expression)
    @current_expression = []
    @operator_stack.push(ParamStart.new)
    @parens_stack << @parens_group
    @parens_group = []
    @type_stack.push(type)
  end

  def start_simple_group(element)
    @operator_stack.push(element)
    @parens_stack << @parens_group
    @parens_group = []
    @type_stack.push(ScalarValue)
  end

  # pop the operator stack until the corresponding left paren is found
  # Append each operator to the end of the output list
  def pop_to_group_start
    stack_to_expression(@operator_stack, @current_expression)
    @parens_group << @current_expression
    @current_expression = []
  end

  # pop the operator stack until the corresponding left paren is removed
  # Append each operator to the end of the output list
  def end_group
    stack_to_expression(@operator_stack, @current_expression)
    @parens_group << @current_expression
    fail(BASICException, 'Expression error') if @operator_stack.size == 0
    start_op = @operator_stack.pop  # remove the '(' or '[' starter
    if start_op.param_start?
      list = List.new(@parens_group)
      @operator_stack.push(list)
      @current_expression = @expression_stack.pop
    end
    @parens_group = @parens_stack.pop
    @type_stack.pop
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def operator_higher(element)
    stack_to_precedence(@operator_stack, @current_expression, element)
    # push the operator onto the operator stack
    @operator_stack.push(element) unless element.terminal?
  end

  def function_variable(element)
    if element.function?
      start_function(element)
    elsif element.variable?
      start_variable(element)
    end
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_function(element)
    stack_to_precedence(@operator_stack, @current_expression, element)
    # push the function onto the operator stack
    @operator_stack.push(element)
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_variable(element)
    stack_to_precedence(@operator_stack, @current_expression, element)
    # push the variable onto the operator stack
    variable_name = @type_stack[-1].new(element)
    @operator_stack.push(variable_name)
  end
end

# base class for expressions
class AbstractExpression
  def initialize(text, tokens, default_type)
    if tokens.nil?
      fail(Exception, 'Expression cannot be empty') if text.length == 0
      @unparsed_expression = text
    else
      fail(Exception, 'Expression cannot be empty') if tokens.length == 0
      @unparsed_expression = tokens.map { |token| "#{token}" }.join
    end

    if tokens.nil?
      split_words = split_input(text)
      # we have split a value like '12E+3' into three parts (12E + 3)
      # put them back into a single item
      words = regroup(split_words)
      elements = elementize(words)
    else
      elements = []
      tokens.each do |token|
        follows_operand = elements.size > 0 && elements[-1].operand?
        elements << token_to_element(token, follows_operand)
      end
      elements << TerminalOperator.new
    end
    parser = Parser.new(default_type)
    elements.each do |element|
      parser.parse(element)
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

  def evaluate_with_vars(interpreter, name, user_var_values)
    interpreter.set_user_var_values(name, user_var_values)
    result = evaluate(interpreter)
    interpreter.clear_user_var_values
    result
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

  def elementize(words)
    elements = []
    # convert elements to objects
    words.each do |word|
      follows_operand = elements.size > 0 && elements[-1].operand?
      elements << make_element(word, follows_operand)
    end
    elements << TerminalOperator.new
  end

  def make_element(word, follows_operand)
    return FunctionFactory.make(word) if FunctionFactory.valid?(word)

    element = nil
    classes = follows_operand ? binary_classes : unary_classes
    classes.each do |c|
      element = c.new(word) if element.nil? && c.init?(word)
    end
    fail(BASICException, "'#{word}' is not a value or operator") if element.nil?
    element
  end

  def token_to_element(token, follows_operand)
    return FunctionFactory.make(token.to_s) if
      FunctionFactory.valid?(token.to_s)

    element = nil
    classes = follows_operand ? binary_classes : unary_classes
    classes.each do |c|
      element = c.new(token.to_s) if element.nil? && c.init?(token.to_s)
    end
    fail(BASICException, "Token '#{token}' is not a value or operator") if element.nil?
    element
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
      VariableName,
      TextConstant
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
      VariableName,
      TextConstant
    ]
  end
end

# Value scalar expression (an R-value)
class ValueScalarExpression < AbstractExpression
  def initialize(text, tokens)
    super(text, tokens, ScalarValue)
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
  def initialize(tokens)
    super(nil, tokens, MatrixValue)
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
  def initialize(tokens, type)
    super(nil, tokens, ScalarValue)

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
    tokens = nil
    @template = ValueScalarExpression.new(parts[1], tokens)
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

  def initialize(tokens)
    parts = split_tokens(tokens)
    fail(BASICException, "'#{tokens}' is not a boolean expression") if
      parts.size != 3

    @a = ValueScalarExpression.new(nil, parts[0])
    @a_value = 'undefined'
    @operator = make_boolean_operator(parts[1])
    @b = ValueScalarExpression.new(nil, parts[2])
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

  def evaluated_to_s
    @a_value.to_s + ' ' + @operator.to_s + ' ' + @b_value.to_s
  end

  private

  def split_tokens(tokens)
    results = []
    nonkeywords = []
    tokens.each do |token|
      if token.operator? && token.comparison?
        results << nonkeywords if nonkeywords.size > 0
        nonkeywords = []
        results << token
      else
        nonkeywords << token
      end
    end
    results << nonkeywords if nonkeywords.size > 0
    results
  end

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

  def make_boolean_operator(token)
    operators = make_operators
    fail(BASICException, "'#{token}' is not an operator") unless
      operators.key?(token.to_s)

    operators[token.to_s].new
  end
end

# Abstract assignment
class AbstractAssignment
  def initialize(tokens)
    # parse into variable, '=', expression
    token_lists = split_tokens(tokens)
    line_text = tokens.map { |token| token.to_s }.join
    fail(BASICException, "'#{line_text}' is not a valid assignment") if
      token_lists.size != 3 || !(token_lists[1].operator? && token_lists[1].equals?)
  end

  def split_tokens(tokens)
    results = []
    nonkeywords = []
    tokens.each do |token|
      if token.operator? && token.equals?
        results << nonkeywords if nonkeywords.size > 0
        nonkeywords = []
        results << token
      else
        nonkeywords << token
      end
    end
    results << nonkeywords if nonkeywords.size > 0
    results
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
  def initialize(tokens)
    super
    # parse into variable, '=', expression
    token_lists = split_tokens(tokens)
    fail(BASICException, 'Bad assignment') if token_lists.size != 3
    @target = TargetExpression.new(token_lists[0], ScalarReference)
    @expression = ValueScalarExpression.new(nil, token_lists[2])
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
  def initialize(tokens)
    super
    # parse into variable, '=', expression
    token_lists = split_tokens(tokens)
    fail(BASICException, 'Bad assignment') if token_lists.size != 3
    @target = TargetExpression.new(token_lists[0], MatrixReference)
    @functions = {
      'CON' => FunctionCon,
      'ZER' => FunctionZer,
      'IDN' => FunctionIdn
    }
    @special_form = token_lists[2].size == 1 && @functions.key?(token_lists[2][0].to_s)
    if @special_form
      @expression = token_lists[2][0].to_s
    else
      @expression = ValueMatrixExpression.new(token_lists[2])
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
