# function (provides a scalar)
class Function < AbstractElement
  def initialize(text)
    super()
    @name = text
    @function = true
    @operand = true
    @precedence = 7
  end

  private

  def counts_to_text(counts)
    words = %w(zero one two)
    texts = counts.map { |v| words[v] }
    texts.join(' or ')
  end

  def match_arg_type_shape(value, spec)
    type = spec['type']
    shape = spec['shape']

    type_compatible = false
    case type
    when 'numeric'
      type_compatible = value.numeric_constant?
    end

    shape_compatible = false
    case shape
    when 'scalar'
      shape_compatible = value.scalar?
    when 'array'
      shape_compatible = value.array?
    when 'matrix'
      shape_compatible = value.matrix?
    end

    type_compatible && shape_compatible
  end

  def match_args_to_signature(args, specs)
    n_args = 0
    n_args = args.size if args.class.to_s == 'Array'

    n_specs = specs.size

    return false if n_args != n_specs

    compatible = true
    (0..n_specs - 1).each do |i|
      compatible &&= match_arg_type_shape(args[i], specs[i])
    end

    compatible
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
    raise(BASICRuntimeError, "'#{text}' is not a valid function") unless
      UserFunction.init?(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack, trace)
    definition = interpreter.get_user_function(@name)
    # verify function is defined
    raise(BASICRuntimeError, "Function #{@name} not defined") if definition.nil?

    # verify arguments
    user_var_values = stack.pop

    spec = { 'type' => 'numeric', 'shape' => 'scalar' }
    specs = [spec] * user_var_values.length

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(user_var_values, specs)

    # dummy variable names and their (now known) values
    expression = definition.expression
    result = expression.evaluate_with_vars(interpreter, @name,
                                           user_var_values, trace)

    result[0]
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
    raise(BASICRuntimeError, @name + ' requires matrix') unless dims.size == 2
    raise(BASICRuntimeError, @name + ' requires square matrix') unless
      dims[1] == dims[0]
  end
end

# function ABS
class FunctionAbs < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].abs
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function ATN
class FunctionAtn < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].atn
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function CON
class FunctionCon < AbstractScalarFunction
  def initialize(text)
    super
    @signature_1 = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
    @signature_2 =
      [
        { 'type' => 'numeric', 'shape' => 'scalar' },
        { 'type' => 'numeric', 'shape' => 'scalar' }
      ]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature_1)
      matrix = Matrix.new(args.clone, {})
      Matrix.new(matrix.dimensions, matrix.one_values)
    elsif match_args_to_signature(args, @signature_2)
      matrix = Matrix.new(args.clone, {})
      Matrix.new(matrix.dimensions, matrix.one_values)
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].cos
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'matrix' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].determinant
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].exp
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function IDN
class FunctionIdn < AbstractScalarFunction
  def initialize(text)
    super
    @signature_1 = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
    @signature_2 =
      [
        { 'type' => 'numeric', 'shape' => 'scalar' },
        { 'type' => 'numeric', 'shape' => 'scalar' }
      ]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature_1)
      dims = [args[0]] * 2
      matrix = Matrix.new(dims, {})
      Matrix.new(dims, matrix.identity_values)
    elsif match_args_to_signature(args, @signature_2)
      raise(BASICRuntimeError, @name + ' requires square matrix') unless
        args[1] == args[0]
      dims = args
      matrix = Matrix.new(dims, {})
      Matrix.new(dims, matrix.identity_values)
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  # return a single value
  def evaluate(interpreter, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      interpreter.int_floor? ? args[0].floor : args[0].truncate
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function INV
class FunctionInv < AbstractMatrixFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'matrix' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      dims = args[0].dimensions
      check_square(dims)
      Matrix.new(dims.clone, args[0].inverse_values)
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].log
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  # return a single value
  def evaluate(interpreter, stack, _)
    stack.push([NumericConstant.new(1)]) unless previous_is_array(stack)
    args = stack.pop
    args = [NumericConstant.new(1)] if args.empty?
    if match_args_to_signature(args, @signature)
      interpreter.rand(args[0])
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].sign
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].sin
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].sqrt
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      args[0].tan
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super
    @signature = [{ 'type' => 'numeric', 'shape' => 'matrix' }]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature)
      dims = args[0].dimensions
      new_dims = [dims[1], dims[0]]
      Matrix.new(new_dims, args[0].transpose_values)
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function ZER
class FunctionZer < AbstractScalarFunction
  def initialize(text)
    super
    @signature_1 = [{ 'type' => 'numeric', 'shape' => 'scalar' }]
    @signature_2 =
      [
        { 'type' => 'numeric', 'shape' => 'scalar' },
        { 'type' => 'numeric', 'shape' => 'scalar' }
      ]
  end

  def evaluate(_, stack, _)
    args = stack.pop
    if match_args_to_signature(args, @signature_1)
      matrix = Matrix.new(args.clone, {})
      Matrix.new(matrix.dimensions, matrix.zero_values)
    elsif match_args_to_signature(args, @signature_2)
      matrix = Matrix.new(args.clone, {})
      Matrix.new(matrix.dimensions, matrix.zero_values)
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
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
