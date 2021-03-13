# function (provides a scalar)
class AbstractFunction < AbstractElement
  attr_reader :name
  attr_reader :default_shape
  attr_reader :content_type
  attr_reader :shape
  attr_reader :constant

  def initialize(text)
    super()

    @name = text
    @function = true
    @default_shape = :unknown
    @content_type = :numeric
    @shape = nil
    @constant = false
    @valref = :value
    @operand = true
    @precedence = 10
    @arg_types = nil
    @arg_shapes = []
    @arg_consts = []
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      types = type_stack.pop

      raise(BASICExpressionError, "Bad expression #{@name} #{type}") unless
        types.class.to_s == 'Array'

      @arg_types = types
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      my_shapes = shape_stack.pop

      raise(BASICExpressionError, "Bad expression #{@name} #{my_shape}") unless
        my_shapes.class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end
  
  def set_constant(constant_stack)
    unless constant_stack.empty?
      constants = constant_stack.pop

      raise(BASICExpressionError, "Bad expression #{@name} #{constants}") unless
        constants.class.to_s == 'Array'

      if constants.empty?
        @constant = false
      else
        @constant = true
        constants.each { |c| @constant &&= c }
      end
    end

    constant_stack.push(@constant)
  end

  def sigils
    make_sigils(@arg_types, @arg_shapes)
  end

  def signature
    make_signature(@arg_types, @arg_shapes)
  end

  def pop_stack(stack)
    stack.pop
  end

  def dump
    result = make_type_sigil(@content_type) + make_shape_sigil(@shape)
    const = @constant ? '=' : ''
    "#{self.class}:#{@name}#{signature} -> #{const}#{result}"
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

    raise(BASICSyntaxError, "#{@name} requires arguments") if arg.nil?

    arg
  end

  def counts_to_text(counts)
    words = %w[zero one two]
    texts = counts.map { |v| words[v] }
    texts.join(' or ')
  end

  def match_arg_type(value, type)
    case type
    when :numeric
      value.numeric_constant?
    when :string
      value.text_constant?
    when :integer
      value.numeric_constant?
    when :boolean
      value.boolean_constant?
    else
      false
    end
  end

  def match_arg_shape(value, shape)
    case shape
    when :scalar
      value.scalar?
    when :array
      value.array?
    when :matrix
      value.matrix?
    else
      false
    end
  end

  def match_arg_type_shape(value, spec)
    type = spec['type']
    type_compatible = match_arg_type(value, type)

    my_shape = spec['shape']
    shape_compatible = match_arg_shape(value, my_shape)

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

    @default_shape = :scalar
  end
end

# Function that expects array parameters
class AbstractArrayFunction < AbstractFunction
  def initialize(text)
    super

    @default_shape = :array
  end
end

# Function that expects matrix parameters
class AbstractMatrixFunction < AbstractFunction
  def initialize(text)
    super

    @default_shape = :matrix
  end

  def check_square(dims)
    raise(BASICSyntaxError, @name + ' requires matrix') unless dims.size == 2

    raise BASICRuntimeError.new(:te_mat_no_sq, @name) unless
      dims[1] == dims[0]
  end
end

