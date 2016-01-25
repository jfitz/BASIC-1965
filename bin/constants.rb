
private

def text_to_numeric(text)
  if /\A\s*[+-]?\d+(E\d+)?\z/.match(text)
    text.to_f.to_i
  elsif /\A\s*[+-]?\d+\.(\d*)?(E\d+)?\z/.match(text)
    text.to_f
  elsif /\A\s*[+-]?(\d+)?\.\d*(E\d+)?\z/.match(text)
    text.to_f
  elsif /\A\s*[+-]?\d+\.(\d*)?(E[+-]?\d+)?\z/.match(text)
    text.to_f
  elsif /\A\s*[+-]?(\d+)?\.\d*(E[+-]?\d+)?\z/.match(text)
    text.to_f
  end
end

public

# token class
class AbstractToken
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
end

# beginning of a group
class GroupStart < AbstractToken
  def initialize
    @group_start = true
  end
end

# end of a group
class GroupEnd < AbstractToken
  def initialize
    @group_end = true
    @operand = true
  end
end

# beginning of a set of parameters
class ParamStart < AbstractToken
  def initialize
    @param_start = true
  end
end

# separator for group or params
class ParamSeparator < AbstractToken
  def initialize
    @separator = true
  end
end

# Numeric constants
class NumericConstant < AbstractToken
  def self.init?(text)
    numeric_classes = %w(Fixnum Bignum Float)
    numeric_classes.include?(text.class.to_s) || !text_to_numeric(text).nil?
  end

  def initialize(text)
    numeric_classes = %w(Fixnum Bignum Float)
    if numeric_classes.include?(text.class.to_s)
      @value = text
    else
      @value = text_to_numeric(text)
    end
    @operand = true
    @precedence = 0
    fail BASICException, "'#{text}' is not a number" if @value.nil?
  end

  def ==(other)
    if other.class.to_s == 'NumericConstant'
      @value == other.to_v
    else
      @value == other
    end
  end

  def >(other)
    if other.class.to_s == 'NumericConstant'
      @value > other.to_v
    else
      @value > other
    end
  end

  def <(other)
    if other.class.to_s == 'NumericConstant'
      @value < other.to_v
    else
      @value < other
    end
  end

  def +(other)
    if other.class.to_s == 'NumericConstant'
      NumericConstant.new(@value + other.to_v)
    else
      NumericConstant.new(@value + other)
    end
  end

  def matrix?
    false
  end

  def evaluate(_, _)
    self
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

  def to_formatted_s
    lead_space = @value >= 0 ? ' ' : ''
    if @value.class.to_s == 'Float'
      lead_space + six_digits(@value).to_s
    else
      lead_space + @value.to_s
    end
  end
end

# Text constants
class TextConstant < AbstractToken
  def self.init?(text)
    /\A".*"\z/.match(text)
  end

  attr_reader :value

  def initialize(text)
    if TextConstant.init?(text)
      @value = text[1..-2]
    else
      fail BASICException, "'#{text}' is not a text constant"
    end
    @operand = true
    @precedence = 0
  end

  def to_s
    "\"#{@value}\""
  end

  def to_formatted_s
    @value
  end
end

# Boolean constants
class BooleanConstant < AbstractToken
  attr_reader :value

  def initialize(text)
    @value = text.upcase == 'ON'
    @operand = true
    @precedence = 0
  end

  def to_s
    @value ? 'true' : 'false'
  end

  def to_formatted_s
    @value ? 'true' : 'false'
  end
end
