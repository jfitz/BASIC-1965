# function (provides a scalar)
class AbstractFunction < AbstractElement
  attr_reader :name
  attr_reader :default_shape
  attr_reader :content_type
  attr_reader :shape
  attr_reader :constant
  attr_reader :warnings

  def initialize(text)
    super()

    @name = text
    @function = true
    @default_shape = :unknown
    @content_type = :numeric
    @shape = nil
    @constant = false
    @warnings = []
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

      raise(BASICExpressionError, "Bad expression #{@name} #{types}") unless
        types.class.to_s == 'Array'

      @arg_types = types
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shapes = shape_stack.pop

      raise(BASICExpressionError, "Bad expression #{@name} #{shapes}") unless
        shapes.class.to_s == 'Array'

      @arg_shapes = shapes
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

  def check_square(dims)
    raise(BASICSyntaxError, @name + ' requires matrix') unless dims.size == 2

    raise BASICRuntimeError.new(:te_mat_no_sq, @name) unless
      dims[1] == dims[0]
  end
end

# User-defined function (provides a scalar value)
class UserFunction < AbstractFunction
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
    @default_shape = :scalar
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
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

    return @cached unless @cached.nil?

    res = false
    res = evaluate_value(interpreter, arg_stack) if @valref == :value
    res = evaluate_ref(interpreter, arg_stack) if @valref == :reference

    @cached = res if @constant && $options['cache_const_expr']
    res
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
    raise BASICSyntaxError.new('function evaluated with arguments') if
      previous_is_array(arg_stack)

    self
  end

  # return a single value, a reference to this object
  def evaluate_ref_compound(interpreter, arg_stack)
    raise BASICSyntaxError.new('function evaluated with arguments') if
      previous_is_array(arg_stack)

    self
  end
end

# function ABS
class FunctionAbs < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].abs

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function ARCCOS
class FunctionArcCos < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].arccos

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function ARCSIN
class FunctionArcSin < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].arcsin

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function ARCTAN
class FunctionArcTan < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    if match_args_to_signature(args, @signature_1)
      res = args[0].atn
    elsif match_args_to_signature(args, @signature_2)
      res = args[0].atn2(args[1])
    else
      raise BASICRuntimeError.new(:te_args_no_match, @name)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function AVG
class FunctionAvg < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    raise BASICRunTimeError.new(:te_too_few, @name) if
      args[0].empty?

    sum = args[0].sum / args[0].size
    res = NumericConstant.new(sum)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function CON1
class FunctionCon1 < AbstractFunction
  def initialize(text)
    super

    @shape = :array

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
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

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = BASICArray.one_values(dims)
        res = BASICArray.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = BASICArray.one_values(dims)
        res = BASICArray.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = BASICArray.one_values(dims)
      res = BASICArray.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function CON, CON2
class FunctionCon2 < AbstractFunction
  def initialize(text)
    super

    @shape = :matrix

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
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

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.one_values(dims)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = Matrix.one_values(dims)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        dims = args.clone
        values = Matrix.one_values(dims)
        res = Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = Matrix.one_values(dims)
      res = Matrix.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function COS
class FunctionCos < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].cos

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function COT
class FunctionCot < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].cot

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function CSC
class FunctionCsc < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].csc

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function DEG
class FunctionDeg < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    v = args[0].to_v
    v1 = v * 180 / 3.14156926
    res = NumericConstant.new(v1)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function DET
class FunctionDet < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].determinant

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function EXP
class FunctionExp < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].exp

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function FIX
class FunctionFix < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  # return a single value
  def evaluate(interpreter, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].floor

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function FRA
class FunctionFra < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  # return a single value
  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0] - args[0].truncate

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function IDN
class FunctionIdn < AbstractFunction
  def initialize(text)
    super

    @shape = :matrix

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
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

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.identity_values(dims)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = [args[0]] * 2
        values = Matrix.identity_values(dims)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        raise BASICRuntimeError.new(:te_mat_no_sq, @name) unless
          args[1] == args[0]

        dims = args.clone
        values = Matrix.identity_values(dims)
        res = Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)

      raise BASICRuntimeError.new(:te_mat_no_sq, @name) unless
        args.size == 2 && args[1] == args[0]

      dims = args.clone
      values = Matrix.identity_values(dims)
      res = Matrix.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function INT
