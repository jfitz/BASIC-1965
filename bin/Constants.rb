class NumericConstant
  def initialize(text)
    int_regex = Regexp.new('\A\s*[+-]?\d+(E\d+)?\z')
    float1_regex = Regexp.new('\A\s*[+-]?\d+\.(\d*)?(E\d+)?\z')
    float2_regex = Regexp.new('\A\s*[+-]?(\d+)?\.\d*(E\d+)?\z')
    if text.class.to_s == 'Fixnum'
      @value = text
    elsif text.class.to_s == 'Bignum'
      @value = text
    elsif text.class.to_s == 'Float'
      @value = text
    elsif int_regex.match(text)
      @value = text.to_f.to_i
    elsif float1_regex.match(text)
      @value = text.to_f
    elsif float2_regex.match(text)
      @value = text.to_f
    else
      fail BASICException, "'#{text}' is not a number"
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
    formatted = @value.class.to_s == 'Float' ? six_digits(@value).to_s : @value.to_s
    lead_space + formatted
  end
end

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

