# Scalar function (provides a scalar)
class Function < AbstractElement
  def initialize(text)
    super()
    @name = text
    @function = true
    @operand = true
    @precedence = 7
  end

  private

  def ensure_argument_count(stack, expected)
    raise(BASICException, @name + ' requires argument') unless
      previous_is_array(stack)
    valid = counts_to_text(expected)
    raise(BASICException, @name + ' requires ' + valid + ' argument') unless
      expected.include? stack[-1].size
  end

  def counts_to_text(counts)
    words = %w(zero one two)
    texts = counts.map { |v| words[v] }
    texts.join(' or ')
  end

  def check_args(args)
    raise(BASICException, 'No arguments for function') if
      args.class.to_s != 'Array'
  end

  def check_value(value, type)
    compatible = false
    case type
    when 'numeric'
      compatible = value.numeric_constant?
    when 'array'
      compatible = value.array?
    when 'matrix'
      compatible = value.matrix?
    end

    raise(BASICException, "Type mismatch value #{value} not #{type}") unless
      compatible
  end

  def check_arg_types(args, types)
    check_args(args)
    if args.size != types.size
      raise(BASICException,
            "Function #{@name} expects #{n_types} argument, found #{n_args}")
    end
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

  def check_square(dims)
    raise(BASICException, @name + ' requires matrix') unless dims.size == 2
    raise(BASICException, @name + ' requires square matrix') unless
      dims[1] == dims[0]
  end
end

# User-defined function (provides a scalar value)
class UserFunction < AbstractScalarFunction
  def self.accept?(token)
    classes = %w(UserFunctionToken)
    classes.include?(token.class.to_s)
  end

  def self.init?(text)
    /\AFN[A-Z]\z/.match(text)
  end

  def initialize(text)
    text = text.to_s if text.class.to_s == 'UserFunctionToken'
    raise(BASICException, "'#{text}' is not a valid function") unless
      UserFunction.init?(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    expression = interpreter.get_user_function(@name)
    # verify function is defined
    raise(BASICException, "Function #{@name} not defined") if expression.nil?

    # verify arguments
    user_var_values = stack.pop
    raise(BASICException, 'No arguments for function') if
      user_var_values.class.to_s != 'Array'
    check_arg_types(user_var_values,
                    ['numeric'] * user_var_values.length)

    # dummy variable names and their (now known) values
    result = expression.evaluate_with_vars(interpreter, @name, user_var_values)
    result[0]
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    interpreter.int_floor? ? args[0].floor : args[0].truncate
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    stack.push([NumericConstant.new(1)]) unless previous_is_array(stack)
    ensure_argument_count(stack, [0, 1])
    args = stack.pop
    args = [NumericConstant.new(1)] if args.empty? || args[0].nil?
    check_arg_types(args, ['numeric'])
    interpreter.rand(args[0])
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].exp
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].log
  end
end

# function ABS
class FunctionAbs < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].abs
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].sqrt
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].sin
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].cos
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].tan
  end
end

# function ATN
class FunctionAtn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].atn
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['numeric'])
    args[0].sign
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['matrix'])
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
    ensure_argument_count(stack, [1, 2])
    args = stack.pop
    check_arg_types(args, ['numeric'] * args.size)
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
    ensure_argument_count(stack, [1, 2])
    args = stack.pop
    check_arg_types(args, ['numeric'] * args.size)
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
    ensure_argument_count(stack, [1, 2])
    args = stack.pop
    check_arg_types(args, ['numeric'] * args.size)
    check_square(args) if args.size == 2
    dims = [args[0]] * 2
    matrix = Matrix.new(dims, {})
    Matrix.new(dims, matrix.identity_values)
  end

  private

  def check_square(dims)
    raise(BASICException, @name + ' requires matrix') unless dims.size == 2
    raise(BASICException, @name + ' requires square matrix') unless
      dims[1] == dims[0]
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['matrix'])
    args[0].determinant
  end
end

# function INV
class FunctionInv < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    dims = args[0].dimensions
    check_arg_types(args, ['matrix'])
    check_square(dims)
    Matrix.new(dims.clone, args[0].inverse_values)
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
