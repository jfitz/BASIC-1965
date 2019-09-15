# function (provides a scalar)
class AbstractFunction < AbstractElement
  def initialize(text)
    super()

    @name = text
    @function = true
    @valref = :value
    @operand = true
    @precedence = 7
  end

  def dump
    self.class.to_s
  end

  def to_s
    @name
  end

  def value?
    @valref == :value
  end

  def reference?
    @valref == :reference
  end
  
  private

  def default_args(interpreter)
    arg = interpreter.default_args(@name)

    raise(BASICRuntimeError, "#{@name} requires arguments") if
      arg.nil?

    arg
  end

  def counts_to_text(counts)
    words = %w(zero one two)
    texts = counts.map { |v| words[v] }
    texts.join(' or ')
  end

  def match_arg_type(value, type)
    case type
    when :numeric
      compatible = value.numeric_constant?
    else
      compatible = false
    end

    compatible
  end

  def match_arg_shape(value, shape)
    case shape
    when :scalar
      compatible = value.scalar?
    when :array
      compatible = value.array?
    when :matrix
      compatible = value.matrix?
    else
      compatible = false
    end

    compatible
  end

  def match_arg_type_shape(value, spec)
    type = spec['type']
    type_compatible = match_arg_type(value, type)

    shape = spec['shape']
    shape_compatible = match_arg_shape(value, shape)

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
class AbstractScalarFunction < AbstractFunction
  def initialize(text)
    super
  end

  def default_shape
    :scalar
  end
end

# Function that expects array parameters
class AbstractArrayFunction < AbstractFunction
  def initialize(text)
    super
  end

  def default_shape
    :array
  end
end

# Function that expects matrix parameters
class AbstractMatrixFunction < AbstractFunction
  def initialize(text)
    super
  end

  def default_shape
    :matrix
  end

  def check_square(dims)
    raise(BASICRuntimeError, @name + ' requires matrix') unless dims.size == 2
    raise(BASICRuntimeError, @name + ' requires square matrix') unless
      dims[1] == dims[0]
  end
end

# User-defined function (provides a scalar value)
class UserFunction < AbstractScalarFunction
  attr_writer :valref

  def self.accept?(token)
    classes = %w(UserFunctionToken)
    classes.include?(token.class.to_s)
  end

  def initialize(text)
    super
    @user_function = true
    @shape = :scalar
  end

  def to_s
    @name.to_s
  end

  def content_type
    :numeric
  end

  def compatible?(value)
    numerics = [:numeric, :integer]
    strings = [:string]

    compatible = false

    if content_type == :numeric
      compatible = numerics.include?(value.content_type)
    end

    if content_type == :string
      compatible = strings.include?(value.content_type)
    end

    if content_type == :integer
      compatible = numerics.include?(value.content_type)
    end

    compatible
  end

  # return a single value
  def evaluate(interpreter, stack)
    x = false
    x = evaluate_value(interpreter, stack) if @valref == :value
    x = evaluate_ref(interpreter, stack) if @valref == :reference
    x
  end

  private

  # return a single value
  def evaluate_value(interpreter, stack)
    definition = interpreter.get_user_function(@name)

    # verify function is defined
    raise(BASICRuntimeError, "Function #{@name} not defined") if definition.nil?

    signature = definition.signature

    # verify arguments
    arguments = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(arguments, signature)

    # dummy variable names and their (now known) values
    params = definition.arguments
    param_names_values = params.zip(arguments)
    names_and_values = Hash[param_names_values]
    interpreter.define_user_var_values(names_and_values)

    expression = definition.expression
    results = expression.evaluate(interpreter)

    interpreter.clear_user_var_values
    results[0]
  end

  def evaluate_ref(interpreter, stack)
    x = nil
    x = evaluate_ref_scalar(interpreter, stack) if @shape == :scalar

    x = evaluate_ref_compound(interpreter, stack) if
      @shape == :array || @shape == :matrix
    x
  end
  
  # return a single value, a reference to this object
  def evaluate_ref_scalar(interpreter, stack)
    if previous_is_array(stack)
      subscripts = stack.pop
      @subscripts = interpreter.normalize_subscripts(subscripts)
      num_args = @subscripts.length

      if num_args.zero?
        raise(BASICRuntimeError,
              'Variable expects subscripts, found empty parentheses')
      end

      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end

  # return a single value, a reference to this object
  def evaluate_ref_compound(interpreter, stack)
    if previous_is_array(stack)
      subscripts = stack.pop
      @subscripts = interpreter.normalize_subscripts(subscripts)
      num_args = @subscripts.length

      if num_args.zero?
        raise(BASICRuntimeError,
              'Variable expects subscripts, found empty parentheses')
      end

      interpreter.check_subscripts(@variable_name, @subscripts)
    end

    self
  end
end

# function ABS
class FunctionAbs < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].abs
  end
end

# function ATN
class FunctionAtn < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  def evaluate(_, stack)
    args = stack.pop

    if match_args_to_signature(args, @signature_1)
      args[0].atn
    elsif match_args_to_signature(args, @signature_2)
      args[0].atn2(args[1])
    else
      raise(BASICRuntimeError, 'Wrong arguments for function')
    end
  end
end