# User-defined function (provides a scalar value)
class UserFunction < AbstractScalarFunction
  attr_writer :valref

  def self.accept?(token)
    classes = %w[UserFunctionToken]
    classes.include?(token.class.to_s)
  end

  def initialize(text)
    super

    @user_function = true
    @shape = :scalar
    @constant = false
  end

  def to_s
    @name.to_s
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constant_stack.pop if constant_stack[-1].class.to_s == 'Array'
    end

    # user function is never const, as it can be re-assigned
    @constant = false

    constant_stack.push(@constant)
  end

  def compatible?(value)
    numerics = %i[numeric integer]
    strings = %i[string]

    case content_type
    when :numeric
      numerics.include?(value.content_type)
    when :string
      strings.include?(value.content_type)
    when :integer
      numerics.include?(value.content_type)
    else
      false
    end
  end

  def evaluate(interpreter, arg_stack)
    x = false
    x = evaluate_value(interpreter, arg_stack) if @valref == :value
    x = evaluate_ref(interpreter, arg_stack) if @valref == :reference
    x
  end

  private

  # return a single value
  def evaluate_value(interpreter, arg_stack)
    arguments = arg_stack.pop
    sigils = XrefEntry.make_sigils(arguments)
    definition = interpreter.get_user_function(@name, sigils)

    # dummy variable names and their (now known) values
    params = definition.arguments
    param_names_values = params.zip(arguments)
    names_and_values = Hash[param_names_values]
    interpreter.define_user_var_values(names_and_values)

    begin
      expression = definition.expression
      results = expression.evaluate(interpreter)
    rescue BASICRuntimeError => e
      interpreter.clear_user_var_values

      raise e
    end

    interpreter.clear_user_var_values
    results[0]
  end

  def evaluate_ref(interpreter, arg_stack)
    x = nil

    x = evaluate_ref_scalar(interpreter, arg_stack) if
      @default_shape == :scalar

    x = evaluate_ref_compound(interpreter, arg_stack) if
      @default_shape == :array || @default_shape == :matrix
    x
  end

  # return a single value, a reference to this object
  def evaluate_ref_scalar(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      subscripts = arg_stack.pop
      @subscripts = interpreter.normalize_subscripts(subscripts)
      num_args = @subscripts.length

      if num_args.zero?
        raise(BASICSyntaxError,
              'Variable expects subscripts, found empty parentheses')
      end

      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end

  # return a single value, a reference to this object
  def evaluate_ref_compound(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      subscripts = arg_stack.pop
      @subscripts = interpreter.normalize_subscripts(subscripts)
      num_args = @subscripts.length

      if num_args.zero?
        raise(BASICSyntaxError,
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

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].abs
  end
end

# function ARCCOS
class FunctionArcCos < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].arccos
  end
end

# function ARCSIN
class FunctionArcSin < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].arcsin
  end
end

# function ARCTAN
class FunctionArcTan < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    if match_args_to_signature(args, @signature_1)
      args[0].atn
    elsif match_args_to_signature(args, @signature_2)
      args[0].atn2(args[1])
    else
      raise BASICRuntimeError.new(:te_args_no_match, @name)
    end
  end
end

# function CON1
class FunctionCon1 < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :array
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end
  
  def set_constant(constant_stack)
    unless constant_stack.empty?
      if constant_stack[-1].class.to_s == 'Array'
        constants = constant_stack.pop

        if constants.empty?
          @constant = false
        else
          @constant = true
          constants.each { |c| @constant &&= c }
        end
      end
    end

    constant_stack.push(@constant)
  end
  
  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = BASICArray.one_values(dims)
        BASICArray.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = BASICArray.one_values(dims)
        BASICArray.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = BASICArray.one_values(dims)
      BASICArray.new(dims, values)
    end
  end
end

# function CON, CON2
class FunctionCon2 < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]

    @shape = :matrix
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
  end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      if constant_stack[-1].class.to_s == 'Array'
        constants = constant_stack.pop

        if constants.empty?
          @constant = false
        else
          @constant = true
          constants.each { |c| @constant &&= c }
        end
      end
    end

    constant_stack.push(@constant)
  end

  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.one_values(dims)
        Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = Matrix.one_values(dims)
        Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        dims = args.clone
        values = Matrix.one_values(dims)
        Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = Matrix.one_values(dims)
      Matrix.new(dims, values)
    end
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].cos
  end
end

# function COT
class FunctionCot < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].cot
  end
end

# function CSC
class FunctionCsc < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].csc
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].determinant
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].exp
  end
end

