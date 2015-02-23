class UnaryOperator < UnaryNode
  @@operators = { '+' => 9, '-' => 9 }
  def initialize(text)
    # puts "DBG: UnaryOperator.initialize(#{text})"
    super
    raise(BASICException, "'#{text}' is not an operator", caller) if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end
  
  def evaluate(interpreter)
    case @op
    when '+'
        posate(@right.evaluate(interpreter))
    when '-'
        negate(@right.evaluate(interpreter))
    end
  end

  def posate(a)
    f = NumericConstant.new(a.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def negate(a)
    f = NumericConstant.new(- a.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def to_s
    @op
  end
end

class ListOperator < ListNode
  @@operators = { '(' => 8 }
  def initialize(text)
    # puts "DBG: ListOperator.initialize(#{text})"
    super()
    raise(BASICException, "'#{text}' is not an operator", caller) if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end
  
  def evaluate(interpreter)
    # @left != nil ? @left.evaluate(interpreter) : @right.evaluate(interpreter)
    evaluate_n(interpreter, 0)
  end
  
  def evaluate_n(interpreter, index)
    case index
    when 0..list_count
      @list[index].evaluate(interpreter)
    else
      0
    end
  end

  def to_s
    infix_string
  end
end

class ListEndOperator < ListEndNode
  @@operators = { ')' => 8 }
  def initialize(text)
    # puts "DBG: ListEndOperator.initialize(#{text})"
    super()
    raise(BASICException, "'#{text}' is not an operator", caller) if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end
  
  def to_s
    @op
  end
end

class BinaryOperator < BinaryNode
  @@operators = { '+' => 1, '-' => 1, '*' => 2, '/' => 2, '^' => 3 }
  def initialize(text)
    # puts "DBG: BinaryOperator.initialize(#{text})"
    super
    raise(BASICException, "'#{text}' is not an operator", caller) if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end
  
  def evaluate(interpreter)
    case @op
    when '+'
        add(@left.evaluate(interpreter), @right.evaluate(interpreter))
    when '-'
        subtract(@left.evaluate(interpreter), @right.evaluate(interpreter))
    when '*'
        multiply(@left.evaluate(interpreter), @right.evaluate(interpreter))
    when '/'
        divide(@left.evaluate(interpreter), @right.evaluate(interpreter))
    when '^'
        power(@left.evaluate(interpreter), @right.evaluate(interpreter))
    end
  end

  def add(a, b)
    f = NumericConstant.new(a.to_f + b.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def subtract(a, b)
    f = NumericConstant.new(a.to_f - b.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def multiply(a, b)
    f = NumericConstant.new(a.to_f * b.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def divide(a, b)
    f = NumericConstant.new(a.to_f / b.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def power(a, b)
    f = NumericConstant.new(a.to_f ** b.to_f)
    i = NumericConstant.new(f.to_i)
    (f.evaluate(nil) - i.evaluate(nil)).abs < 1e-8 ? i : f
  end
  
  def to_s
    @op
  end
end

class BooleanOperator
  @@valid_operators = [ '=', '<', '>', '>=', '<=', '<>' ]
  def initialize(text)
    raise(BASICException, "'#{text}' is not a valid boolean operator", caller) if !@@valid_operators.include?(text)
    @value = text
  end
  
  def to_s
    @value
  end
end