# function CON
class FunctionCon < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
  end

  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      args = stack.pop

      if match_args_to_signature(args, @signature_0)
        arg = default_args(interpreter)
        matrix = Matrix.new(arg.clone, {})
        Matrix.new(matrix.dimensions, matrix.one_values)
      elsif match_args_to_signature(args, @signature_1)
        matrix = Matrix.new(args.clone, {})
        Matrix.new(matrix.dimensions, matrix.one_values)
      elsif match_args_to_signature(args, @signature_2)
        matrix = Matrix.new(args.clone, {})
        Matrix.new(matrix.dimensions, matrix.one_values)
      else
        raise(BASICRuntimeError, 'Wrong arguments for function')
      end
    else
      arg = default_args(interpreter)
      matrix = Matrix.new(arg.clone, {})
      Matrix.new(matrix.dimensions, matrix.one_values)
    end
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].cos
  end
end

# function COT
class FunctionCot < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].cot
  end
end

# function CSC
class FunctionCsc < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].csc
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].determinant
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].exp
  end
end

# function FRA
class FunctionFra < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0] - args[0].truncate
  end
end

# function IDN
class FunctionIdn < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
  end

  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      args = stack.pop

      if match_args_to_signature(args, @signature_0)
        arg = default_args(interpreter)
        matrix = Matrix.new(arg.clone, {})
        Matrix.new(matrix.dimensions, matrix.one_values)
      elsif match_args_to_signature(args, @signature_1)
        dims = [args[0]] * 2
        matrix = Matrix.new(dims, {})
        Matrix.new(dims, matrix.identity_values)
      elsif match_args_to_signature(args, @signature_2)
        raise(BASICRuntimeError, @name + ' requires square matrix') unless
          args[1] == args[0]

        matrix = Matrix.new(args, {})
        Matrix.new(args, matrix.identity_values)
      else
        raise(BASICRuntimeError, 'Wrong arguments for function')
      end
    else
      arg = default_args(interpreter)
      raise(BASICRuntimeError, @name + ' requires square matrix') unless
        arg.size == 2 && arg[1] == arg[0]

      matrix = Matrix.new(arg.clone, {})
      Matrix.new(matrix.dimensions, matrix.identity_values)
    end
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    interpreter.int_floor? ? args[0].floor : args[0].truncate
  end
end

# function INV
class FunctionInv < AbstractMatrixFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    dims = args[0].dimensions
    check_square(dims)
    Matrix.new(dims.clone, args[0].inverse_values)
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].log
  end
end

# function MOD
class FunctionMod < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].mod(args[1])
  end
end

# function ROUND
class FunctionRound < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].round(args[1])
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  # return a single value
  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      args = stack.pop

      if match_args_to_signature(args, @signature_0)
        arg = default_args(interpreter)
        interpreter.rand(arg)
      elsif match_args_to_signature(args, @signature_1)
        interpreter.rand(args[0])
      else
        raise(BASICRuntimeError, 'Wrong arguments for function')
      end
    else
      arg = default_args(interpreter)
      interpreter.rand(arg)
    end
  end
end

# function SEC
class FunctionSec < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].sec
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].sign
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].sin
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].sqrt
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    args[0].tan
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super

    @signature = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, stack)
    args = stack.pop

    raise(BASICRuntimeError, 'Wrong arguments for function') unless
      match_args_to_signature(args, @signature)

    dims = args[0].dimensions
    new_dims = [dims[1], dims[0]]
    Matrix.new(new_dims, args[0].transpose_values)
  end
end

# function ZER
class FunctionZer < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
  end

  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      args = stack.pop

      if match_args_to_signature(args, @signature_0)
        arg = default_args(interpreter)
        matrix = Matrix.new(arg.clone, {})
        Matrix.new(matrix.dimensions, matrix.zero_values)
      elsif match_args_to_signature(args, @signature_1)
        matrix = Matrix.new(args.clone, {})
        Matrix.new(matrix.dimensions, matrix.zero_values)
      elsif match_args_to_signature(args, @signature_2)
        matrix = Matrix.new(args.clone, {})
        Matrix.new(matrix.dimensions, matrix.zero_values)
      else
        raise(BASICRuntimeError, 'Wrong arguments for function')
      end
    else
      arg = default_args(interpreter)
      matrix = Matrix.new(arg.clone, {})
      Matrix.new(matrix.dimensions, matrix.zero_values)
    end
  end
end

# class to make functions, given the name
class FunctionFactory
  @functions = {
    'ABS' => FunctionAbs,
    'ATN' => FunctionAtn,
    'CON' => FunctionCon,
    'COS' => FunctionCos,
    'COT' => FunctionCot,
    'CSC' => FunctionCsc,
    'DET' => FunctionDet,
    'EXP' => FunctionExp,
    'FRA' => FunctionFra,
    'IDN' => FunctionIdn,
    'INT' => FunctionInt,
    'INV' => FunctionInv,
    'LOG' => FunctionLog,
    'MOD' => FunctionMod,
    'RND' => FunctionRnd,
    'ROUND' => FunctionRound,
    'SEC' => FunctionSec,
    'SGN' => FunctionSgn,
    'SIN' => FunctionSin,
    'SQR' => FunctionSqr,
    'TAN' => FunctionTan,
    'TRN' => FunctionTrn,
    'ZER' => FunctionZer
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

  def self.user_function_names
    ('FNA'..'FNZ').to_a
  end
end
