class NumericConstant
  def initialize(text)
    int_regex = Regexp.new('^\d+$')
    float_regex = Regexp.new('^\d+\.\d*$')
    if text.class.to_s == 'Fixnum' then @value = text
    elsif text.class.to_s == 'Float' then @value = text
    elsif int_regex.match(text) then @value = text.to_i
    elsif float_regex.match(text) then @value = text.to_f
    else raise BASICException, "'#{text}' is not a number", caller
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
    @value < 0 ? formatted : ' ' + formatted
  end
end

class TextConstant
  def initialize(text)
    if text =~ /^".*"$/ then @value = text[1..-2]
    else raise BASICException, "'#{text}' is not a text constant", caller
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

