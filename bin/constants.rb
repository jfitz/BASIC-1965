# frozen_string_literal: true

# class for all constant classes
class AbstractElement
  def self.make_coord(c)
    [NumericConstant.new(c)]
  end

  def self.make_coords(r, c)
    [NumericConstant.new(r), NumericConstant.new(c)]
  end

  attr_reader :precedence

  def initialize
    @empty = false
    @operator = false
    @function = false
    @user_function = false
    @variable = false
    @operand = false
    @terminal = false
    @group_start = false
    @group_end = false
    @param_start = false
    @separator = false
    @file_handle = false
    @precedence = 0
    @shape = nil
    @list = false
    @carriage = false
    @valref = nil
    @set_dims = false
    @numeric_constant = false
    @text_constant = false
    @boolean_constant = false
  end

  def uncache
    @cached = nil
  end

  def dump
    "#{self.class}:Unimplemented"
  end

  def destinations(_)
    []
  end

  def empty?
    @empty
  end

  def keyword?
    false
  end

  def operator?
    @operator
  end

  def function?
    @function
  end

  def user_function?
    @user_function
  end

  def variable?
    @variable
  end

  def function_variable?
    function? || variable?
  end

  def operand?
    @operand
  end

  def terminal?
    @terminal
  end

  def group_start?
    @group_start
  end

  def group_end?
    @group_end
  end

  def param_start?
    @param_start
  end

  def starter?
    @group_start || @param_start
  end

  def separator?
    @separator
  end

  def group_separator?
    group_start? || group_end? || separator?
  end

  def previous_is_array(stack)
    !stack.empty? && stack[-1].class.to_s == 'Array'
  end

  def file_handle?
    @file_handle
  end

  def scalar?
    @shape == :scalar
  end

  def array?
    @shape == :array
  end

  def matrix?
    @shape == :matrix
  end

  def list?
    @list
  end

  def carriage_control?
    @carriage
  end

  def value?
    @valref == :value
  end

  def reference?
    @valref == :reference
  end

  def numeric_constant?
    @numeric_constant
  end

  def text_constant?
    @text_constant
  end

  def boolean_constant?
    @boolean_constant
  end

  def pop_stack(stack); end

  private

  def make_sigils(types, shapes)
    return nil if types.nil? || shapes.nil?

    msg = "Different number of types (#{types.count}) and shapes (#{shapes.count})"
    raise BASICExpressionError, msg unless
      types.count == shapes.count

    sigil_chars = {
      numeric: '_',
      integer: '%',
      string: '$',
      boolean: '?'
    }

    sigils = []

    types.each_with_index do |type, index|
      sigil = sigil_chars[type]
      sigil += '()' if shapes[index] == :array
      sigil += '(,)' if shapes[index] == :matrix
      sigils << sigil
    end

    sigils
  end

  def make_type_sigil(type)
    sigil_chars = {
      numeric: '_',
      integer: '%',
      string: '$',
      boolean: '?',
      filehandle: 'FH'
    }

    sigil_chars[type]
  end

  def make_shape_sigil(shape)
    sigil = ''
    sigil = '()' if shape == :array
    sigil = '(,)' if shape == :matrix
    sigil
  end

  def make_signature(types, shapes)
    return '' if types.nil? || shapes.nil?

    sigils = make_sigils(types, shapes)

    XrefEntry.format_sigils(sigils)
  end
end

# empty token
class EmptyToken < AbstractElement
  def initialize
    super

    @text = ''
    @empty = true
  end
end

# beginning of a group
class GroupStart < AbstractElement
  def self.accept?(token)
    classes = %w[GroupStartToken]
    classes.include?(token.class.to_s)
  end

  attr_reader :text

  def initialize(element)
    super()

    @text = element.to_s
    @group_start = true
  end

  def to_s
    @text
  end
end

# end of a group
class GroupEnd < AbstractElement
  def self.accept?(token)
    classes = %w[GroupEndToken]
    classes.include?(token.class.to_s)
  end

  def initialize(element)
    super()

    @text = element.to_s
    @group_end = true
    @operand = true
  end

  def match?(start_element)
    (start_element.text == '(' && @text == ')') ||
      (start_element.text == '[' && @text == ']')
  end

  def to_s
    @text
  end
end

# beginning of a set of parameters
class ParamStart < AbstractElement
  attr_reader :text

  def initialize(element)
    super()

    @text = element.to_s
    @param_start = true
  end

  def to_s
    @text
  end
end

# separator for group or params
class ParamSeparator < AbstractElement
  def self.accept?(token)
    classes = %w[ParamSeparatorToken]
    classes.include?(token.class.to_s)
  end

  def initialize(token)
    super()

    @text = token.to_s
    @separator = true
  end

  def to_s
    @text
  end
end

public

