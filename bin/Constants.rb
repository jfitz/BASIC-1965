class NumericConstant < LeafNode
  def initialize(text)
    super
    if text.class.to_s == 'Fixnum' then @value = text
    elsif text =~ /^\d+$/ then @value = text.to_i
    elsif text.class.to_s == 'Float' then @value = text
    elsif text =~ /^\d+\.\d*$/ then @value = text.to_f
    else raise BASICException, "'#{text}' is not a number", caller
    end
  end

  def evaluate(interpreter)
    @value
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

