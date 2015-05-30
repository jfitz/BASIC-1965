class VariableName
  def initialize(text)
    regex = Regexp.new('^[A-Z]\d?$')
    raise(BASICException, "'#{text}' is not a variable name", caller) if not regex.match(text)
    @var_name = text
  end

  def eql?(rhs)
    @var_name == rhs.to_s
  end

  def ==(rhs)
    @var_name == rhs.to_s
  end

  def hash
    @var_name.hash
  end

  def to_s
    @var_name
  end
end

class Variable
  def initialize(variable_name)
    raise(BASICException, "'#{variable_name}' is not a variable name", caller) if variable_name.class.to_s != 'VariableName'
    @variable_name = variable_name
    @subscripts = Array.new
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
  
  def name
    @variable_name
  end

  def to_s
    if subscripts.length > 0 then
      @variable_name.to_s + '(' + @subscripts.join(',') + ')'
    else
      @variable_name.to_s
    end
  end

  def subscripts
    @subscripts
  end
end

class VariableValue < Variable
  def initialize(variable_name)
    super
  end
  
  def evaluate(interpreter, stack)
    ## puts "VariableValue::evaluate() #{to_s}"
    if stack.size > 0 and stack[-1].class.to_s == 'Array' then
      @subscripts = stack.pop
      num_args = @subscripts.length
      raise(Exception, "Variable expects subscripts, found empty parentheses", caller) if num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
      evaled_var_name = @variable_name.to_s + '(' + @subscripts.join(',') + ')'
      interpreter.get_value(evaled_var_name)
    else
      interpreter.get_value(@variable_name.to_s)
    end
  end
end

class VariableReference < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end
  
  def evaluate(interpreter, stack)
    ## puts "VariableReference::evaluate() #{to_s}"
    if stack.size > 0 and stack[-1].class.to_s == 'Array' then
      @subscripts = stack.pop
      num_args = @subscripts.length
      raise(Exception, "Variable expects subscripts, found empty parentheses", caller) if num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

class VariableDimension < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end
  
  def evaluate(interpreter, stack)
    ## puts "VariableReference::evaluate() #{to_s}"
    if stack.size > 0 and stack[-1].class.to_s == 'Array' then
      @subscripts = stack.pop
      num_args = @subscripts.length
      raise(Exception, "Variable expects subscripts, found empty parentheses", caller) if num_args == 0
    end
    self
  end
end

class List
  def initialize(parsed_expressions)
    @parsed_expressions = parsed_expressions
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

  def list
    @parsed_expressions
  end
  
  def evaluate(interpreter, stack)
    eval(interpreter, @parsed_expressions, 'NumericConstant')
  end

  def to_s
    "[#{@parsed_expressions.join('] [')}]"
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
  
  def evaluate(interpreter, stack)
    ## puts "Function::evaluate() #{to_s}"
    result = 0
    args = stack.pop
    ## puts "args: #{args.class} #{args}"
    raise(BASICException, "No arguments for function", caller) if args.class.to_s != 'Array'
    num_args = args.length
    case @name
    when 'INT'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      result = xv.to_i
    when 'RND'
      if num_args.value == 0 then
        xv = 100
      elsif num_args.value == 1 then
        x = args[0]
        xv = x.to_v
      else
        raise(BASICException, "Function #{@name} expects 0 or 1 argument, found #{num_args}", caller)
      end
      upper_bound = xv.truncate.to_f
      upper_bound = 1 if upper_bound <= 0
      result = $randomizer.rand(upper_bound)
    when 'EXP'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = Math.exp(xv)
      result = float_to_possible_int(f)
    when 'LOG'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.log(xv) : 0
      result = float_to_possible_int(f)
    when 'ABS'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      result = xv >= 0 ? xv : -xv
    when 'SQR'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.sqrt(xv) : 0
      result = float_to_possible_int(f)
    when 'SIN'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv >= 0 ? Math.sin(xv) : 0
      result = float_to_possible_int(f)
    when 'COS'
      raise(BASICException, "Function #{@name} expects 1 argument, found #{num_args}", caller) if num_args != 1
      x = args[0]
      raise(BASICException, "Argument #{x} #{x.class} not numeric", caller) if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv >= 0 ? Math.cos(xv) : 0
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

