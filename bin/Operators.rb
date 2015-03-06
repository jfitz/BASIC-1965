class UnaryOperator
  @@operators = { '+' => 5, '-' => 5 }
  def initialize(text)
    raise(BASICException, "'#{text}' is not an operator", caller) if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end

  def is_operator
    true
  end
  
  def precedence
    @precedence
  end

  def evaluate(stack)
    x = stack.pop
    case @op
    when '+'
      z = posate(x)
    when '-'
      z = negate(x)
    end
    z
  end

  def posate(a)
    f = a.to_f
    i = f.to_i
    (f - i).abs < 1e-8 ? i : f
  end
  
  def negate(a)
    f = -a.to_f
    i = f.to_i
    (f - i).abs < 1e-8 ? i : f
  end
  
  def to_s
    @op
  end
end

class BinaryOperator
  @@operators = { '+' => 2, '-' => 2, '*' => 3, '/' => 3, '^' => 4 }
  def initialize(text)
    raise(BASICException, "'#{text}' is not an operator", caller) if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end
  
  def is_operator
    true
  end
  
  def precedence
    @precedence
  end

  def evaluate(stack)
    y = stack.pop
    x = stack.pop
    case @op
    when '+'
      z = add(x, y)
    when '-'
      z = subtract(x, y)
    when '*'
      z = multiply(x, y)
    when '/'
      z = divide(x, y)
    when '^'
      z = power(x, y)
    end
    z
  end

  def add(a, b)
    f = a.to_f + b.to_f
    i = f.to_i
    (f - i).abs < 1e-8 ? i : f
  end
  
  def subtract(a, b)
    f = a.to_f - b.to_f
    i = f.to_i
    (f. - i).abs < 1e-8 ? i : f
  end
  
  def multiply(a, b)
    f = a.to_f * b.to_f
    i = f.to_i
    (f - i).abs < 1e-8 ? i : f
  end
  
  def divide(a, b)
    f = a.to_f / b.to_f
    i = f.to_i
    (f. - i).abs < 1e-8 ? i : f
  end
  
  def power(a, b)
    f = a.to_f ** b.to_f
    i = f.to_i
    (f - i).abs < 1e-8 ? i : f
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
    @precedence = 1
  end
  
  def is_operator
    true
  end
  
  def precedence
    @precedence
  end

  def to_s
    @value
  end
end

