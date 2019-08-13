# token class
class AbstractElement
  attr_reader :precedence

  def initialize
    @operator = false
    @function = false
    @variable = false
    @operand = false
    @terminal = false
    @group_start = false
    @group_end = false
    @param_start = false
    @separator = false
    @file_handle = false
    @precedence = 10
    @shape = nil
    @list = false
    @carriage = false
    @value = false
    @reference = false
    @numeric_constant = false
    @text_constant = false
    @boolean_constant = false
  end

  def dump
    self.class.to_s + ':' + 'Unimplemented'
  end

  def operator?
    @operator
  end

  def function?
    @function
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
    @value
  end

  def reference?
    @reference
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

  protected

  def make_coord(c)
    [NumericConstant.new(c)]
  end

  def make_coords(r, c)
    [NumericConstant.new(r), NumericConstant.new(c)]
  end
end

# beginning of a group
class GroupStart < AbstractElement
  def self.accept?(token)
    classes = %w(GroupStartToken)
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
    classes = %w(GroupEndToken)
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
    classes = %w(ParamSeparatorToken)
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
  def initialize
    super

    @operand = true
    @precedence = 0
    @shape = :scalar
    @value = nil
  end

  def dump
    self.class.to_s + ':' + to_s
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
    raise(BASICRuntimeError, message) unless compatible?(other)
    @value == other.to_v
  end

  def >(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in >"
    raise(BASICRuntimeError, message) unless compatible?(other)
    @value > other.to_v
  end

  def >=(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in >="
    raise(BASICRuntimeError, message) unless compatible?(other)
    @value >= other.to_v
  end

  def <(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in <"
    raise(BASICRuntimeError, message) unless compatible?(other)
    @value < other.to_v
  end

  def <=(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in <="
    raise(BASICRuntimeError, message) unless compatible?(other)
    @value <= other.to_v
  end

  def b_eq(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_eq()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    BooleanConstant.new(@value == other.to_v)
  end

  def b_ne(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_ne()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    BooleanConstant.new(@value != other.to_v)
  end

  def b_gt(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_gt()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    BooleanConstant.new(@value > other.to_v)
  end

  def b_ge(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_ge()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    BooleanConstant.new(@value >= other.to_v)
  end

  def b_lt(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_lt()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    BooleanConstant.new(@value < other.to_v)
  end

  def b_le(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in b_le()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    BooleanConstant.new(@value <= other.to_v)
  end

  def +(_)
    raise(BASICRuntimeError, 'Invalid operator +')
  end

  def -(_)
    raise(BASICRuntimeError, 'Invalid operator -')
  end

  def add(_)
    raise(BASICRuntimeError, 'Invalid operator add')
  end

  def subtract(_)
    raise(BASICRuntimeError, 'Invalid operator subtract')
  end

  def multiply(_)
    raise(BASICRuntimeError, 'Invalid operator multiply')
  end

  def divide(_)
    raise(BASICRuntimeError, 'Invalid operator divide')
  end

  def power(_)
    raise(BASICRuntimeError, 'Invalid operator power')
  end

  def printable?
    true
  end

  def evaluate(_, _)
    self
  end

  def to_v
    @value
  end

  private

  def compatible?(other)
    other.content_type == content_type
  end
end

# Numeric constants
class NumericConstant < AbstractValueElement
  def self.accept?(token)
    classes = %w(Fixnum Integer Bignum Float NumericConstantToken)
    classes.include?(token.class.to_s)
  end

  def self.numeric(text)
    # nnn(E+nn)
    if /\A\s*[+-]?\d+(E+?\d+)?\z/ =~ text
      text.to_f.to_i
    # nnn(E-nn)
    elsif /\A\s*[+-]?\d+(E-\d+)?\z/ =~ text
      text.to_f
    # nnn.(nnn)(E+-nn)
    elsif /\A\s*[+-]?\d+\.(\d*)?(E[+-]?\d+)?\z/ =~ text
      text.to_f
    # (nnn).nnn(E+-nn)
    elsif /\A\s*[+-]?(\d+)?\.\d*(E[+-]?\d+)?\z/ =~ text
      text.to_f
    end
  end

  private

  def float_to_possible_int(f)
    i = f.to_i
    frac = f - i
    frac.zero? || (!i.zero? && frac.abs < 1e-7) ? i : f
  end

  public

  attr_reader :token_chars

  def initialize(text)
    super()

    numeric_classes = %w(Fixnum Integer Bignum Float)
    float_classes = %w(Rational NumericConstantToken)

    f = nil
    f = text.to_f if float_classes.include?(text.class.to_s)
    f = text if numeric_classes.include?(text.class.to_s)

    raise(BASICRuntimeError, "'#{text}' is not a number") if f.nil?

    epsilon = $options['epsilon'].value
    f = 0 if f.abs < epsilon

    @token_chars = text.to_s
    @value = float_to_possible_int(f)
    @numeric_constant = true
  end

  def zero?
    @value.zero?
  end

  def content_type
    'numeric'
  end

  def eql?(other)
    @value == other.to_v
  end

  def ==(other)
    @value == other.to_v
  end

  def hash
    @value.hash + @token_chars.hash
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
    raise(BASICRuntimeError, message) unless compatible?(other)
    NumericConstant.new(@value + other.to_v)
  end

  def -(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in -()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    NumericConstant.new(@value - other.to_v)
  end

  def add(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in add()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    NumericConstant.new(@value + other.to_v)
  end

  def subtract(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in subtract()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    NumericConstant.new(@value - other.to_v)
  end

  def multiply(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in multiply()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    NumericConstant.new(@value * other.to_v)
  end

  def divide(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in divide()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    raise(BASICRuntimeError, 'Divide by zero') if other.zero?
    NumericConstant.new(@value.to_f / other.to_v.to_f)
  end

  def power(other)
    message = "Type mismatch (#{content_type}/#{other.content_type}) in power()"
    raise(BASICRuntimeError, message) unless compatible?(other)
    NumericConstant.new(@value**other.to_v)
  end

  def negate
    NumericConstant.new(-(@value))
  end

  def truncate
    NumericConstant.new(@value.to_i)
  end

  def floor
    NumericConstant.new(@value.floor)
  end

  def exp
    NumericConstant.new(Math.exp(@value))
  end

  def log
    NumericConstant.new(@value > 0 ? Math.log(@value) : 0)
  end

  def mod(other)
    NumericConstant.new(other.to_v != 0 ? @value % other.to_v : 0)
  end

  def abs
    NumericConstant.new(@value >= 0 ? @value : -@value)
  end

  def sqrt
    NumericConstant.new(@value > 0 ? Math.sqrt(@value) : 0)
  end

  def sin
    NumericConstant.new(Math.sin(@value))
  end

  def cos
    NumericConstant.new(Math.cos(@value))
  end

  def tan
    NumericConstant.new(@value >= 0 ? Math.tan(@value) : 0)
  end

  def atn
    NumericConstant.new(Math.atan(@value))
  end

  def sign
    result = 0
    result = 1 if @value > 0
    result = -1 if @value < 0
    NumericConstant.new(result)
  end

  def to_i
    @value.to_i
  end

  def to_f
    @value.to_f
  end

  def to_s
    @value.to_s
  end

  def decimal_digits(value)
    decimals = $options['decimals'].value
    num_decimals = decimals - (value != 0 ? Math.log(value.abs, 10).to_i : 0)
    rounded = value.round(num_decimals)
    rounded.to_f
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

  private

  def to_formatted_s
    lead_space = @value >= 0 ? ' ' : ''
    digits = decimal_digits(@value).to_s

    # remove trailing zeros and decimal point
    ### make this optional
    digits = digits.sub(/0+\z/, '').sub(/\.\z/, '') if
      digits.include?('.') && !digits.include?('e')

    lead_space + digits
  end

  def compatible?(other)
    other.numeric_constant?
  end
end

# Text constants
class TextConstant < AbstractValueElement
  def self.accept?(token)
    classes = %w(TextConstantToken)
    classes.include?(token.class.to_s)
  end

  attr_reader :value

  def initialize(text)
    super()

    @value = nil
    @value = text.value if text.class.to_s == 'TextConstantToken'
    raise(BASICSyntaxError, "'#{text}' is not a text constant") if @value.nil?
    @text_constant = true
  end

  def content_type
    'string'
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

  def to_s
    "\"#{@value}\""
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
    classes = %w(BooleanConstantToken)
    classes.include?(token.class.to_s)
  end

  attr_reader :value

  def initialize(obj)
    super()

    obj_class = obj.class.to_s

    @value =
      (obj_class == 'BooleanConstantToken' && obj.to_s == 'TRUE') ||
      (obj_class == 'String' && obj.casecmp('TRUE').zero?) ||
      obj_class == 'TrueClass'

    @boolean_constant = true
  end

  def content_type
    'bool'
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

  def to_s
    @value ? 'true' : 'false'
  end
end

# File handle class
class FileHandle < AbstractElement
  attr_reader :number

  def initialize(num)
    super()

    raise(BASICRuntimeError, 'Invalid file reference') unless
      ['Fixnum', 'Integer'].include?(num.class.to_s)

    raise(BASICRuntimeError, 'Invalid file number') if num < 0

    @number = num
    @file_handle = true
  end

  def hash
    @number.hash
  end

  def eql?(other)
    @number == other.number
  end

  def to_s
    '#' + @number.to_s
  end
end

# Carriage control for PRINT and MAT PRINT statements
class CarriageControl
  def self.accept?(token)
    classes = %w(ParamSeparatorToken)
    classes.include?(token.class.to_s)
  end

  def initialize(token)
    @operator = token.to_s
    @carriage = true
    @file_handle = false
  end

  def printable?
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
    [self.class.to_s + ':' + @operator]
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

  def variables
    []
  end

  def print(printer, _)
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

  def write(printer, _)
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

# Hold a variable name (not a reference or value)
class VariableName < AbstractElement
  def self.accept?(token)
    classes = %w(VariableToken)
    classes.include?(token.class.to_s)
  end

  attr_reader :name
  attr_reader :content_type

  def initialize(token)
    super()

    raise(BASICSyntaxError, "'#{token}' is not a variable name") unless
      token.class.to_s == 'VariableToken' ||
      token.class.to_s == 'UserFunctionToken'

    @name = token
    @variable = true
    @operand = true
    @precedence = 7
    @content_type = 'numeric'
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

  def dump
    self.class.to_s + ':' + @name.to_s
  end

  def compatible?(value)
    numerics = %w(numeric)
    strings = %w(string)

    compatible = false

    if content_type == 'numeric'
      compatible = numerics.include?(value.content_type)
    end

    if content_type == 'string'
      compatible = strings.include?(value.content_type)
    end

    compatible
  end

  def to_s
    @name.to_s
  end
end

# Hold a variable (name with possible subscripts and value)
class Variable < AbstractElement
  attr_reader :subscripts

  def initialize(variable_name, subscripts = [])
    super()

    raise(BASICSyntaxError, "'#{variable_name}' is not a variable name") if
      variable_name.class.to_s != 'VariableName' &&
      variable_name.class.to_s != 'UserFunctionToken'

    @variable_name = variable_name
    @subscripts = normalize_subscripts(subscripts)
    @variable = true
    @operand = true
    @precedence = 7
  end

  def dump
    self.class.to_s + ':' + @variable_name.to_s
  end

  def name
    @variable_name
  end

  def content_type
    @variable_name.content_type
  end

  def compatible?(value)
    numerics = %w(numeric)
    strings = %w(string)

    compatible = false

    if content_type == 'numeric'
      compatible = numerics.include?(value.content_type)
    end

    if content_type == 'string'
      compatible = strings.include?(value.content_type)
    end

    compatible
  end

  def to_s
    if subscripts.empty?
      @variable_name.to_s
    else
      @variable_name.to_s + '(' + @subscripts.join(',') + ')'
    end
  end

  private

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
end

class Value < Variable
  def initialize(name, shape, subscripts = [])
    super(name, subscripts)

    @value = true
    @shape = shape
  end

  def evaluate(interpreter, stack)
    x = evaluate_scalar(interpreter, stack) if @shape == :scalar
    x = evaluate_array(interpreter, stack) if @shape == :array
    x = evaluate_matrix(interpreter, stack) if @shape == :matrix
    x
  end

  private
  
  # return a single value
  def evaluate_scalar(interpreter, stack)
    if previous_is_array(stack)
      subscripts = get_subscripts(stack)
      @subscripts = interpreter.normalize_subscripts(subscripts)
      interpreter.check_subscripts(@variable_name, @subscripts)
      interpreter.get_value(self)
    else
      interpreter.get_value(@variable_name)
    end
  end

  def get_subscripts(stack)
    subscripts = stack.pop

    if subscripts.empty?
      raise(BASICExpressionError,
            'Variable expects subscripts, found empty parentheses')
    end

    subscripts
  end

  def evaluate_array(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)
    raise(BASICRuntimeError, 'Variable has no dimensions') if dims.nil?
    raise(BASICRuntimeError, 'Array requires one dimension') if dims.size != 1
    values = evaluate_array_1(interpreter, dims[0].to_i)
    BASICArray.new(dims, values)
  end

  def evaluate_array_1(interpreter, n_cols)
    values = {}
    base = interpreter.base
    (base..n_cols).each do |col|
      coords = make_coord(col)
      variable = Value.new(@variable_name, :array, coords)
      values[coords] = interpreter.get_value(variable)
    end

    values
  end

  def evaluate_matrix(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)
   raise(BASICRuntimeError, 'Variable has no dimensions') if dims.nil?
    values = evaluate_matrix_n(interpreter, dims)
    Matrix.new(dims, values)
  end

  def evaluate_matrix_n(interpreter, dims)
    values = {}
    values = evaluate_matrix_1(interpreter, dims[0].to_i) if dims.size == 1

    values = evaluate_matrix_2(interpreter, dims[0].to_i, dims[1].to_i) if
      dims.size == 2

    values
  end

  def evaluate_matrix_1(interpreter, n_cols)
    values = {}

    base = $options['base'].value
    
    (base..n_cols).each do |col|
      coords = make_coord(col)
      variable = Value.new(@variable_name, :matrix, coords)
      values[coords] = interpreter.get_value(variable)
    end

    values
  end

  def evaluate_matrix_2(interpreter, n_rows, n_cols)
    values = {}

    base = $options['base'].value
    
    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
        coords = make_coords(row, col)
        variable = Value.new(@variable_name, :matrix, coords)
        values[coords] = interpreter.get_value(variable)
      end
    end

    values
  end
end

class Reference < Variable
  def initialize(name, shape, subscripts = [])
    super(name, subscripts)

    @reference = true
    @shape = shape
  end

  def evaluate(interpreter, stack)
    x = evaluate_scalar(interpreter, stack) if @shape == :scalar
    x = evaluate_compound(interpreter, stack) if
      @shape == :array || @shape == :matrix
    x
  end

  def dimensions?
    !@subscripts.empty?
  end

  def dimensions
    @subscripts
  end

  private
  
  # return a single value, a reference to this object
  def evaluate_scalar(interpreter, stack)
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
  def evaluate_compound(interpreter, stack)
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

class Declaration < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  # return a single value, a reference to this object
  def evaluate(_, stack)
    if previous_is_array(stack)
      @subscripts = stack.pop
      num_args = @subscripts.length

      if num_args.zero?
        raise(BASICRuntimeError,
              'Variable expects subscripts, found empty parentheses')
      end
    end

    self
  end
end

# A list (needed because it has precedence value)
class List < AbstractElement
  def initialize(parsed_expressions)
    super()

    @list = true
    @parsed_expressions = parsed_expressions
    @variable = true
    @precedence = 7
  end

  def list
    @parsed_expressions
  end

  def dump
    lines = []

    @parsed_expressions.each do |expression|
      expression.each { |exp| lines << exp.dump }

    end
    lines
  end

  def evaluate(interpreter, _)
    interpreter.evaluate(@parsed_expressions)
  end

  def to_s
    "[#{@parsed_expressions.join('] [')}]"
  end

  def size
    @parsed_expressions.size
  end

  def count
    @parsed_expressions.count
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
    self.class.to_s + ':' + @texts.join
  end
end