def split_args(text, keep_separators)
  args = Array.new
  current_arg = String.new
  in_string = false
  parens_level = 0
  text.split('').each do | c |
    if [',', ';'].include?(c) and not in_string and parens_level == 0 then
      args << current_arg if current_arg.length > 0
      current_arg = String.new
      args << c if keep_separators
    elsif c == '"' and in_string then
      current_arg += c
      args << current_arg
      current_arg = String.new
    elsif c == ' ' and not in_string then
      c = c
    elsif c == '(' and not in_string then
      current_arg += c
      parens_level += 1
    elsif c == ')' and not in_string then
      current_arg += c
      parens_level -= 1 if parens_level > 0
    else
      current_arg += c
    end
    in_string = !in_string if c == '"'
  end
  args << current_arg if current_arg.size > 0
  args
end

def split(text)
  # split the input infix string
  regex = Regexp.new('([\+\-\*\/\(\)\^,])')
  text.split(regex)
end

def textline_to_constants(line)
  values = Array.new
  text_values = line.split(/,/)
  text_values.each do | value |
    begin
      values << NumericConstant.new(value)
    rescue BASICException
      raise BASICException, "Invalid value #{value}", caller
    end
  end
  values
end

def tokenize(words)
  tokens = Array.new
  last_was_operand = false
  # convert tokens to objects
  words.each do | word |
    ## puts "word: #{word}"
    if word.size > 0 then
      if word == '(' then
        tokens << '('
        last_was_operand = true
      else
        if word == ')' then
          tokens << ')'
          last_was_operand = true
        elsif word == ',' then
          tokens << ','
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
                  variable_name = VariableName.new(word)
                  tokens << VariableValue.new(variable_name)
                  last_was_operand = true
                rescue BASICException
                  raise BASICException, "'#{word}' is not a value or operator", caller
                end
              end
            end
          end
        end
      end
    end
    ## puts "  tokens: [#{tokens.join('] [')}]"
  end
  tokens << TerminalOperator.new
end

