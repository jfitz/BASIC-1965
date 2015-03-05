class VariableRef
  def initialize(text)
    regex = Regexp.new('^[A-Z]\d?$')
    # regex = Regexp.new('^[A-Z]\d?(\(\d{1,2}\))?$')
    raise(BASICException, "'#{text}' is not a variable name", caller) if regex !~ text
    @var_name = text
    @precedence = 0
  end
  
  def is_operator
    false
  end

  def is_list_op
    false
  end

  def is_end_list
    false
  end

  def precedence
    @precedence
  end

  def to_s
    @var_name
  end
end

class NumericExpression
  def initialize(text)
    @variable = nil
    @value = nil
    begin
      @variable = VariableRef.new(text)
    rescue BASICException
      @value = NumericConstant.new(text)
    end
    @precedence = 0
  end
  
  def is_operator
    false
  end
  
  def is_list_op
    false
  end

  def is_end_list
    false
  end

  def precedence
    @precedence
  end

  def evaluate(interpreter)
    if !@variable.nil? then
      interpreter.get_value(@variable)
    else
      @value.evaluate(interpreter)
    end
  end
  
  def to_s
    @variable.nil? ? @value.to_s : @variable.to_s
  end
  
  def six_digits(value)
    decimals = 5 - (value != 0 ? Math.log(value.abs,10).to_i : 0)
    value.round(decimals)
  end
  
  def to_formatted_s(interpreter)
    vvalue = interpreter.get_value(@variable)
    formatted = vvalue.class.to_s == 'Float' ? six_digits(vvalue).to_s : vvalue.to_s
    @variable.nil? ? @value.value : ' ' + formatted
  end
end

class Function
  @@valid_names = [ 'INT', 'RND', 'EXP', 'LOG' ]
  def initialize(text)
    raise(BASICException, "'#{text}' is not a valid function", caller) if !@@valid_names.include?(text)
    @name = text
    @precedence = 0
  end

  def is_operator
    true
  end
  
  def is_list_op
    false
  end

  def is_end_list
    false
  end

  def precedence
    @precedence
  end

  def evaluate(stack)
    case @name
    when 'INT'
      x = stack.pop
      x.to_i
    when 'RND'
      x = stack.pop
      upper_bound = x.truncate.to_f
      upper_bound = 1 if upper_bound <= 0
      $randomizer.rand(upper_bound)
    when 'EXP'
      x = stack.pop
      Math.exp(x)
    when 'LOG'
      x = stack.pop
      x > 0 ? Math.log(x) : 0
    end
  end

  def to_s
    @name + @right.to_s
  end
  
  def to_formatted_s(interpreter)
    @name + @right.to_formatted_s(interpreter)
  end
end

