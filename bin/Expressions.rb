class VariableName
  def initialize(text)
    regex = Regexp.new('^[A-Z]\d?$')
    fail(BASICException, "'#{text}' is not a variable name") unless regex.match(text)
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
    fail(BASICException, "'#{variable_name}' is not a variable name") if variable_name.class.to_s != 'VariableName'
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
    if subscripts.length > 0
      @variable_name.to_s + '(' + @subscripts.join(',') + ')'
    else
      @variable_name.to_s
    end
  end

  def subscripts
    @subscripts
  end
end

class ScalarValue < Variable
  def initialize(variable_name)
    super
  end
  
  # return a single value
  def evaluate(interpreter, stack)
    if stack.size > 0 and stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(Exception, "Variable expects subscripts, found empty parentheses") if num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
      evaled_var_name = @variable_name.to_s + '(' + @subscripts.join(',') + ')'
      interpreter.get_value(evaled_var_name)
    else
      interpreter.get_value(@variable_name.to_s)
    end
  end
end

class ScalarReference < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end
  
  # return a single value, a reference to this object
  def evaluate(interpreter, stack)
    if stack.size > 0 and stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(Exception, "Variable expects subscripts, found empty parentheses") if num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

class VariableDimension < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end
  
  # return a single value, a reference to this object
  def evaluate(interpreter, stack)
    if stack.size > 0 and stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(Exception, "Variable expects subscripts, found empty parentheses") if num_args == 0
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
    if @parsed_expressions[0].size > 0
      eval_scalar(interpreter, @parsed_expressions, 'NumericConstant')
    else
      eval_scalar(interpreter, @parsed_expressions, 'NilClass')
    end
  end

  def to_s
    "[#{@parsed_expressions.join('] [')}]"
  end
end

class ScalarFunction
  @@valid_names = [ 'INT', 'RND', 'EXP', 'LOG', 'ABS', 'SQR', 'SIN', 'COS', 'TAN', 'ATN', 'SGN' ]
  def initialize(text)
    fail(BASICException, "'#{text}' is not a valid function") unless @@valid_names.include?(text)
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
  
  # return a single value
  def evaluate(interpreter, stack)
    result = 0
    args = stack.pop
    fail(BASICException, "No arguments for function") if args.class.to_s != 'Array'
    num_args = args.length
    case @name
    when 'INT'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      result = xv.to_i
    when 'RND'
      if num_args == 0
        xv = 100
      elsif num_args == 1
        x = args[0]
        xv = x.to_v
      else
        fail(BASICException, "Function #{@name} expects 0 or 1 argument, found #{num_args}")
      end
      upper_bound = xv.truncate.to_f
      upper_bound = 1.to_f if upper_bound <= 0
      result = $randomizer.rand(upper_bound)
    when 'EXP'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = Math.exp(xv)
      result = float_to_possible_int(f)
    when 'LOG'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.log(xv) : 0
      result = float_to_possible_int(f)
    when 'ABS'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      result = xv >= 0 ? xv : -xv
    when 'SQR'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv > 0 ? Math.sqrt(xv) : 0
      result = float_to_possible_int(f)
    when 'SIN'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = Math.sin(xv)
      result = float_to_possible_int(f)
    when 'COS'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = Math.cos(xv)
      result = float_to_possible_int(f)
    when 'TAN'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv >= 0 ? Math.tan(xv) : 0
      result = float_to_possible_int(f)
    when 'ATN'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      xv = x.to_v
      f = xv >= 0 ? Math.atan(xv) : 0
      result = float_to_possible_int(f)
    when 'SGN'
      fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != 1
      x = args[0]
      fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'
      result = 0
      result = 1 if x > 0
      result = -1 if x < 0
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