def parse(tokens)
  parsed_expressions = Array.new
  operator_stack = Array.new
  expression_stack = Array.new
  parsed_expression = Array.new
  parens_stack = Array.new

  ## puts "tokens: [#{tokens.join('] [')}]"
  last_was_function = false
  last_was_variable = false
  parens_group = Array.new
  ## puts " PG new: [#{parens_group.join('] [')}]"
  # scan the token list from left to right
  tokens.each do | token |
    if token != '' then
      ## puts "token: #{token.class} #{token}"
      ## puts "PG: [#{parens_group.join('] [')}]"
      # If the token is a left parenthesis, push it on the operator stack
      if token == '(' then
        ## puts " PG (: [#{parens_group.join('] [')}]"
        if last_was_function or last_was_variable then
          # start parsing the list of function arguments
          expression_stack.push(parsed_expression)
          parsed_expression = Array.new
          operator_stack.push('[')
        else
          operator_stack.push(token)
        end
        ## puts " PG pre-<<: [#{parens_group.join('] [')}]"
        parens_stack << parens_group
        parens_group = Array.new
        last_was_function = false
        last_was_variable = false
      # If the token is a comma,
      # pop the operator stack until the corresponding left parenthesis is found
      # Append each operator to the end of the output list
      elsif token == ',' then
        while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1] != '[' do
          op = operator_stack.pop
          parsed_expression << op
          ## puts "  PE ): [#{parsed_expression.join('] [')}]"
        end
        parens_group << parsed_expression
        ## puts " PG ,: [#{parens_group.join('] [')}]"
        parsed_expression = Array.new
      else
        raise(BASICException, "Function requires parentheses", caller) if last_was_function
        # If the token is a right parenthesis,
        # pop the operator stack until the corresponding left parenthesis is removed
        # Append each operator to the end of the output list
        if token == ')' then
          ## puts " PG ) 1: [#{parens_group.join('] [')}]"
          while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1] != '[' do
            op = operator_stack.pop
            parsed_expression << op
            ## puts "  PE ): [#{parsed_expression.join('] [')}]"
          end
          parens_group << parsed_expression
          start_op = operator_stack.pop  # remove the '(' or '['
          ## puts " PG ) 2: [#{parens_group.join('] [')}]"
          if start_op == '[' then
            ## puts "  PE [: [#{parsed_expression.join('] [')}]"
            list = List.new(parens_group)
            operator_stack.push(list)
            ## puts "  OS [: [#{operator_stack.join('] [')}]"
            parsed_expression = expression_stack.pop
            ## puts "  PE [: [#{parsed_expression.join('] [')}]"
          end
          parens_group = parens_stack.pop
          ## puts " PG pop: [#{parens_group.join('] [')}]"
          last_was_function = false
          last_was_variable = false
        else
          if token.is_operator or token.is_function or token.is_variable then
            # remove operators already on the stack that have higher or equal precedence
            # append them to the output list
            while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1] != '[' and operator_stack[-1].precedence >= token.precedence do
              op = operator_stack.pop
              parsed_expression << op
              ## puts "  PE stack: [#{parsed_expression.join('] [')}]"
            end
            # push the operator onto the operator stack
            if not token.is_terminal then
              operator_stack.push(token)
            end
          else
            # the token is an operand, append it to the output list
            parsed_expression << token
            ## puts "  PE operand: [#{parsed_expression.join('] [')}]"
          end
          last_was_function = token.is_function
          last_was_variable = token.is_variable
        end
      end
    end
    ## puts "  OS end: [#{operator_stack.join('] [')}]"
    ## puts "  CE end: [#{parsed_expressions.join('] [')}]"
  end
  ## puts "OS fin: [#{operator_stack.join('] [')}]"
  parsed_expressions << parsed_expression
  ## puts "CE fin: [#{parsed_expressions.join('] [')}]"
  parsed_expressions
end

def eval(interpreter, parsed_expressions, expected_result_class)
  expected = parsed_expressions.length
  result_values = Array.new
  parsed_expressions.each do | parsed_expression |
    ## puts "eval CE: [#{parsed_expression.join('] [')}]"
    stack = Array.new
    parsed_expression.each do | token |
      ## puts "parse::token: #{token.class} #{token}"
      case token.class.to_s
      when 'List'
        x = token.evaluate(interpreter, stack)
      when 'UnaryOperator','BinaryOperator','Function'
        x = token.evaluate(interpreter, stack)
      when 'NumericConstant'
        x = token.evaluate(interpreter, stack)
      when 'VariableValue','VariableReference','VariableDimension'
        x = token.evaluate(interpreter, stack)
      else
        raise Exception, "Unknown data type #{x.class}", caller
      end
      ## puts "parse::value: #{x}"
      stack.push(x)
      ## puts "stack: [#{stack.join('] [')}]"
    end
    # should be only one item on stack
    actual = stack.length
    raise(Exception, "Expected #{expected} items, #{actual} remaining on evaluation stack", caller) if actual != 1
    # very each item is of correct type
    item = stack[0]
    raise(Exception, "Expected item #{expected_result_class}, found item type #{item.class} remaining on evaluation stack", caller) if item.class.to_s != expected_result_class
    result_values << item
  end
  actual = result_values.length
  raise(Exception, "Expected #{expected} items, #{actual} remaining on evaluation stack", caller) if actual != expected
  result_values
end

