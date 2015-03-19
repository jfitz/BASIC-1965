class Variable
  def initialize(text)
    regex = Regexp.new('^[A-Z]\d?$')
    raise(Exception, "'#{text}' is not a variable name", caller) if not regex.match(text)
    @var_name = text
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
    true
  end
  
  def precedence
    5
  end
  
  def to_s
    @var_name
  end
end

class VariableValue < Variable
  def initialize(text)
    super
  end
  
  def evaluate(interpreter, stack)
    if stack.size > 0 and stack[-1].class.to_s == 'ArgumentCounter' then
      num_args = stack.pop
      raise(BASICException, "Variable expects subscripts, found empty parentheses", caller) if num_args.value == 0
      subs = Array.new
      (1..num_args.value).each do | index |
        subs << stack.pop
      end
      evaled_var_name = @var_name + '(' + subs.join(',') + ')'
      interpreter.get_value(evaled_var_name)
    else
      interpreter.get_value(@var_name)
    end
  end
end

class VariableReference < Variable
  def initialize(text)
    super
  end
  
  def evaluate(interpreter)
    self
  end
end

class ArgumentCounter
  def initialize(value)
    @value = value
  end

  def value
    @value
  end

  def is_operator
    false
  end

  def is_function
    false
  end

  def is_variable
    false
  end
  
  def evaluate(interpreter)
    self
  end

  def to_s
    "AC:#{@value}"
  end
end

class Function
  @@valid_names = [ 'INT', 'RND', 'EXP', 'LOG', 'ABS', 'SQR', 'SIN', 'COS' ]
  def initialize(text)
    raise(BASICException, "'#{text}' is not a valid function", caller) if !@@valid_names.include?(text)
    @name = text
  end

  def is_operator
    false
  end
  
  def is_function
    true
  end

  def is_terminal
    false
  end
  
  def is_variable
    false
  end
  
  def precedence
    5
  end
  
  def evaluate(stack)
    result = 0
    num_args = stack.pop
    case @name
    when 'INT'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      result = xv.to_i
    when 'RND'
      if num_args.value == 0 then
        xv = 100
      elsif num_args.value == 1 then
        x = stack.pop
        xv = x.to_v
      else
        raise(BASICException, "Function #{@name} expects 0 or 1 argument, found #{num_args.value}", caller)
      end
      upper_bound = xv.truncate.to_f
      upper_bound = 1 if upper_bound <= 0
      result = $randomizer.rand(upper_bound)
    when 'EXP'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = Math.exp(xv)
      result = float_to_possible_int(f)
    when 'LOG'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.log(xv) : 0
      result = float_to_possible_int(f)
    when 'ABS'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      result = xv >= 0 ? xv : -xv
    when 'SQR'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.sqrt(xv) : 0
      result = float_to_possible_int(f)
    when 'SIN'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.sin(xv) : 0
      result = float_to_possible_int(f)
    when 'COS'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args.value}", caller) if num_args.value != 1
      x = stack.pop
      raise(Exception, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.cos(xv) : 0
      result = float_to_possible_int(f)
    end
    NumericConstant.new(result)
  end

  def to_s
    @name + @right.to_s
  end
  
  def to_formatted_s(interpreter)
    @name + @right.to_formatted_s(interpreter)
  end
end

class Expression
  def initialize(text)
    @uncompiled_expression = text
  end

  protected
  def tokenize(words)
    tokens = Array.new
    last_was_operand = false
    # convert tokens to objects
    words.each do | word |
      # puts "DBG: word=#{word}"
      if word.size > 0 then
        if word == '(' then
          tokens << '('
          last_was_operand = true
        else
          if word == ')'
            tokens << ')'
            last_was_operand = true
          else
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
                  tokens << NumericConstant.new(word)
                  last_was_operand = true
                rescue BASICException
                  begin
                    tokens << VariableValue.new(word)
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
    end
    tokens << TerminalOperator.new
  end

  protected
  def parse(tokens)
    operator_stack = Array.new
    arg_count_stack = Array.new
    arg_count = ArgumentCounter.new(0)
    compiled_expression = Array.new

    last_was_function = false
    # scan the token list from left to right
    tokens.each do | token |
      if token != '' then
        # If the token is a left parenthesis, push it on the operator stack
        if token == '(' then
          operator_stack.push(token)
          last_was_function = false
        else
          raise(BASICException, "Function requires parentheses", caller) if last_was_function
          # If the token is a right parenthesis,
          # pop the operator stack until the corresponding left parenthesis is removed
          # Append each operator to the end of the output list
          if token == ')' then
            while operator_stack.size > 0 and operator_stack[-1] != '(' do
              op = operator_stack.pop
              if op.is_function
                compiled_expression << arg_count
              end
              compiled_expression << op
            end
            operator_stack.pop  # remove the '('
            last_was_function = false
          else
            if token.is_operator or token.is_function or token.is_variable then
              # remove operators already on the stack that have higher or equal precedence
              # append them to the output list
              while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1].precedence >= token.precedence do
                op = operator_stack.pop
                if op.is_function then
                  compiled_expression << arg_count
                  arg_count = arg_count_stack.pop
                end
                compiled_expression << op
              end
              # push the operator onto the operator stack
              if not token.is_terminal then
                operator_stack.push(token)
                if token.is_function then
                  arg_count_stack.push(arg_count)
                  arg_count = ArgumentCounter.new(0)
                end
              end
              if token.is_variable and arg_count.value == 0 then
                arg_count = ArgumentCounter.new(1)
              end
            else
              # the token is an operand, append it to the output list
              if arg_count.value == 0 then
                arg_count = ArgumentCounter.new(1)
              end
              compiled_expression << token
            end
            last_was_function = token.is_function
          end
        end
      end
    end
    compiled_expression
  end
  
  public
  def to_s
    @uncompiled_expression
  end