# class that holds a value
class AbstractValueElement < AbstractElement
  attr_reader :content_type, :shape, :constant, :warnings

  def initialize
    super

    @operand = true
    @precedence = 0
    @shape = :scalar
    @constant = false
    @value = nil
    @warnings = []
  end

  def dump
    "#{self.class}:#{self}"
  end

  def eql?(other)
    @value == other.to_v
  end

  def hash
    @value.hash
  end

  def <=>(other)
    return -1 if self < other
    return 1 if self > other

    0
  end

  def ==(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in =="

    raise(BASICExpressionError, message) unless compatible?(other)

    @value == other.to_v
  end

  def >(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in >"

    raise(BASICExpressionError, message) unless compatible?(other)

    @value > other.to_v
  end

  def >=(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in >="

    raise(BASICExpressionError, message) unless compatible?(other)

    @value >= other.to_v
  end

  def <(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in <"

    raise(BASICExpressionError, message) unless compatible?(other)

    @value < other.to_v
  end

  def <=(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in <="

    raise(BASICExpressionError, message) unless compatible?(other)

    @value <= other.to_v
  end

  def b_eq(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_eq()"

    raise(BASICExpressionError, message) unless compatible?(other)

    BooleanConstant.new(@value == other.to_v)
  end

  def b_ne(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_ne()"

    raise(BASICExpressionError, message) unless compatible?(other)

    BooleanConstant.new(@value != other.to_v)
  end

  def b_gt(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_gt()"

    raise(BASICExpressionError, message) unless compatible?(other)

    BooleanConstant.new(@value > other.to_v)
  end

  def b_ge(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_ge()"

    raise(BASICExpressionError, message) unless compatible?(other)

    BooleanConstant.new(@value >= other.to_v)
  end

  def b_lt(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_lt()"

    raise(BASICExpressionError, message) unless compatible?(other)

    BooleanConstant.new(@value < other.to_v)
  end

  def b_le(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_le()"

    raise(BASICExpressionError, message) unless compatible?(other)

    BooleanConstant.new(@value <= other.to_v)
  end

  def posate
    raise(BASICExpressionError, 'Invalid operator +')
  end

  def negate
    raise(BASICExpressionError, 'Invalid operator -')
  end

  def filehandle
    raise(BASICExpressionError, 'Invalid operator #')
  end

  def +(_other)
    raise(BASICExpressionError, 'Invalid operator +')
  end

  def -(_other)
    raise(BASICExpressionError, 'Invalid operator -')
  end

  def add(_)
    raise(BASICExpressionError, 'Invalid operator add')
  end

  def subtract(_)
    raise(BASICExpressionError, 'Invalid operator subtract')
  end

  def multiply(_)
    raise(BASICExpressionError, 'Invalid operator multiply')
  end

  def divide(_)
    raise(BASICExpressionError, 'Invalid operator divide')
  end

  def power(_)
    raise(BASICExpressionError, 'Invalid operator power')
  end

  def keyword?
    false
  end

  def evaluate(_, _)
    self
  end

  def to_v
    @value
  end

  def to_numeric
    @value
  end

  def compatible?(other)
    other.content_type == content_type
  end
end

# Numeric constants
class NumericConstant < AbstractValueElement
  def self.accept?(token)
    classes =
      %w[Fixnum Integer Bignum Float NumericConstantToken NumericSymbolToken]

    classes.include?(token.class.to_s)
  end

  def self.numeric(text)
    case text
    # nnn(E+nn)
    when /\A\s*[+-]?\d+(E+?\d+)?\z/
      text.to_f.to_i
    # nnn(E-nn)
    when /\A\s*[+-]?\d+(E-\d+)?\z/
      text.to_f
    # nnn.(nnn)(E+-nn)
    when /\A\s*[+-]?\d+\.(\d*)?(E[+-]?\d+)?\z/
      text.to_f
    # (nnn).nnn(E+-nn)
    when /\A\s*[+-]?(\d+)?\.\d*(E[+-]?\d+)?\z/
      text.to_f
    end
  end

  def self.new_rand(interpreter, upper_bound)
    v = interpreter.rand(upper_bound)
    NumericConstant.new(v)
  end

  private

  def float_to_possible_int(f)
    return f if f == Float::INFINITY

    i = f.to_i
    frac = f - i
    frac.zero? || (!i.zero? && frac.abs < 1e-7) ? i : f
  end

  public

  attr_reader :symbol_text

  def initialize(obj)
    super()

    numeric_classes = %w[Fixnum Integer Bignum Float]
    float_classes = %w[Rational NumericConstantToken]

    f = nil
    f = obj.to_f if float_classes.include?(obj.class.to_s)
    f = obj if numeric_classes.include?(obj.class.to_s)

    if obj.class.to_s == 'NumericSymbolToken'
      f = obj.value
      @symbol = true
    end

    raise(BASICSyntaxError, "'#{obj}' is not a number") if f.nil?

    precision = $options['precision'].value
    if precision != 'INFINITE' && f != 0 && f != Float::INFINITY
      abs_value = f.abs
      log_value = Math.log10(abs_value)
      ceil_value = log_value.ceil
      num_digits = -(ceil_value - precision)
      f = f.round(num_digits)
    end

    @content_type = :numeric
    @shape = :scalar
    @constant = true
    @symbol_text = obj.to_s
    @value = float_to_possible_int(f)
    @numeric_constant = true
    @units = {}

    @units = obj.units if obj.class.to_s == 'NumericConstantToken'
  end

  def dump
    "#{self.class}:#{@symbol_text}"
  end

  def zero?
    @value.zero?
  end

  def set_content_type(type_stack)
    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    @value == other.to_v
  end

  def ==(other)
    @value == other.to_v
  end

  def hash
    @value.hash + @symbol_text.hash
  end

  def <=>(other)
    @value <=> other.to_v
  end

  def >(other)
    @value > other.to_v
  end

  def >=(other)
    @value >= other.to_v
  end

  def <(other)
    @value < other.to_v
  end

  def <=(other)
    @value <= other.to_v
  end

  def posate
    NumericConstant.new(@value)
  end

  def negate
    NumericConstant.new(-@value)
  end

  def filehandle
    num = to_i
    FileHandle.new(num)
  end

  def +(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in +()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value + other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def -(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in -()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value - other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def *(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in *()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value * other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def add(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in add()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value + other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def subtract(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in subtract()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value - other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def multiply(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in multiply()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value * other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def divide(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in divide()"

    raise(BASICExpressionError, message) unless compatible?(other)
    raise BASICRuntimeError, :te_div_zero if other.zero?

    value = @value.to_f / other.to_numeric.to_f
    NumericConstant.new(value)
  end

  def power(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in power()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value**other.to_numeric.to_v
    NumericConstant.new(value)
  end

  def truncate
    value = @value.to_i
    NumericConstant.new(value)
  end

  def floor
    value = @value.floor
    NumericConstant.new(value)
  end

  def exp
    value = Math.exp(@value)
    NumericConstant.new(value)
  end

  def log
    value = @value.positive? ? Math.log(@value) : 0
    NumericConstant.new(value)
  end

  def logb(lbase)
    lbase_v = lbase.to_v
    value = @value.positive? ? Math.log(@value, lbase_v) : 0
    NumericConstant.new(value)
  end

  def mod(other)
    value = other.to_v.zero? ? 0 : @value % other.to_v
    NumericConstant.new(value)
  end

  def abs
    value = @value >= 0 ? @value : -@value
    NumericConstant.new(value)
  end

  def round(places)
    NumericConstant.new(@value.round(places.to_i))
  end

  def sqrt
    value = @value.positive? ? Math.sqrt(@value) : 0
    NumericConstant.new(value)
  end

  def sin
    value = Math.sin(@value)
    NumericConstant.new(value)
  end

  def arcsin
    return 0 if @value < -1.0 || @value > 1.0

    NumericConstant.new(Math.asin(@value))
  end

  def cos
    value = Math.cos(@value)
    NumericConstant.new(value)
  end

  def arccos
    return 0 if @value < -1.0 || @value > 1.0

    NumericConstant.new(Math.acos(@value))
  end

  def tan
    value = @value >= 0 ? Math.tan(@value) : 0
    NumericConstant.new(value)
  end

  def cot
    cos = Math.cos(@value)
    sin = Math.sin(@value)
    cot = Float::INFINITY
    cot = cos / sin if sin.nonzero?
    NumericConstant.new(cot)
  end

  def atn
    value = Math.atan(@value)
    NumericConstant.new(value)
  end

  def atn2(a2)
    value = Math.atan2(@value, a2.to_f)
    NumericConstant.new(value)
  end

  def sec
    cos = Math.cos(@value)
    sec = Float::INFINITY
    sec = 1 / cos if cos.nonzero?
    NumericConstant.new(sec)
  end

  def csc
    sin = Math.sin(@value)
    csc = Float::INFINITY
    csc = 1 / sin if sin.nonzero?
    NumericConstant.new(csc)
  end

  def sign
    result = 0
    result = 1 if @value.positive?
    result = -1 if @value.negative?
    NumericConstant.new(result)
  end

  def to_i
    @value.to_i
  end

  def to_f
    @value.to_f
  end

  def to_s
    digits = @value.to_s
    units = AbstractToken.units_to_s(@units)

    digits + units
  end

  def to_b
    !@value.to_f.zero?
  end

  def to_numeric
    NumericConstant.new(@value)
  end

  def print(printer)
    s = to_formatted_s
    s = s.upcase
    printer.print_item s
    printer.last_was_numeric
  end

  def write(printer)
    s = to_formatted_s
    s = s.upcase
    printer.print_item s
  end

  def compatible?(other)
    other.numeric_constant?
  end

  private

  def to_formatted_s
    lead_space = @value >= 0 ? ' ' : ''
    digits = @value.to_s
    units = AbstractToken.units_to_s(@units)

    lead_space + digits + units
  end
end

# Integer constants
class IntegerConstant < AbstractValueElement
  def self.accept?(token)
    classes = %w[Fixnum Integer Bignum Float IntegerConstantToken]
    classes.include?(token.class.to_s)
  end

  def self.numeric(text)
    # nnn%
    text.to_f.to_i if /\A\s*[+-]?\d+%\z/ =~ text
  end

  def self.new_rand(interpreter, upper_bound)
    v = interpreter.rand(upper_bound)
    IntegerConstant.new(v.to_i)
  end

  attr_reader :symbol_text

  def initialize(obj)
    super()

    numeric_classes = %w[Fixnum Integer Bignum Float NumericConstantToken]
    f = nil
    f = obj.to_i if numeric_classes.include?(obj.class.to_s)
    f = obj.to_f.to_i if obj.class.to_s == 'NumericConstantToken'

    raise BASICSyntaxError, "'#{obj}' is not an integer" if f.nil?

    @symbol_text = obj.to_s
    @content_type = :integer
    @shape = :scalar
    @constant = true
    @value = f
    @operand = true
    @precedence = 0
    @numeric_constant = true
    @units = {}

    @units = obj.units if obj.class.to_s == 'NumericConstantToken'
  end

  def zero?
    @value.zero?
  end

  def set_content_type(type_stack)
    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    @value == other.to_v
  end

  def ==(other)
    @value == other.to_v
  end

  def hash
    @value.hash + @symbol_text.hash
  end

  def <=>(other)
    @value <=> other.to_v
  end

  def >(other)
    @value > other.to_v
  end

  def >=(other)
    @value >= other.to_v
  end

  def <(other)
    @value < other.to_v
  end

  def <=(other)
    @value <= other.to_v
  end

  def b_and(other)
    if other.content_type == :integer && $options['int_bitwise'].value
      IntegerConstant.new(to_i & other.to_i)
    else
      BooleanConstant.new(to_b && other.to_b)
    end
  end

  def b_or(other)
    if other.content_type == :integer && $options['int_bitwise'].value
      IntegerConstant.new(to_i | other.to_i)
    else
      BooleanConstant.new(to_b || other.to_b)
    end
  end

  def posate
    NumericConstant.new(@value)
  end

  def negate
    IntegerConstant.new(-@value)
  end

  def filehandle
    num = to_i
    FileHandle.new(num)
  end

  def not
    b = ~to_i
    IntegerConstant.new(b)
  end

  def +(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in +()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value + other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def -(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in -()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value - other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def *(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in *()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value * other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def add(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in add()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value + other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def subtract(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in subtract()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value - other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def multiply(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in multiply()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value * other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def divide(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in divide()"

    raise(BASICExpressionError, message) unless compatible?(other)
    raise BASICRuntimeError, :te_div_zero if other.zero?

    value = @value.to_f / other.to_numeric.to_f
    IntegerConstant.new(value)
  end

  def power(other)
    message =
      "Type mismatch (#{content_type}/#{other.content_type}) in power()"

    raise(BASICExpressionError, message) unless compatible?(other)

    value = @value**other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def truncate
    value = @value.to_i
    IntegerConstant.new(value)
  end

  def floor
    IntegerConstant.new(@value)
  end

  def exp
    value = Math.exp(@value)
    IntegerConstant.new(value)
  end

  def log
    value = @value.positive? ? Math.log(@value) : 0
    IntegerConstant.new(value)
  end

  def log10
    value = @value.positive? ? Math.log10(@value) : 0
    IntegerConstant.new(value)
  end

  def log2
    value = @value.positive? ? Math.log2(@value) : 0
    IntegerConstant.new(value)
  end

  def mod(other)
    value = other.to_numeric.zero? ? 0 : @value % other.to_numeric.to_v
    IntegerConstant.new(value)
  end

  def abs
    value = @value >= 0 ? @value : -@value
    IntegerConstant.new(value)
  end

  def sqrt
    value = @value.positive? ? Math.sqrt(@value) : 0
    IntegerConstant.new(value)
  end

  def sin
    value = Math.sin(@value)
    IntegerConstant.new(value)
  end

  def cos
    value = Math.cos(@value)
    IntegerConstant.new(value)
  end

  def tan
    value = @value >= 0 ? Math.tan(@value) : 0
    IntegerConstant.new(value)
  end

  def atn
    value = Math.atan(@value)
    IntegerConstant.new(value)
  end

  def sign
    result = 0
    result = 1 if @value.positive?
    result = -1 if @value.negative?
    IntegerConstant.new(result)
  end

  def to_i
    @value.to_i
  end

  def to_f
    @value.to_i
  end

  def to_s
    digits = @value.to_s
    units = AbstractToken.units_to_s(@units)

    digits + units
  end

  def to_b
    !@value.to_i.zero?
  end

  def to_numeric
    IntegerConstant.new(@value)
  end

  def print(printer)
    s = to_formatted_s
    s = s.upcase
    printer.print_item s
    printer.last_was_numeric
  end

  def write(printer)
    s = to_formatted_s
    s = s.upcase
    printer.print_item s
  end

  def compatible?(other)
    other.numeric_constant?
  end

  private

  def to_formatted_s
    lead_space = @value >= 0 ? ' ' : ''
    digits = @value.to_s
    units = AbstractToken.units_to_s(@units)

    lead_space + digits + units
  end
end

# Text constants
class TextConstant < AbstractValueElement
  def self.accept?(token)
    classes = %w[TextConstantToken String]
    classes.include?(token.class.to_s)
  end

  attr_reader :value, :symbol_text

  def initialize(text)
    super()

    @value = nil
    @value = text if text.class.to_s == 'String'
    @value = text.value if text.class.to_s == 'TextConstantToken'

    raise(BASICSyntaxError, "'#{text}' is not a text constant") if @value.nil?

    @content_type = :string
    @shape = :scalar
    @constant = true

    @text_constant = true
  end

  def set_content_type(type_stack)
    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    @value == other.to_v
  end

  def ==(other)
    @value == other.to_v
  end

  def hash
    @value.hash
  end

  def <=>(other)
    @value <=> other.to_v
  end

  def >(other)
    @value > other.to_v
  end

  def >=(other)
    @value >= other.to_v
  end

  def <(other)
    @value < other.to_v
  end

  def <=(other)
    @value <= other.to_v
  end

  def +(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in +()"

    raise(BASICExpressionError, message) unless compatible?(other)

    TextConstant.new(@value + other.to_v)
  end

  def add(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in add()"

    raise(BASICExpressionError, message) unless compatible?(other)

    TextConstant.new(@value + other.to_v)
  end

  def multiply(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in add()"

    raise(BASICExpressionError, message) unless other.numeric_constant?

    TextConstant.new(@value * other.to_v)
  end

  def to_s
    "\"#{@value}\""
  end

  def to_b
    !@value.size.zero?
  end

  def print(printer)
    printer.print_item @value
  end

  def write(printer)
    v = to_s
    printer.print_item v
  end
end

# Boolean constants
class BooleanConstant < AbstractValueElement
  def self.accept?(token)
    classes = %w[BooleanConstantToken]
    classes.include?(token.class.to_s)
  end

  attr_reader :value, :symbol_text

  def initialize(obj)
    super()

    obj_class = obj.class.to_s
    @symbol_text = obj.to_s

    @value =
      (obj_class == 'BooleanConstantToken' && obj.to_s == 'TRUE') ||
      (obj_class == 'String' && obj.casecmp('TRUE').zero?) ||
      (obj_class == 'NumericConstant' && !obj.to_f.zero?) ||
      (obj_class == 'IntegerConstant' && !obj.to_i.zero?) ||
      (obj_class == 'TextConstant' && !obj.value.strip.size.zero?) ||
      obj_class == 'TrueClass'

    @content_type = :boolean
    @shape = :scalar
    @constant = true
    @boolean_constant = true
  end

  def set_content_type(type_stack)
    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    @value == other.to_v
  end

  def ==(other)
    @value == other.to_v
  end

  def hash
    @value.hash
  end

  def <=>(other)
    to_i <=> other.to_i
  end

  def >(other)
    @value > other.to_v
  end

  def >=(other)
    @value >= other.to_v
  end

  def <(other)
    @value < other.to_v
  end

  def <=(other)
    @value <= other.to_v
  end

  def b_and(other)
    BooleanConstant.new(@value && other.to_b)
  end

  def b_or(other)
    BooleanConstant.new(@value || other.to_b)
  end

  def to_i
    @value ? 1 : 0
  end

  def to_f
    @value ? 1.0 : 0.0
  end

  def to_s
    @value ? 'true' : 'false'
  end

  def to_formatted_s
    @value ? 'true' : 'false'
  end

  def to_b
    @value
  end

  def to_numeric
    @value ? NumericConstant.new(-1) : NumericConstant.new(0)
  end

  def print(printer)
    s = to_formatted_s
    s = s.upcase
    printer.print_item s
    printer.last_was_numeric
  end

  def write(printer)
    s = to_formatted_s
    s = s.upcase
    printer.print_item s
  end

  def compatible?(other)
    other.numeric_constant? || other.boolean_constant?
  end

  private

  def numeric_value
    @value ? -1 : 0
  end
end

# File handle class
class FileHandle < AbstractElement
  attr_reader :number

  def initialize(num)
    super()

    legals = %w[Fixnum Integer NumericConstant IntegerConstant FileHandle]

    raise BASICRuntimeError, :te_fh_inv unless
      legals.include?(num.class.to_s)

    raise BASICRuntimeError, :te_fnum_inv if num.to_i.negative?

    @number = num.to_i
    @file_handle = true
  end

  def hash
    @number.hash
  end

  def eql?(other)
    @number == other.number
  end

  def warnings
    []
  end

  def to_s
    "##{@number}"
  end

  def to_i
    @number
  end
end

# Carriage control for PRINT and MAT PRINT statements
class CarriageControl
  def self.accept?(token)
    classes = %w[ParamSeparatorToken]
    classes.include?(token.class.to_s)
  end

  attr_reader :comprehension_effort

  def initialize(token)
    token = ',' if token == 'COMMA'
    token = ';' if token == 'SEMI'
    token = '' if token == 'NONE'

    @operator = token.to_s
    @carriage = true
    @file_handle = false
    @comprehension_effort = 0
  end

  def warnings
    []
  end

  def uncache; end

  def keyword?
    false
  end

  def has_tab
    false
  end

  def to_s
    case @operator
    when ';'
      '; '
    when ','
      ', '
    when 'NL'
      ''
    when ''
      ' '
    end
  end

  def dump
    ["#{self.class}:#{@operator}"]
  end

  def carriage_control?
    @carriage
  end

  def filehandle?
    @file_handle
  end

  def numerics
    []
  end

  def strings
    []
  end

  def booleans
    []
  end

  def variables
    []
  end

  def operators
    []
  end

  def functions
    []
  end

  def userfuncs
    []
  end

  def plot(printer)
    printer.newline
  end

  def print(printer)
    case @operator
    when ','
      printer.tab
    when ';'
      printer.semicolon
    when 'NL'
      printer.newline
    when ''
      printer.implied
    end
  end

  def write(printer)
    case @operator
    when ','
      printer.print_item(@operator)
    when ';'
      printer.print_item(@operator)
    when 'NL'
      printer.newline
    when ''
      printer.print_item(',')
    end
  end
end

# Hold a variable name
class VariableName < AbstractElement
  def self.accept?(token)
    classes = %w[VariableToken]
    classes.include?(token.class.to_s)
  end

  attr_reader :name, :content_type, :constant

  def initialize(token)
    super()

    raise(BASICSyntaxError, "'#{token}' is not a variable token") unless
      token.class.to_s == 'VariableToken'

    @name = token
    @variable = true
    @operand = true
    @precedence = 10
    @content_type = @name.content_type
    @constant = false
  end

  def set_content_type(type_stack)
    type_stack.push(@content_type)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    to_s == other.to_s
  end

  def ==(other)
    to_s == other.to_s
  end

  def hash
    @name.hash
  end

  def scalar?
    true
  end

  def dump
    result = make_type_sigil(@content_type)
    "#{self.class}:#{@name} -> #{result}"
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

  def subscripts
    []
  end

  def to_s
    @name.to_s
  end
end

# Hold a function name
class UserFunctionName < AbstractElement
  def self.accept?(token)
    classes = %w[UserFunctionToken]
    classes.include?(token.class.to_s)
  end

  attr_reader :name, :content_type, :shape, :constant, :warnings

  def initialize(token)
    super()

    raise(BASICSyntaxError, "'#{token}' is not a function name") unless
      token.class.to_s == 'UserFunctionToken'

    @name = token
    @function = true
    @user_function = true
    @operand = true
    @precedence = 10
    @content_type = @name.content_type
    @shape = :scalar
    @warnings = []
  end

  def set_content_type(type_stack)
    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    to_s == other.to_s
  end

  def ==(other)
    to_s == other.to_s
  end

  def hash
    @name.hash
  end

  def scalar?
    true
  end

  def default_shape
    :scalar
  end

  def dump
    result = make_type_sigil(@content_type) + make_shape_sigil(@shape)
    "#{self.class}:#{@name} -> #{result}"
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

  def subscripts
    []
  end

  def to_s
    @name.to_s
  end
end

# empty variable, used only for NEXT without control variable
class EmptyVariable
  def name
    EmptyToken.new
  end

  def empty?
    true
  end
end

# Hold a variable (name with possible subscripts and value)
class Variable < AbstractElement
  attr_writer :valref, :set_dims
  attr_reader :content_type, :shape, :constant, :subscripts, :warnings

  def initialize(variable_name, my_shape, subscripts, wrapped_subscripts)
    super()

    raise(BASICSyntaxError, "'#{variable_name}' is not a variable name") unless
      variable_name.class.to_s == 'VariableName'

    @variable_name = variable_name
    @content_type = @variable_name.content_type
    @shape = my_shape
    @constant = false
    @warnings = []
    @valref = :value
    @subscripts = normalize_subscripts(subscripts)
    @wrapped_subscripts = wrapped_subscripts
    @variable = true
    @operand = true
    @precedence = 10
    @arg_types = nil
    @arg_shapes = []
    @arg_consts = []
  end

  def set_content_type(type_stack)
    unless type_stack.empty?
      types = type_stack[-1]

      @arg_types = type_stack.pop if types.class.to_s == 'Array'
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    unless shape_stack.empty?
      shapes = shape_stack[-1]
      @arg_shapes = shape_stack.pop if shapes.class.to_s == 'Array'
    end

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    constant_stack.push(@constant)
  end

  def eql?(other)
    @variable_name == other.name && @subscripts == other.subscripts
  end

  def ==(other)
    @variable_name == other.name && @subscripts == other.subscripts
  end

  def hash
    @variable_name.hash && @subscripts.hash
  end

  def signature
    sig = make_signature(@arg_types, @arg_shapes)
    sig += make_shape_sigil(@shape) if sig.empty?
    sig
  end

  def dump
    result = make_type_sigil(@content_type) + make_shape_sigil(@shape)
    "#{self.class}:#{@variable_name}#{signature} -> #{result}"
  end

  def name
    @variable_name
  end

  def dimensions?
    !@subscripts.empty?
  end

  def dimensions
    @subscripts
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

  def to_s
    if subscripts.empty?
      @variable_name.to_s
    else
      "#{@variable_name}(#{@subscripts.join(',')})"
    end
  end

  def to_v
    to_s
  end

  def to_sw
    if subscripts.empty?
      @variable_name.to_s
    else
      "#{@variable_name}(#{@wrapped_subscripts.join(',')})"
    end
  end

  def evaluate(interpreter, stack)
    x = false
    x = evaluate_value(interpreter, stack) if @valref == :value
    x = evaluate_ref(interpreter, stack) if @valref == :reference
    x
  end

  private

  def evaluate_value(interpreter, stack)
    x = nil
    x = evaluate_value_scalar(interpreter, stack) if @shape == :scalar
    x = evaluate_value_array(interpreter, stack) if @shape == :array
    x = evaluate_value_matrix(interpreter, stack) if @shape == :matrix
    x
  end

  def evaluate_ref(interpreter, stack)
    x = nil
    x = evaluate_ref_scalar(interpreter, stack) if @shape == :scalar

    x = evaluate_ref_compound(interpreter, stack) if
      @shape == :array || @shape == :matrix
    x
  end

  def normalize_subscripts(subscripts)
    raise(BASICSyntaxError, 'Invalid subscripts container') unless
      subscripts.class.to_s == 'Array'

    int_subscripts = []
    subscripts.each do |subscript|
      raise(BASICExpressionError, "Invalid subscript #{subscript}") unless
        subscript.numeric_constant?

      int_subscripts << subscript.truncate
    end

    int_subscripts
  end

  # return a single value
  def evaluate_value_scalar(interpreter, stack)
    if previous_is_array(stack)
      subscripts = get_subscripts(stack)
      @subscripts = interpreter.normalize_subscripts(subscripts)

      @wrapped_subscripts =
        interpreter.wrap_subscripts(@variable_name, @subscripts)

      interpreter.check_subscripts(@variable_name, @subscripts,
                                   @wrapped_subscripts)
    end

    interpreter.get_value(self)
  end

  def get_subscripts(stack)
    subscripts = stack.pop

    if subscripts.empty?
      raise(BASICExpressionError,
            'Variable expects subscripts, found empty parentheses')
    end

    subscripts
  end

  def evaluate_value_array(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)

    msg = "Variable #{@variable_name} has no dimensions"
    raise BASICExpressionError, msg if dims.nil?

    msg = "Array #{@variable_name} requires one dimension"
    raise BASICExpressionError, msg if dims.size != 1

    values = evaluate_value_array_1(interpreter, dims[0].to_i)
    BASICArray.new(dims, values)
  end

  def evaluate_value_array_1(interpreter, n_cols)
    values = {}

    base = $options['base'].value

    (base..n_cols).each do |col|
      coords = AbstractElement.make_coord(col)
      wcoords = interpreter.wrap_subscripts(@variable_name, coords)
      variable = Variable.new(@variable_name, :array, coords, wcoords)
      values[coords] = interpreter.get_value(variable)
    end

    values
  end

  def evaluate_value_matrix(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)

    msg = "Variable #{@variable_name} has no dimensions"
    raise BASICExpressionError, msg if dims.nil?

    # msg = "Matrix #{@variable_name} requires two dimensions"
    # don't check this; it causes problems for special forms
    # raise BASICExpressionError.new(msg) if dims.size != 2

    values = evaluate_matrix_n(interpreter, dims)
    Matrix.new(dims, values)
  end

  def evaluate_matrix_n(interpreter, dims)
    values = {}

    values = evaluate_matrix_1(interpreter, dims[0].to_i) if
      dims.size == 1

    values = evaluate_matrix_2(interpreter, dims[0].to_i, dims[1].to_i) if
      dims.size == 2

    values
  end

  def evaluate_matrix_1(interpreter, n_cols)
    values = {}

    base = $options['base'].value

    (base..n_cols).each do |col|
      coords = AbstractElement.make_coord(col)
      wcoords = interpreter.wrap_subscripts(@variable_name, coords)
      variable = Variable.new(@variable_name, :matrix, coords, wcoords)
      values[coords] = interpreter.get_value(variable)
    end

    values
  end

  def evaluate_matrix_2(interpreter, n_rows, n_cols)
    values = {}

    base = $options['base'].value

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
        coords = AbstractElement.make_coords(row, col)
        wcoords = interpreter.wrap_subscripts(@variable_name, coords)
        variable = Variable.new(@variable_name, :matrix, coords, wcoords)
        values[coords] = interpreter.get_value(variable)
      end
    end

    values
  end

  # return a single value, a reference to this object
  def evaluate_ref_scalar(interpreter, stack)
    if previous_is_array(stack)
      subscripts = stack.pop
      @subscripts = interpreter.normalize_subscripts(subscripts)
      num_args = @subscripts.length

      @wrapped_subscripts =
        interpreter.wrap_subscripts(@variable_name, @subscripts)

      if num_args.zero?
        raise(BASICExpressionError,
              'Variable expects subscripts, found empty parentheses')
      end

      interpreter.check_subscripts(@variable_name, @subscripts,
                                   @wrapped_subscripts)
    end

    self
  end

  # return a single value, a reference to this object
  def evaluate_ref_compound(interpreter, stack)
    if previous_is_array(stack)
      subscripts = stack.pop
      @subscripts = interpreter.normalize_subscripts(subscripts)
      num_args = @subscripts.length

      @wrapped_subscripts =
        interpreter.wrap_subscripts(@variable_name, @subscripts)

      if num_args.zero?
        raise(BASICExpressionError,
              'Variable expects subscripts, found empty parentheses')
      end

      unless @set_dims
        interpreter.check_subscripts(@variable_name, @subscripts,
                                     @wrapped_subscripts)
      end
    end

    self
  end
end

# Class for declaration (in a DIM statement)
class Declaration < AbstractElement
  attr_reader :subscripts, :content_type, :shape, :warnings

  def initialize(variable_name)
    super()

    raise(BASICSyntaxError, "'#{variable_name}' is not a variable name") unless
      variable_name.class.to_s == 'VariableName'

    @variable_name = variable_name
    @subscripts = []
    @variable = true
    @content_type = @variable_name.content_type
    @shape = :unknown
    @warnings = []
    @arg_types = []
    @arg_shapes = []
    @arg_consts = []
  end

  def name
    @variable_name
  end

  def set_content_type(type_stack)
    if !type_stack.empty? && (type_stack[-1].class.to_s == 'Array')
      type_stack.pop
    end

    type_stack.push(@content_type)
  end

  def set_shape(shape_stack)
    raise(BASICExpressionError, "Bad expression #{@name}") if
      shape_stack.empty?

    raise(BASICExpressionError, "Bad expression #{@name} #{shapes}") unless
      shape_stack[-1].class.to_s == 'Array'

    @arg_shapes = shape_stack.pop

    @shape = :scalar
    @shape = :array if @arg_shapes.size == 1
    @shape = :matrix if @arg_shapes.size == 2

    shape_stack.push(@shape)
  end

  def set_constant(constant_stack)
    if !constant_stack.empty? && (constant_stack[-1].class.to_s == 'Array')
      constant_stack.pop
    end

    constant_stack.push(@constant)
  end

  def signature
    make_shape_sigil(@shape)
  end

  def dump
    result = make_type_sigil(@content_type) + make_shape_sigil(@shape)
    "#{self.class}:#{@variable_name}#{signature} -> #{result}"
  end

  def to_s
    if subscripts.empty?
      @variable_name.to_s
    else
      "#{@variable_name}(#{@subscripts.join(',')})"
    end
  end

  # return a single value, a reference to this object
  def evaluate(_, stack)
    if previous_is_array(stack)
      @subscripts = stack.pop
      num_args = @subscripts.length

      if num_args.zero?
        raise(BASICExpressionError,
              'Variable expects subscripts, found empty parentheses')
      end
    end

    self
  end
end

# A list (needed because it has precedence value)
class ExpressionList < AbstractElement
  attr_reader :expressions, :warnings

  def initialize(expressions)
    super()

    @list = true
    @expressions = expressions
    @warnings = []
    @variable = true
    @precedence = 10
  end

  def dump
    lines = []

    @expressions.each { |expression| lines.concat expression.dump }

    lines
  end

  def content_type
    types = []

    @expressions.each { |expression| types << expression.content_type }

    types
  end

  def set_content_type(type_stack)
    @expressions.each(&:set_content_type)

    type_stack.push(content_type)
  end

  def shape
    shapes = []

    @expressions.each { |expression| shapes << expression.shape }

    shapes
  end

  def set_shape(shape_stack)
    @expressions.each(&:set_shape)

    shape_stack.push(shape)
  end

  def constant
    constants = []

    @expressions.each { |expression| constants << expression.constant }

    constants
  end

  def set_constant(constant_stack)
    @expressions.each(&:set_constant)

    constant_stack.push(constant)
  end

  def evaluate(interpreter, _)
    interpreter.evaluate(@expressions)
  end

  def to_s
    "[#{@expressions.join('] [')}]"
  end

  def size
    @expressions.size
  end

  def count
    @expressions.count
  end
end

# class to hold REM text
class Remark < AbstractElement
  def initialize(tokens)
    super()

    @texts = []
    @texts = tokens.map(&:to_s) unless tokens.nil?
  end

  def dump
    "#{self.class}:#{@texts.join}"
  end
end