class ValueExpression
  def initialize(text)
    raise(Exception, "Expression cannot be empty", caller) if text.length == 0
    @unparsed_expression = text

    words = split(text)
    ## puts "DBG: words=[#{words.join('] [')}]"
    tokens = tokenize(words)
    ## puts "DBG: tokens=[#{tokens.join('] [')}]"
    @parsed_expressions = parse(tokens)
    ## puts "ValueExpression::init CE=[#{@parsed_expressions.join('] [')}]"
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  def evaluate(interpreter)
    ## puts "ValueExpression::evaluate() #{to_s}"
    ## puts "ValueExpression:: [#{@parsed_expressions.join('] [')}]"
    values = eval(interpreter, @parsed_expressions, 'NumericConstant')
    raise(Exception, "ValueExpression: Expected some values", caller) if values.length == 0
    ## puts "ValueExpression::values: [#{values.join('] [')}]"
    values
  end
end

class TargetExpression
  def initialize(text)
    raise(Exception, "Expression cannot be empty", caller) if text.length == 0
    @unparsed_expression = text

    words = split(text)
    ## puts "DBG: words=[#{words.join('] [')}]"
    tokens = tokenize(words)
    ## puts "DBG: tokens=[#{tokens.join('] [')}]"
    @parsed_expressions = parse(tokens)
    ## puts "TargetExpression::init CE=[#{@parsed_expressions.join('] [')}]"
    raise(BASICException, "Value list is empty (length 0)", caller) if @parsed_expressions.length == 0
    @parsed_expressions.each do | parsed_expression |
      ## puts "expression: #{parsed_expression} #{parsed_expression.class}"
      raise(BASICException, "Value is not assignable (length 0)", caller) if parsed_expression.length == 0
      raise(BASICException, "Value is not assignable (type #{parsed_expression[-1].class})", caller) if parsed_expression[-1].class.to_s != 'VariableValue'
      parsed_expression[-1] = VariableReference.new(parsed_expression[-1])
    end
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  def evaluate(interpreter)
    ## puts "TargetExpression::evaluate() #{to_s}"
    ## puts "TargetExpression:: [#{@parsed_expressions.join('] [')}]"
    values = eval(interpreter, @parsed_expressions, 'VariableReference')
    raise(Exception, "Expected some values", caller) if values.length == 0
    values
  end
end

class DimensionExpression
  def initialize(text)
    raise(Exception, "Expression cannot be empty", caller) if text.length == 0
    @unparsed_expression = text

    words = split(text)
    ## puts "DimensionExpression: words=[#{words.join('] [')}]"
    tokens = tokenize(words)
    ## puts "DimensionExpression: tokens=[#{tokens.join('] [')}]"
    @parsed_expressions = parse(tokens)
    ## puts "DimensionExpression CE=[#{@parsed_expressions.join('] [')}]"
    raise(BASICException, "Value list is empty (length 0)", caller) if @parsed_expressions.length == 0
    @parsed_expressions.each do | parsed_expression |
      ## puts "expression: #{parsed_expression} #{parsed_expression.class}"
      raise(BASICException, "Value is not assignable (length 0)", caller) if parsed_expression.length == 0
      raise(BASICException, "Value is not assignable (type #{parsed_expression[-1].class})", caller) if parsed_expression[-1].class.to_s != 'VariableValue'
      parsed_expression[-1] = VariableDimension.new(parsed_expression[-1])
    end
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  def evaluate(interpreter)
    ## puts "DimensionExpression::evaluate() #{to_s}"
    ## puts "DimensionExpression:: [#{@parsed_expressions.join('] [')}]"
    values = eval(interpreter, @parsed_expressions, 'VariableDimension')
    raise(Exception, "Expected some values", caller) if values.length == 0
    values
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
      numeric_constants = @arithmetic_expression.evaluate(interpreter)
      numeric_constant = numeric_constants[0]
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
    avs = @a.evaluate(interpreter)
    av = avs[0].to_v
    bvs = @b.evaluate(interpreter)
    bv = bvs[0].to_v
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

  def count_target
    @target.count
  end

  def eval_target(interpreter)
    @target.evaluate(interpreter)
  end

  def count_value
    @expression.count
  end
  
  def eval_value(interpreter)
    @expression.evaluate(interpreter)
  end
  
  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end

  def to_postfix_s
    @expression.to_postfix_s
  end
end