end

class ValueExpression < Expression
  def initialize(text)
    super
    # split the input infix string
    regex = Regexp.new('([\+\-\*\/\(\)\^])')
    words = text.split(regex)
    # puts "DBG: words=[#{words.join('] [')}]"

    tokens = tokenize(words)
    @compiled_expression = parse(tokens)
  end

  def evaluate(interpreter)
    interpreter.evaluate_r_value(@compiled_expression)
  end
end

class TargetExpression < Expression
  def initialize(text)
    super
    # split the input infix string
    regex = Regexp.new('([\+\-\*\/\(\)\^])')
    words = text.split(regex)
    # puts "DBG: words=[#{words.join('] [')}]"

    tokens = tokenize(words)
    # verify that the first token is a VariableValue
    # convert it to a VariableRef
    @compiled_expression = parse(tokens)
  end

  def evaluate(interpreter)
    interpreter.evaluate_r_value(@compiled_expression)
  end
end

class PrintableExpression
  def initialize(text)
    @arithmetic_expression = nil
    @text_constant = nil
    begin
      @text_constant = TextConstant.new(text)
    rescue BASICException => message
      @arithmetic_expression = ValueExpression.new(text)
    end
  end
  
  def to_s
    if @arithmetic_expression.nil? then
      @text_constant.to_s
    else
      @arithmetic_expression.to_s
    end
  end
  
  def six_digits(value)
    decimals = 5 - (value != 0 ? Math.log(value.abs,10).to_i : 0)
    value.round(decimals)
  end
  
  def to_formatted_s(interpreter)
    if @arithmetic_expression.nil? then
      @text_constant.to_formatted_s(interpreter)
    else
      numeric_constant = @arithmetic_expression.evaluate(interpreter)
      numeric_constant.to_formatted_s(interpreter)
    end
  end
end

class BooleanExpression
  def initialize(text)
    parts = text.split(/\s*([=<>]+)\s*/)
    raise(BASICException, "'#{text}' is not a boolean expression", caller) if parts.size != 3
    @a = ValueExpression.new(parts[0])
    @operator = BooleanOperator.new(parts[1])
    @b = ValueExpression.new(parts[2])
  end
  
  def evaluate(interpreter)
    av = @a.evaluate(interpreter).to_v
    bv = @b.evaluate(interpreter).to_v
    case @operator.to_s
    when '='
        av == bv
    when '<>'
        av != bv
    when '<'
        av < bv
    when '>'
        av > bv
    when '<='
        av <= bv
    when '>='
        av >= bv
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
    @target = TargetExpression.new(parts[0])
    @expression = ValueExpression.new(parts[1])
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