# function FRA
class FunctionFra < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  # return a single value
  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

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

    @shape = :matrix
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      if constant_stack[-1].class.to_s == 'Array'
        constants = constant_stack.pop

        if constants.empty?
          @constant = false
        else
          @constant = true
          constants.each { |c| @constant &&= c }
        end
      end
    end

    constant_stack.push(@constant)
  end

  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.identity_values(dims)
        Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = [args[0]] * 2
        values = Matrix.identity_values(dims)
        Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        raise BASICRuntimeError.new(:te_mat_no_sq, @name) unless
          args[1] == args[0]

        dims = args.clone
        values = Matrix.identity_values(dims)
        Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)

      raise BASICRuntimeError.new(:te_mat_no_sq, @name) unless
        args.size == 2 && args[1] == args[0]

      dims = args.clone
      values = Matrix.identity_values(dims)
      Matrix.new(dims, values)
    end
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  # return a single value
  def evaluate(interpreter, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    $options['int_floor'].value ? args[0].floor : args[0].truncate
  end
end

# function INV
class FunctionInv < AbstractMatrixFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]

    @shape = :matrix
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    dims = args[0].dimensions
    check_square(dims)
    Matrix.new(dims.clone, args[0].inverse_values)
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].log
  end
end

# function LOG10
class FunctionLog10 < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].log10
  end
end

# function LOG2
class FunctionLog2 < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].log2
  end
end

# function MOD
class FunctionMod < AbstractScalarFunction
  def initialize(text)
    super

    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]

    @shape = :scalar
  end

  # return a single value
  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_2)

    args[0].mod(args[1])
  end
end

# function ROUND
class FunctionRound < AbstractScalarFunction
  def initialize(text)
    super

    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_2)

    args[0].round(args[1])
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
    @constant = false
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constant_stack.pop if constant_stack[-1].class.to_s == 'Array'
    end

    # RND() is never constant
    
    constant_stack.push(@constant)
  end
  
  # return a single value
  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      if match_args_to_signature(args, @signature_0)
        arg = default_args(interpreter)
        interpreter.rand(arg)
      elsif match_args_to_signature(args, @signature_1)
        interpreter.rand(args[0])
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
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

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].sec
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].sign
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].sin
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].sqrt
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :scalar
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    args[0].tan
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super

    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]

    @shape = :matrix
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    dims = args[0].dimensions
    new_dims = [dims[1], dims[0]]
    Matrix.new(new_dims, args[0].transpose_values)
  end
end

# function ZER1
class FunctionZer1 < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]

    @shape = :array
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      if constant_stack[-1].class.to_s == 'Array'
        constants = constant_stack.pop

        if constants.empty?
          @constant = false
        else
          @constant = true
          constants.each { |c| @constant &&= c }
        end
      end
    end

    constant_stack.push(@constant)
  end

  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = BASICArray.zero_values(dims)
        BASICArray.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = BASICArray.zero_values(dims)
        BASICArray.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = BASICArray.zero_values(dims)
      BASICArray.new(dims, values)
    end
  end
end

# function ZER. ZER2
class FunctionZer2 < AbstractScalarFunction
  def initialize(text)
    super

    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]

    @shape = :matrix
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      if constant_stack[-1].class.to_s == 'Array'
        constants = constant_stack.pop

        if constants.empty?
          @constant = false
        else
          @constant = true
          constants.each { |c| @constant &&= c }
        end
      end
    end

    constant_stack.push(@constant)
  end

  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.zero_values(dims)
        Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = Matrix.zero_values(dims)
        Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        dims = args.clone
        values = Matrix.zero_values(dims)
        Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = Matrix.zero_values(dims)
      Matrix.new(dims, values)
    end
  end
end

# class to make functions, given the name
class FunctionFactory
  @functions = {
    'ABS' => FunctionAbs,
    'ARCCOS' => FunctionArcCos,
    'ARCSIN' => FunctionArcSin,
    'ARCTAN' => FunctionArcTan,
    'ATN' => FunctionArcTan,
    'CON' => FunctionCon2,
    'CON1' => FunctionCon1,
    'CON2' => FunctionCon2,
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
    'LOG10' => FunctionLog10,
    'LOG2' => FunctionLog2,
    'MOD' => FunctionMod,
    'RND' => FunctionRnd,
    'ROUND' => FunctionRound,
    'SEC' => FunctionSec,
    'SGN' => FunctionSgn,
    'SIN' => FunctionSin,
    'SQR' => FunctionSqr,
    'TAN' => FunctionTan,
    'TRN' => FunctionTrn,
    'ZER' => FunctionZer2,
    'ZER1' => FunctionZer1,
    'ZER2' => FunctionZer2
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