class UserFunction
  def initialize(text)
    regex = Regexp.new('\AFN[A-Z]\z')
    fail(BASICException, "'#{text}' is not a valid function") unless regex.match(text)
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
  
  # return a single value
  def evaluate(interpreter, stack)
    expression = interpreter.get_user_function(@name)
    # verify function is defined
    fail(BASICException, "Function #{@name} not defined") if expression == nil
    user_var_names = interpreter.get_user_var_names(@name)

    # verify arguments
    user_var_values = stack.pop
    fail(BASICException, "No arguments for function") if user_var_values.class.to_s != 'Array'
    num_args = user_var_values.length
    fail(BASICException, "Function #{@name} expects 1 argument, found #{num_args}") if num_args != user_var_names.length
    x = user_var_values[0]
    fail(BASICException, "Argument #{x} #{x.class} not numeric") if x.class.to_s != 'NumericConstant'

    # dummy variable names and their (now known) values
    names_and_values = Hash[user_var_names.zip(user_var_values)]
    interpreter.set_user_var_values(names_and_values)
    result = expression.evaluate(interpreter)
    interpreter.clear_user_var_values
    result[0]
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
    if [',', ';'].include?(c) and not in_string and parens_level == 0
      args << current_arg if current_arg.length > 0
      current_arg = String.new
      args << c if keep_separators
    elsif c == '"' and in_string
      current_arg += c
      args << current_arg
      current_arg = String.new
    elsif c == ' ' and not in_string
      c = c
    elsif c == '(' and not in_string
      current_arg += c
      parens_level += 1
    elsif c == ')' and not in_string
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
    rescue BASICException => e
      fail BASICException, "Invalid value #{value}: #{e.message}"
    end
  end
  values
end

# returns an Array of tokens
def tokenize(words)
  tokens = Array.new
  last_was_operand = false
  # convert tokens to objects
  words.each do | word |
    if word.size > 0
      if word == '('
        tokens << '('
        last_was_operand = true
      else
        if word == ')'
          tokens << ')'
          last_was_operand = true
        elsif word == ','
          tokens << ','
          last_was_operand = true
        else
          begin
            if last_was_operand
              tokens << BinaryOperator.new(word)
            else
              tokens << UnaryOperator.new(word)
            end
            last_was_operand = false
          rescue BASICException
            begin
              tokens << ScalarFunction.new(word)
              last_was_operand = true
            rescue BASICException
              begin
                tokens << UserFunction.new(word)
                rescue BASICException
                  begin
                    tokens << NumericConstant.new(word)
                    last_was_operand = true
                    rescue BASICException
                      begin
                        variable_name = VariableName.new(word)
                        tokens << ScalarValue.new(variable_name)
                        last_was_operand = true
                      rescue BASICException
                        fail BASICException, "'#{word}' is not a value or operator"
                      end
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

# returns an Array of parsed expressions
def parse(tokens)
  parsed_expressions = Array.new
  operator_stack = Array.new
  expression_stack = Array.new
  parsed_expression = Array.new
  parens_stack = Array.new

  last_was_function = false
  last_was_variable = false
  parens_group = Array.new
  # scan the token list from left to right
  tokens.each do | token |
    if token != ''
      # If the token is a left parenthesis, push it on the operator stack
      if token == '('
        if last_was_function or last_was_variable
          # start parsing the list of function arguments
          expression_stack.push(parsed_expression)
          parsed_expression = Array.new
          operator_stack.push('[')
        else
          operator_stack.push(token)
        end
        parens_stack << parens_group
        parens_group = Array.new
        last_was_function = false
        last_was_variable = false
      # If the token is a comma,
      # pop the operator stack until the corresponding left parenthesis is found
      # Append each operator to the end of the output list
      elsif token == ','
        while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1] != '[' do
          op = operator_stack.pop
          parsed_expression << op
        end
        parens_group << parsed_expression
        parsed_expression = Array.new
      else
        fail(BASICException, "Function requires parentheses") if last_was_function
        # If the token is a right parenthesis,
        # pop the operator stack until the corresponding left parenthesis is removed
        # Append each operator to the end of the output list
        if token == ')'
          while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1] != '[' do
            op = operator_stack.pop
            parsed_expression << op
          end
          parens_group << parsed_expression
          start_op = operator_stack.pop  # remove the '(' or '['
          if start_op == '['
            list = List.new(parens_group)
            operator_stack.push(list)
            parsed_expression = expression_stack.pop
          end
          parens_group = parens_stack.pop
          last_was_function = false
          last_was_variable = false
        else
          if token.is_operator or token.is_function or token.is_variable
            # remove operators already on the stack that have higher or equal precedence
            # append them to the output list
            while operator_stack.size > 0 and operator_stack[-1] != '(' and operator_stack[-1] != '[' and operator_stack[-1].precedence >= token.precedence do
              op = operator_stack.pop
              parsed_expression << op
            end
            # push the operator onto the operator stack
            if not token.is_terminal
              operator_stack.push(token)
            end
          else
            # the token is an operand, append it to the output list
            parsed_expression << token
          end
          last_was_function = token.is_function
          last_was_variable = token.is_variable
        end
      end
    end
  end
  parsed_expressions << parsed_expression
  parsed_expressions