class FunctionInt < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  # return a single value
  def evaluate(interpreter, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = $options['int_floor'].value ? args[0].floor : args[0].truncate

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function INV
class FunctionInv < AbstractFunction
  def initialize(text)
    super

    @shape = :matrix

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    dims = args[0].dimensions
    check_square(dims)
    res = Matrix.new(dims.clone, args[0].inverse_values)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function LOG
class FunctionLog < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    if match_args_to_signature(args, @signature_1)
      res = args[0].log
    elsif match_args_to_signature(args, @signature_2)
      res = args[0].logb(args[1])
    else
      raise BASICRuntimeError.new(:te_args_no_match, @name)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function MAXA
class FunctionMaxA < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    raise BASICRunTimeError.new(:te_too_few, @name) if
      args[0].empty?

    res = args[0].max

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function MAXM
class FunctionMaxM < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    raise BASICRunTimeError.new(:te_too_few, @name) if
      args[0].empty?

    res = args[0].max

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function MINA
class FunctionMinA < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    raise BASICRunTimeError.new(:te_too_few, @name) if
      args[0].empty?

    res = args[0].min

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function MINM
class FunctionMinM < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    raise BASICRunTimeError.new(:te_too_few, @name) if
      args[0].empty?

    res = args[0].min

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function MOD
class FunctionMod < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  # return a single value
  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_2)

    res = args[0].mod(args[1])

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function NCOL
class FunctionNcol < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constant_stack.pop if constant_stack[-1].class.to_s == 'Array'
    end

    # NCOL() is never constant

    res = constant_stack.push(@constant)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = NumericConstant.new(args[0].ncol)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function NELEM
class FunctionNelem < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constant_stack.pop if constant_stack[-1].class.to_s == 'Array'
    end

    # NELEM() is never constant

    res = constant_stack.push(@constant)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = NumericConstant.new(args[0].size)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function NROW
class FunctionNrow < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constant_stack.pop if constant_stack[-1].class.to_s == 'Array'
    end

    # NROW() is never constant

    res = constant_stack.push(@constant)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = NumericConstant.new(args[0].nrow)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function PROD
class FunctionProd < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    sum = args[0].prod
    res = NumericConstant.new(sum)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function RAD
class FunctionRad < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    v = args[0].to_v
    v1 = v * 3.14156926 / 180
    res = NumericConstant.new(v1)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function ROUND
class FunctionRound < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_2)

    res = args[0].round(args[1])

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function RND
class FunctionRnd < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar
    @constant = false

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      @arg_types = type_stack.pop if
        type_stack[-1].class.to_s == 'Array'
    end

    res = type_stack.push(@content_type)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constant_stack.pop if constant_stack[-1].class.to_s == 'Array'
    end

    # RND() is never constant
    
    res = constant_stack.push(@constant)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
  
  # return a single value
  def evaluate(interpreter, arg_stack)
    if previous_is_array(arg_stack)
      args = arg_stack.pop

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        arg = default_args(interpreter)
        res = NumericConstant.new_rand(interpreter, arg)
      elsif match_args_to_signature(args, @signature_1)
        res = NumericConstant.new_rand(interpreter, args[0])
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      arg = default_args(interpreter)
      res = NumericConstant.new_rand(interpreter, arg)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function RND1
class FunctionRnd1 < AbstractFunction
  def initialize(text)
    super

    @shape = :array
    @constant = false

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 = [
      { 'type' => :numeric, 'shape' => :scalar },
      { 'type' => :numeric, 'shape' => :scalar }
    ]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end
  
  def set_constant(constant_stack)
    unless constant_stack.empty?
      constants = constant_stack.pop if
        constant_stack[-1].class.to_s == 'Array'
    end

    # RND1() is never constant

    constant_stack.push(@constant)
  end
  
  def evaluate(interpreter, arg_stack)
    upper_bound = NumericConstant.new(1)

    if previous_is_array(arg_stack)
      args = arg_stack.pop

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = BASICArray.rnd_values(dims, interpreter, upper_bound)
        res = BASICArray.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = BASICArray.rnd_values(dims, interpreter, upper_bound)
        res = BASICArray.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        dims = [args[0]]
        upper_bound = args[1]
        values = BASICArray.rnd_values(dims, interpreter, upper_bound)
        res = BASICArray.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = BASICArray.rnd_values(dims, interpreter, upper_bound)
      res = BASICArray.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function RND2
class FunctionRnd2 < AbstractFunction
  def initialize(text)
    super

    @shape = :matrix
    @constant = false

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
    @signature_3 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    unless constant_stack.empty?
      constants = constant_stack.pop if
        constant_stack[-1].class.to_s == 'Array'
    end

    # RND2() is never constant

    constant_stack.push(@constant)
  end

  def evaluate(interpreter, arg_stack)
    upper_bound = NumericConstant.new(1)

    if previous_is_array(arg_stack)
      args = arg_stack.pop

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.rnd_values(dims, interpreter, upper_bound)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = Matrix.rnd_values(dims, interpreter, upper_bound)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        dims = args.clone
        values = Matrix.rnd_values(dims, interpreter, upper_bound)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_3)
        dims = args.clone[0..1]
        upper_bound = args[2]
        values = Matrix.rnd_values(dims, interpreter, upper_bound)
        res = Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = Matrix.rnd_values(dims, interpreter, upper_bound)
      res = Matrix.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function REV1