class ArithmeticExpression
  def initialize(text)
    @uncompiled_expression = text
    # split the  input infix string
    words = text.split(/([\+\-\*\/\(\)\^])/)
    # puts "DBG: words=[#{words.join('] [')}]"

    tokens = Array.new
    last_was_operand = false
    # convert tokens to objects
    words.each do | word |
      # puts "DBG: word=#{word}"
      if word.size > 0 then
        begin
          tokens << ListOperator.new(word)
          last_was_operand = false
        rescue BASICException
          begin
            tokens << ListEndOperator.new(word)
            last_was_operand = true
          rescue BASICException
            begin
              if last_was_operand then
                tokens << BinaryOperator.new(word)
              else
                tokens << UnaryOperator.new(word)
              end
              last_was_operand = false
            rescue BASICException
              begin
                tokens << Function.new(word)
                last_was_operand = true
              rescue BASICException
                begin
                  tokens << NumericExpression.new(word)
                  last_was_operand = true
                rescue
                  raise BASICException, "'#{word}' is not a value or operator", caller
                end
              end
            end
          end
        end
      end
    end

    # stack for operators
    operator_stack = Array.new
    # list for compiled expression (postfix)
    @compiled_expression = Array.new

    # scan the token list from left to right
    tokens.each do | token |
      if token != '' then
        # If the token is an operand, append it to the end of the output list
        if not token.is_operator then
          @compiled_expression << token
        else
          # If the token is a left parenthesis, push it on the opstack
          if token.is_list_op then
            operator_stack.push(token)
          else
            # If the token is a right parenthesis,
            # pop the opstack until the corresponding left parenthesis is removed
            # Append each operator to the end of the output list
            if token.is_end_list then
              while operator_stack.size > 0 and not operator_stack[-1].is_list_op do
                @compiled_expression << operator_stack.pop
              end
              operator_stack.pop
            else
              # First remove any operators already on the stack that have higher or equal precedence
              # and append them to the output list
              while operator_stack.size > 0 and operator_stack[-1].precedence >= token.precedence do
                @compiled_expression << operator_stack.pop
              end
              # push the token onto the stack
              operator_stack.push(token)
            end
          end
        end
      end
    end
    # Any operators still on the stack can be removed and appended to the end of the output list
    while operator_stack.size > 0 do
      @compiled_expression << operator_stack.pop
    end
  end

  def is_operator
    false
  end
  
  def is_list_op
    false
  end

  def is_end_list
    false
  end

  def evaluate(interpreter)
    interpreter.evaluate(@compiled_expression)
  end
  
  def to_s
    @uncompiled_expression
  end
end

class PrintableExpression
  def initialize(text)
    @numeric_expression = nil
    @text_constant = nil
    begin
      @text_constant = TextConstant.new(text)
    rescue BASICException => message
      @numeric_expression = ArithmeticExpression.new(text)
    end
  end
  
  def to_s
    if @numeric_expression.nil? then
      @text_constant.to_s
    else
      @numeric_expression.to_s
    end
  end
  
  def six_digits(value)
    decimals = 5 - (value != 0 ? Math.log(value.abs,10).to_i : 0)
    value.round(decimals)
  end
  
  def to_formatted_s(interpreter)
    if @numeric_expression.nil? then
      @text_constant.to_formatted_s(interpreter)
    else
      vvalue = @numeric_expression.evaluate(interpreter)
      formatted = vvalue.class.to_s == 'Float' ? six_digits(vvalue).to_s : vvalue.to_s
      vvalue < 0 ? formatted : ' ' + formatted
    end
  end
end

class BooleanExpression
  def initialize(text)
    parts = text.split(/\s*([=<>]+)\s*/)
    raise(BASICException, "'#{text}' is not a boolean expression", caller) if parts.size != 3
    @a = ArithmeticExpression.new(parts[0])
    @operator = BooleanOperator.new(parts[1])
    @b = ArithmeticExpression.new(parts[2])
  end
  
  def evaluate(interpreter)
    case @operator.to_s
    when '='
        @a.evaluate(interpreter) == @b.evaluate(interpreter)
    when '<>'
        @a.evaluate(interpreter) != @b.evaluate(interpreter)
    when '<'
        @a.evaluate(interpreter) < @b.evaluate(interpreter)
    when '>'
        @a.evaluate(interpreter) > @b.evaluate(interpreter)
    when '<='
        @a.evaluate(interpreter) <= @b.evaluate(interpreter)
    when '>='
        @a.evaluate(interpreter) >= @b.evaluate(interpreter)
    end
  end
  
  def to_s
    @a.to_s + ' ' + @operator.to_s + ' ' + @b.to_s
  end
end

class Assignment
  def initialize(text)
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    raise(BASICException, "'#{text}' is not a valid assignment", caller) if parts.size != 2
    @target = VariableRef.new(parts[0])
    @expression = ArithmeticExpression.new(parts[1])
  end

  def target
    @target
  end
  
  def value(interpreter)
    @expression.evaluate(interpreter)
  end
  
  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end

  def to_postfix_s
    @expression.to_postfix_s
  end
end