end

# returns an Array of values
def eval_scalar(interpreter, parsed_expressions, expected_result_class)
  # expected = parsed_expressions[0].length
  result_values = Array.new
  parsed_expressions.each do | parsed_expression |
    stack = Array.new
    parsed_expression.each do | token |
      case token.class.to_s
      when 'List'
        x = token.evaluate(interpreter, stack)
      when 'UnaryOperator','BinaryOperator','ScalarFunction','UserFunction'
        x = token.evaluate(interpreter, stack)
      when 'NumericConstant'
        x = token.evaluate(interpreter, stack)
      when 'ScalarValue','ScalarReference','VariableDimension'
        x = token.evaluate(interpreter, stack)
      else
        fail Exception, "Unknown data type #{x.class}"
      end
      stack.push(x)
    end
    # should be only one item on stack
    # actual = stack.length
    # fail(Exception, "Expected #{expected} items, #{actual} remaining on evaluation stack") if actual != expected
    # very each item is of correct type
    item = stack[0]
    # fail(Exception, "Expected item #{expected_result_class}, found item type #{item.class} remaining on evaluation stack") if item.class.to_s != expected_result_class
    result_values << item unless item.class.to_s == 'NilClass'
  end
  actual = result_values.length
  # fail(Exception, "Expected #{expected} items, #{actual} remaining on evaluation stack") if actual != expected
  result_values
end

class ValueScalarExpression
  def initialize(text)
    fail(Exception, "Expression cannot be empty") if text.length == 0
    @unparsed_expression = text

    words = split(text)
    tokens = tokenize(words)
    @parsed_expressions = parse(tokens)
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  # returns an Array of values
  def evaluate(interpreter)
    if @parsed_expressions.size > 0
      values = eval_scalar(interpreter, @parsed_expressions, 'NumericConstant')
      fail(Exception, "ValueScalarExpression: Expected some values") if values.length == 0
    else
      values = Array.new
    end
    values
  end
end

class ValueMatrixExpression
  def initialize(text)
    variable_name = VariableName.new(text)
    @variable = Variable.new(variable_name)
  end

  def to_s
    @variable.to_s
  end

  def print(printer, interpreter, carriage)
    dimensions = interpreter.get_dimensions(@variable.name)
    if not dimensions.nil?
      if dimensions.size == 1
        upper = dimensions[0].to_v
        (1..upper).each do | index |
          varname = @variable.to_s + '(' + index.to_s + ')'
          value = interpreter.get_value(varname)
          printer.print_item(value.to_s)
          printer.last_was_numeric
          carriage.print(printer, interpreter)
        end
        printer.newline
        printer.newline
      end
      if dimensions.size == 2
        upper_i = dimensions[0].to_v
        upper_j = dimensions[1].to_v
        (1..upper_i).each do | i |
          (1..upper_j).each do | j |
            varname = @variable.to_s + '(' + i.to_s + ',' + j.to_s + ')'
            value = interpreter.get_value(varname)
            printer.print_item(value.to_s)
            printer.last_was_numeric
            carriage.print(printer, interpreter)
          end
          printer.newline
        end
        printer.newline
      end
    else
      fail BASICException, "Undefined value #{@variable}"
    end
  end
end

