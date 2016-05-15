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
    @precedence = 10
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

  protected

  def make_coord(c)
    '(' + c.to_s + ')'
  end

  def make_coords(r, c)
    '(' + r.to_s + ',' + c.to_s + ')'
  end
end

# beginning of a group
class GroupStart < AbstractElement
  def self.init?(text)
    text == '('
  end

  def initialize(_)
    super()
    @group_start = true
  end
end

# end of a group
class GroupEnd < AbstractElement
  def self.init?(text)
    text == ')'
  end

  def initialize(_)
    super()
    @group_end = true
    @operand = true
  end
end

# beginning of a set of parameters
class ParamStart < AbstractElement
  def initialize
    super
    @param_start = true
  end
end

# separator for group or params
class ParamSeparator < AbstractElement
  def self.init?(text)
    text == ',' || text == ';'
  end

  def initialize(_)
    super()
    @separator = true
  end
end

private

def text_to_numeric(text)
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

public

# Numeric constants
class NumericConstant < AbstractElement
  def self.init?(text)
    numeric_classes = %w(Fixnum Bignum Float)
    numeric_classes.include?(text.class.to_s) || !text_to_numeric(text).nil?
  end

  private

  def float_to_possible_int(f)
    i = f.to_i
    (f - i).abs < 1e-8 ? i : f
  end

  public

  def initialize(text)
    super()
    numeric_classes = %w(Fixnum Bignum Float)
    f = numeric_classes.include?(text.class.to_s) ? text : text_to_numeric(text)
    @value = float_to_possible_int(f)
    @operand = true
    @precedence = 0
    raise BASICException, "'#{text}' is not a number" if @value.nil?
  end

  def ==(other)
    @value == other.to_v
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
    NumericConstant.new(@value + other.to_v)
  end

  def -(other)
    NumericConstant.new(@value - other.to_v)
  end

  def *(other)
    NumericConstant.new(@value * other.to_v)
  end

  def /(other)
    raise(BASICException, 'Divide by zero') if other == NumericConstant.new(0)
    NumericConstant.new(@value.to_f / other.to_v.to_f)
  end

  def **(other)
    NumericConstant.new(@value**other.to_v)
  end

  def matrix?
    false
  end

  def evaluate(_, _)
    self
  end

  def truncate
    NumericConstant.new(@value.to_i)
  end

  def exp
    NumericConstant.new(Math.exp(@value))
  end

  def log
    NumericConstant.new(@value > 0 ? Math.log(@value) : 0)
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

  def to_v
    @value
  end

  def to_s
    @value.to_s
  end

  def six_digits(value)
    decimals = 5 - (value != 0 ? Math.log(value.abs, 10).to_i : 0)
    value.round(decimals)
  end

  def print(printer)
    s = to_formatted_s
    printer.print_item s
    printer.last_was_numeric
  end

  private

  def to_formatted_s
    lead_space = @value >= 0 ? ' ' : ''
    digits = six_digits(@value).to_s
    # remove trailing zeros and decimal point
    digits = digits.sub(/0+\z/, '').sub(/\.\z/, '') if
      digits.include?('.') && !digits.include?('e')
    lead_space + digits
  end
end

# Text constants
class TextConstant < AbstractElement
  def self.init?(text)
    /\A".*"\z/.match(text)
  end

  attr_reader :value

  def initialize(text)
    super()
    if TextConstant.init?(text)
      @value = text[1..-2]
    else
      raise BASICException, "'#{text}' is not a text constant"
    end
    @operand = true
    @precedence = 0
  end

  def evaluate(_, _)
    self
  end

  def printable?
    true
  end

  def to_s
    "\"#{@value}\""
  end

  def print(printer)
    printer.print_item @value
  end
end

# Boolean constants
class BooleanConstant < AbstractElement
  attr_reader :value

  def initialize(text)
    super()
    @value = text.to_s.casecmp('ON') == 0
    @operand = true
    @precedence = 0
  end

  def to_s
    @value ? 'true' : 'false'
  end
end

# Carriage control for PRINT and MAT PRINT statements
class CarriageControl
  def self.init?(text)
    ['NL', ',', ';', ''].include?(text)
  end

  def initialize(text)
    raise(BASICException, "'#{text}' is not a valid separator") unless
      CarriageControl.init?(text)
    @operator = text
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

  def print(printer, _)
    case @operator
    when ','
      printer.tab
    when ';'
      printer.semicolon
    when 'NL'
      printer.newline
    when ''
      # do nothing
    end
  end
end

# Hold a variable name (not a reference or value)
class VariableName < AbstractElement
  def self.init?(text)
    /\A[A-Z]\d?\z/.match(text)
  end

  def initialize(text)
    super()
    raise(BASICException, "'#{text}' is not a variable name") unless
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
    raise(BASICException, "'#{variable_name}' is not a variable name") if
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
    if subscripts.empty?
      @variable_name.to_s
    else
      @variable_name.to_s + '(' + @subscripts.join(',') + ')'
    end
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
    raise(BASICException, 'No arguments for function') if
      args.class.to_s != 'Array'
  end

  def check_value(value, type)
    raise(BASICException,
          "Argument #{x} #{x.class} not of type #{type.class}") if
      value.class.to_s != type
  end

  def check_arg_types(args, types)
    check_args(args)
    n_types = types.size
    n_args = args.size
    raise(BASICException,
          "Function #{@name} expects #{n_types} argument, found #{n_args}") if
      n_args != n_types
    (0..types.size - 1).each do |i|
      check_value(args[i], types[i])
    end
  end
end
