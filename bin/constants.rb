
private

def text_to_numeric(text)
  if /\A\s*[+-]?\d+(E\d+)?\z/.match(text)
    text.to_f.to_i
  elsif /\A\s*[+-]?\d+\.(\d*)?(E\d+)?\z/.match(text)
    text.to_f
  elsif /\A\s*[+-]?(\d+)?\.\d*(E\d+)?\z/.match(text)
    text.to_f
  else
    fail BASICException, "'#{text}' is not a number"
  end
end

public

# Numeric constants
class NumericConstant
  def initialize(text)
    numeric_classes = %w(Fixnum Bignum Float)
    if numeric_classes.include?(text.class.to_s)
      @value = text
    else
      @value = text_to_numeric(text)
    end
    @precedence = 0
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

  def operator?
    false
  end

  def function?
    false
  end

  def terminal?
    false
  end

  def variable?
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

  def to_formatted_s(_)
    lead_space = @value >= 0 ? ' ' : ''
    if @value.class.to_s == 'Float'
      lead_space + six_digits(@value).to_s
    else
      lead_space + @value.to_s
    end
  end
end

# Text constants
class TextConstant
  attr_reader :value

  def initialize(text)
    regex = Regexp.new('\A".*"\z')
    if regex.match(text)
      @value = text[1..-2]
    else
      fail BASICException, "'#{text}' is not a text constant"
    end
    @precedence = 0
  end

  def operator?
    false
  end

  def function?
    false
  end

  def terminal?
    false
  end

  def variable?
    false
  end

  def to_s
    "\"#{@value}\""
  end

  def to_formatted_s(_)
    @value
  end
end

# Boolean constants
class BooleanConstant
  attr_reader :value

  def initialize(text)
    @value = text.upcase == 'ON'
    @precedence = 0
  end

  def operator?
    false
  end

  def function?
    false
  end

  def terminal?
    false
  end

  def variable?
    false
  end

  def to_s
    @value ? 'true' : 'false'
  end

  def to_formatted_s(_)
    @value ? 'true' : 'false'
  end
end