class TargetScalarExpression
  def initialize(text)
    fail(Exception, "Expression cannot be empty") if text.length == 0
    @unparsed_expression = text

    words = split(text)
    tokens = tokenize(words)
    @parsed_expressions = parse(tokens)
    fail(BASICException, "Value list is empty (length 0)") if @parsed_expressions.length == 0
    @parsed_expressions.each do | parsed_expression |
      fail(BASICException, "Value is not assignable (length 0)") if parsed_expression.length == 0
      fail(BASICException, "Value is not assignable (type #{parsed_expression[-1].class})") if parsed_expression[-1].class.to_s != 'ScalarValue'
      parsed_expression[-1] = ScalarReference.new(parsed_expression[-1])
    end
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  # returns an Array of targets
  def evaluate(interpreter)
    values = eval_scalar(interpreter, @parsed_expressions, 'ScalarReference')
    fail(Exception, "Expected some values") if values.length == 0
    values
  end
end

class DimensionExpression
  def initialize(text)
    fail(Exception, "Expression cannot be empty") if text.length == 0
    @unparsed_expression = text

    words = split(text)
    tokens = tokenize(words)
    @parsed_expressions = parse(tokens)
    fail(BASICException, "Value list is empty (length 0)") if @parsed_expressions.length == 0
    @parsed_expressions.each do | parsed_expression |
      fail(BASICException, "Value is not assignable (length 0)") if parsed_expression.length == 0
      fail(BASICException, "Value is not assignable (type #{parsed_expression[-1].class})") if parsed_expression[-1].class.to_s != 'ScalarValue'
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
    values = eval_scalar(interpreter, @parsed_expressions, 'VariableDimension')
    fail(Exception, "Expected some values") if values.length == 0
    values
  end
end

class UserFunctionPrototype
  def initialize(text)
    regex = Regexp.new('\AFN[A-Z]\([A-Z]\)\z')
    fail(BASICException, "Invalid function specification #{text}") unless regex.match(text)
    @name = text[0..2]
    arg0 = text[4..4]
    @arguments = Array.new
    @arguments << arg0
  end

  def name
    @name
  end

  def arguments
    @arguments
  end

  def to_s
    @name
  end
end

class PrintableExpression
  def initialize(text)
    @arithmetic_expression = nil
    @text_constant = nil
    begin
      @text_constant = TextConstant.new(text)
    rescue BASICException => message
      @arithmetic_expression = ValueScalarExpression.new(text)
    end
  end
  
  def to_s
    if @arithmetic_expression.nil?
      @text_constant.to_s
    else
      @arithmetic_expression.to_s
    end
  end
  
  def print(printer, interpreter)
    if @arithmetic_expression.nil?
      printer.print_item @text_constant.to_formatted_s(interpreter)
    else
      numeric_constants = @arithmetic_expression.evaluate(interpreter)
      numeric_constant = numeric_constants[0]
      printer.print_item numeric_constant.to_formatted_s(interpreter)
      printer.last_was_numeric
    end
  end
end

class CarriageControl
  @@valid_operators = [ 'NL', ',', ';' ]
  def initialize(text)
    fail(BASICException, "'#{text}' is not a valid separator") unless @@valid_operators.include?(text)
    @operator = text
  end

  def to_s
    case @operator
    when ';'
      ';'
    when ','
      ','
    when 'NL'
      ''
    end
  end

  def print(printer, interpreter)
    case @operator
    when ','
      printer.tab
    when ';'
      printer.semicolon
    when 'NL'
      printer.newline
    end
  end
end

class BooleanExpression
  def initialize(text)
    parts = text.split(/\s*([=<>]+)\s*/)
    fail(BASICException, "'#{text}' is not a boolean expression") if parts.size != 3
    @a = ValueScalarExpression.new(parts[0])
    @operator = BooleanOperator.new(parts[1])
    @b = ValueScalarExpression.new(parts[2])
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
    fail(BASICException, "'#{text}' is not a valid assignment") if parts.size != 2
    @target = TargetScalarExpression.new(parts[0])
    @expression = ValueScalarExpression.new(parts[1])
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

class UserFunctionDefinition
  def initialize(text)
    # parse into name '=' expression
    parts = text.split('=', 2)
    fail(BASICException, "'#{text}' is not a valid assignment") if parts.size != 2
    user_function_prototype = UserFunctionPrototype.new(parts[0])
    @name = user_function_prototype.name
    @arguments = user_function_prototype.arguments
    @template = ValueScalarExpression.new(parts[1])
  end

  def name
    @name
  end

  def arguments
    @arguments
  end

  def template
    @template
  end
end