class FunctionRev1 < AbstractFunction
  def initialize(text)
    super

    @shape = :array

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    dims = args[0].dimensions
    res = BASICArray.new(dims, args[0].reverse_values)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function SEC
class FunctionSec < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].sec

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function SGN
class FunctionSgn < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].sign

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function SIN
class FunctionSin < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].sin

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function SQR
class FunctionSqr < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].sqrt

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function SUM
class FunctionSum < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :array
    @signature_1 = [{ 'type' => :numeric, 'shape' => :array }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    sum = args[0].sum
    res = NumericConstant.new(sum)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function TAN
class FunctionTan < AbstractFunction
  def initialize(text)
    super

    @shape = :scalar

    @default_shape = :scalar
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    res = args[0].tan

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function TRN
class FunctionTrn < AbstractFunction
  def initialize(text)
    super

    @shape = :matrix

    @default_shape = :matrix
    @signature_1 = [{ 'type' => :numeric, 'shape' => :matrix }]
  end

  def evaluate(_, arg_stack)
    args = arg_stack.pop

    return @cached unless @cached.nil?

    raise BASICRuntimeError.new(:te_args_no_match, @name) unless
      match_args_to_signature(args, @signature_1)

    dims = args[0].dimensions
    new_dims = [dims[1], dims[0]]
    res = Matrix.new(new_dims, args[0].transpose_values)

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function ZER1
class FunctionZer1 < AbstractFunction
  def initialize(text)
    super

    @shape = :array

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
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

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = BASICArray.zero_values(dims)
        res = BASICArray.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = BASICArray.zero_values(dims)
        res = BASICArray.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = BASICArray.zero_values(dims)
      res = BASICArray.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
  end
end

# function ZER. ZER2
class FunctionZer2 < AbstractFunction
  def initialize(text)
    super

    @shape = :matrix

    @default_shape = :scalar
    @signature_0 = []
    @signature_1 = [{ 'type' => :numeric, 'shape' => :scalar }]
    @signature_2 =
      [
        { 'type' => :numeric, 'shape' => :scalar },
        { 'type' => :numeric, 'shape' => :scalar }
      ]
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
      @arg_shapes = shape_stack.pop if shape_stack[-1].class.to_s == 'Array'
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

      return @cached unless @cached.nil?

      if match_args_to_signature(args, @signature_0)
        args = default_args(interpreter)
        dims = args.clone
        values = Matrix.zero_values(dims)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_1)
        dims = args.clone
        values = Matrix.zero_values(dims)
        res = Matrix.new(dims, values)
      elsif match_args_to_signature(args, @signature_2)
        dims = args.clone
        values = Matrix.zero_values(dims)
        res = Matrix.new(dims, values)
      else
        raise BASICRuntimeError.new(:te_args_no_match, @name)
      end
    else
      args = default_args(interpreter)
      dims = args.clone
      values = Matrix.zero_values(dims)
      res = Matrix.new(dims, values)
    end

    @cached = res if @constant && $options['cache_const_expr']
    res
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
    'AVG' => FunctionAvg,
    'CON' => FunctionCon2,
    'CON1' => FunctionCon1,
    'CON2' => FunctionCon2,
    'COS' => FunctionCos,
    'COT' => FunctionCot,
    'CSC' => FunctionCsc,
    'DEG' => FunctionDeg,
    'DET' => FunctionDet,
    'EXP' => FunctionExp,
    'FIX' => FunctionFix,
    'FRA' => FunctionFra,
    'IDN' => FunctionIdn,
    'INT' => FunctionInt,
    'INV' => FunctionInv,
    'LOG' => FunctionLog,
    'MAXA' => FunctionMaxA,
    'MAXM' => FunctionMaxM,
    'MINA' => FunctionMinA,
    'MINM' => FunctionMinM,
    'MOD' => FunctionMod,
    'NCOL' => FunctionNcol,
    'NELEM' => FunctionNelem,
    'NROW' => FunctionNrow,
    'PROD' => FunctionProd,
    'RAD' => FunctionRad,
    'RND' => FunctionRnd,
    'RND1' => FunctionRnd1,
    'RND2' => FunctionRnd2,
    'REV1' => FunctionRev1,
    'ROUND' => FunctionRound,
    'SEC' => FunctionSec,
    'SGN' => FunctionSgn,
    'SIN' => FunctionSin,
    'SQR' => FunctionSqr,
    'SUM' => FunctionSum,
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
