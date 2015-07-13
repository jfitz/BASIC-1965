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

  def >(rhs)
    if rhs.class.to_s == 'NumericConstant'
      @value > rhs.to_v
    else
      @value > rhs
    end
  end

  def <(rhs)
    if rhs.class.to_s == 'NumericConstant'
      @value < rhs.to_v
    else
      @value < rhs
    end
  end

  def +(rhs)
    if rhs.class.to_s == 'NumericConstant'
      NumericConstant.new(@value + rhs.to_v)
    else
      NumericConstant.new(@value + rhs)
    end
  end

  def is_operator
    false
  end

  def is_function
    false
  end
  
  def is_terminal
    false
  end
  
  def is_variable
    false
  end
  
  def evaluate(interpreter, stack)
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
    decimals = 5 - (value != 0 ? Math.log(value.abs,10).to_i : 0)
    value.round(decimals)
  end
  
  def to_formatted_s(interpreter)
    formatted = @value.class.to_s == 'Float' ? six_digits(@value).to_s : @value.to_s
    if @value >= 0
      formatted = ' ' + formatted
    end
    formatted
  end
end

class TextConstant
  def initialize(text)
    regex = Regexp.new('\A".*"\z')
    if regex.match(text)
      @value = text[1..-2]
    else
      fail BASICException, "'#{text}' is not a text constant"
    end
    @precedence = 0
  end

  def is_operator
    false
  end

  def is_function
    false
  end
  
  def is_terminal
    false
  end
  
  def is_variable
    false
  end
  
  def value
    @value
  end
  
  def to_s
    "\"#{@value}\""
  end
  
  def to_formatted_s(interpreter)
    @value
  end
end

class BooleanConstant
  def initialize(text)
    @value = text.upcase == 'ON'
    @precedence = 0
  end

  def is_operator
    false
  end

  def is_function
    false
  end
  
  def is_terminal
    false
  end
  
  def is_variable
    false
  end
  
  def value
    @value
  end
  
  def to_s
    @value ? 'true' : 'false'
  end
  
  def to_formatted_s(interpreter)
    @value ? 'true' : 'false'
  end
end

