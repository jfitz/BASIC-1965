# Hold a variable name (not a reference or value)
class VariableName
  def self.init?(text)
    /\A[A-Z]\d?\z/.match(text)
  end

  def initialize(text)
    fail(BASICException, "'#{text}' is not a variable name") unless
      VariableName.init?(text)
    @var_name = text
  end

  def eql?(other)
    @var_name == other.to_s
  end

  def ==(other)
    @var_name == other.to_s
  end

  def hash
    @var_name.hash
  end

  def to_s
    @var_name
  end
end

# Hold a variable (name with possible subscripts and value)
class Variable < AbstractToken
  attr_reader :subscripts

  def initialize(variable_name)
    fail(BASICException, "'#{variable_name}' is not a variable name") if
      variable_name.class.to_s != 'VariableName'
    @variable_name = variable_name
    @subscripts = []
    @variable = true
    @operand = true
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

  def to_s_1(i)
    @variable_name.to_s + '(' + i.to_s + ')'
  end

  def to_s_2(i, j)
    @variable_name.to_s + '(' + i.to_s + ',' + j.to_s + ')'
  end
end

# Scalar value (not a matrix)
class ScalarValue < Variable
  def initialize(variable_name)
    super
  end

  private

  def previous_is_array(stack)
    stack.size > 0 && stack[-1].class.to_s == 'Array'
  end

  def get_subscripts(stack)
    subscripts = stack.pop
    num_args = subscripts.length
    fail(Exception,
         'Variable expects subscripts, found empty parentheses') if
      num_args == 0
    subscripts
  end

  def eval_var_name(name, subscripts)
    name.to_s + '(' + subscripts.join(',') + ')'
  end

  public

  # return a single value
  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      @subscripts = get_subscripts(stack)
      interpreter.check_subscripts(@variable_name, @subscripts)
      evaled_var_name = eval_var_name(@variable_name, @subscripts)
      interpreter.get_value(evaled_var_name)
    else
      interpreter.get_value(@variable_name.to_s)
    end
  end
end

# Scalar reference (not a matrix)
class ScalarReference < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  # return a single value, a reference to this object
  def evaluate(interpreter, stack)
    if stack.size > 0 && stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(Exception,
           'Variable expects subscripts, found empty parentheses') if
        num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

# Dimensions to a variable
class VariableDimension < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  # return a single value, a reference to this object
  def evaluate(_, stack)
    if stack.size > 0 && stack[-1].class.to_s == 'Array'
      @subscripts = stack.pop
      num_args = @subscripts.length
      fail(Exception,
           'Variable expects subscripts, found empty parentheses') if
        num_args == 0
    end
    self
  end
end

# A list (needed because it has precedence value)
class List < AbstractToken
  def initialize(parsed_expressions)
    @parsed_expressions = parsed_expressions
    @variable = true
  end

  def precedence
    5
  end

  def list
    @parsed_expressions
  end

  def evaluate(interpreter, _)
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

# Scalar function (provides a scalar)
class ScalarFunction < AbstractToken
  def initialize(text)
    @name = text
    @function = true
    @operand = true
  end

  def precedence
    5
  end

  private

  def check_1_num_arg(args)
    fail(BASICException, 'No arguments for function') if
      args.class.to_s != 'Array'
    num_args = args.length
    fail(BASICException,
         "Function #{@name} expects 1 argument, found #{num_args}") if
      num_args != 1
    x = args[0]
    fail(BASICException,
         "Argument #{x} #{x.class} not numeric") if
      x.class.to_s != 'NumericConstant'
    x
  end

  def check_0_1_num_args(args)
    fail(BASICException, 'No arguments for function') if
      args.class.to_s != 'Array'
    num_args = args.length
    if num_args == 0
      x = NumericConstant.new(100)
    elsif num_args == 1
      x = args[0]
    else
      fail(BASICException,
           "Function #{@name} expects 0 or 1 argument, found #{num_args}")
    end

    fail(BASICException,
         "Argument #{x} #{x.class} not numeric") if
      x.class.to_s != 'NumericConstant'
    x
  end
end

# function INT
class ScalarFunctionInt < ScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    result = xv.to_i
    NumericConstant.new(result)
  end
end

# function RND
class ScalarFunctionRnd < ScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop
    x = check_0_1_num_args(args)
    xv = x.to_v
    upper_bound = xv.truncate.to_f
    upper_bound = 1.to_f if upper_bound <= 0
    result = interpreter.rand(upper_bound)
    NumericConstant.new(result)
  end
end

# function EXP
class ScalarFunctionExp < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = Math.exp(xv)
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function LOG
class ScalarFunctionLog < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = xv > 0 ? Math.log(xv) : 0
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function ABS
class ScalarFunctionAbs < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    result = xv >= 0 ? xv : -xv
    NumericConstant.new(result)
  end
end

# function SQR
class ScalarFunctionSqr < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = xv > 0 ? Math.sqrt(xv) : 0
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function SIN
class ScalarFunctionSin < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = Math.sin(xv)
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function COS
class ScalarFunctionCos < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = Math.cos(xv)
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function TAN
class ScalarFunctionTan < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = xv >= 0 ? Math.tan(xv) : 0
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function ATN
class ScalarFunctionAtn < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    xv = x.to_v
    f = xv >= 0 ? Math.atan(xv) : 0
    result = float_to_possible_int(f)
    NumericConstant.new(result)
  end
end

# function SGN
class ScalarFunctionSgn < ScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args)
    result = 0
    result = 1 if x > 0
    result = -1 if x < 0
    NumericConstant.new(result)
  end
end

# class to make functions, given the name
class ScalarFunctionFactory
  @@functions = {
    'INT' => ScalarFunctionInt,
    'RND' => ScalarFunctionRnd,
    'EXP' => ScalarFunctionExp,
    'LOG' => ScalarFunctionLog,
    'ABS' => ScalarFunctionAbs,
    'SQR' => ScalarFunctionSqr,
    'SIN' => ScalarFunctionSin,
    'COS' => ScalarFunctionCos,
    'TAN' => ScalarFunctionTan,
    'ATN' => ScalarFunctionAtn,
    'SGN' => ScalarFunctionSgn
  }

  def self.valid?(text)
    @@functions.key?(text) || UserFunction.init?(text)
  end

  def self.make(text)
    func = @@functions[text].new(text) if @@functions.key?(text)
    func = UserFunction.new(text) if UserFunction.init?(text)
    func
  end
end

# User-defined function (provides a scalar value)
class UserFunction < ScalarFunction
  def self.init?(text)
    /\AFN[A-Z]\z/.match(text)
  end

  def initialize(text)
    fail(BASICException, "'#{text}' is not a valid function") unless
      UserFunction.init?(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    expression = interpreter.get_user_function(@name)
    # verify function is defined
    fail(BASICException, "Function #{@name} not defined") if expression.nil?
    user_var_names = interpreter.get_user_var_names(@name)

    # verify arguments
    user_var_values = stack.pop
    fail(BASICException, 'No arguments for function') if
      user_var_values.class.to_s != 'Array'
    num_args = user_var_values.length
    fail(BASICException,
         "Function #{@name} expects #{user_var_names.length} argument, found #{num_args}") if
      num_args != user_var_names.length
    x = user_var_values[0]
    fail(BASICException, "Argument #{x} #{x.class} not numeric") if
      x.class.to_s != 'NumericConstant'

    # dummy variable names and their (now known) values
    names_and_values = Hash[user_var_names.zip(user_var_values)]
    interpreter.set_user_var_values(names_and_values)
    result = expression.evaluate(interpreter)
    interpreter.clear_user_var_values
    result[0]
  end
end

# split a line into arguments
def split_args(text, keep_separators)
  args = []
  current_arg = ''
  in_string = false
  parens_level = 0
  text.each_char do |c|
    if in_string
      if c == '"'
        current_arg += c
        args << current_arg
        current_arg = ''
      else
        current_arg += c
      end
    else
      if [',', ';'].include?(c) && parens_level == 0
        args << current_arg if current_arg.length > 0
        current_arg = ''
        args << c if keep_separators
      elsif c == ' '
        c = c
      elsif c == '('
        current_arg += c
        parens_level += 1
      elsif c == ')'
        current_arg += c
        parens_level -= 1 if parens_level > 0
      else
        current_arg += c
      end
    end
    in_string = !in_string if c == '"'
  end
  args << current_arg if current_arg.size > 0
  args
end

# split the input
# needs changes to allow for negative exponents
def split(text)
  # split the input infix string
  text.split(%r{([\+\-\*\/\(\)\^,])})
end

# converts text line to constant values
def textline_to_constants(line)
  values = []
  text_values = line.split(',')
  text_values.each do |value|
    begin
      values << NumericConstant.new(value)
    rescue BASICException => e
      raise BASICException, "Invalid value #{value}: #{e.message}"
    end
  end
  values
end

# returns an Array of tokens
def tokenize(words)
  tokens = []
  # convert tokens to objects
  words.each do |word|
    next if word.size == 0

    if word == '('
      tokens << GroupStart.new
    elsif word == ')'
      tokens << GroupEnd.new
    elsif word == ','
      tokens << ParamSeparator.new
    elsif tokens.size > 0 && tokens[-1].operand? && BinaryOperator.init?(word)
      tokens << BinaryOperator.new(word)
    elsif !(tokens.size > 0 && tokens[-1].operand?) && UnaryOperator.init?(word)
      tokens << UnaryOperator.new(word)
    elsif ScalarFunctionFactory.valid?(word)
      tokens << ScalarFunctionFactory.make(word)
    elsif NumericConstant.init?(word)
      tokens << NumericConstant.new(word)
    elsif VariableName.init?(word)
      variable_name = VariableName.new(word)
      tokens << ScalarValue.new(variable_name)
    else
      fail BASICException, "'#{word}' is not a value or operator"
    end
  end
  tokens << TerminalOperator.new
end

# returns an Array of parsed expressions
def parse(tokens)
  parsed_expressions = []
  operator_stack = []
  expression_stack = []
  parsed_expression = []
  parens_stack = []

  last_was_function = false
  last_was_variable = false
  parens_group = []
  # scan the token list from left to right
  tokens.each do |token|
    next if token == ''

    # If the token is a left parenthesis, push it on the operator stack
    if token.group_start?
      if last_was_function || last_was_variable
        # start parsing the list of function arguments
        expression_stack.push(parsed_expression)
        parsed_expression = []
        operator_stack.push(ParamStart.new)
      else
        operator_stack.push(token)
      end
      parens_stack << parens_group
      parens_group = []
      last_was_function = false
      last_was_variable = false
    # If the token is a comma,
    # pop the operator stack until the corresponding left parenthesis is found
    # Append each operator to the end of the output list
    elsif token.separator?
      while operator_stack.size > 0 &&
            !operator_stack[-1].starter?
        op = operator_stack.pop
        parsed_expression << op
      end
      parens_group << parsed_expression
      parsed_expression = []
    else
      fail(BASICException, 'Function requires parentheses') if last_was_function
      # If the token is a right parenthesis,
      # pop the operator stack until the corresponding left paren is removed
      # Append each operator to the end of the output list
      if token.group_end?
        while operator_stack.size > 0 &&
              !operator_stack[-1].starter?
          op = operator_stack.pop
          parsed_expression << op
        end
        parens_group << parsed_expression
        start_op = operator_stack.pop  # remove the '(' or '[' starter
        if start_op.param_start?
          list = List.new(parens_group)
          operator_stack.push(list)
          parsed_expression = expression_stack.pop
        end
        parens_group = parens_stack.pop
        last_was_function = false
        last_was_variable = false
      else
        if token.operator? || token.function? || token.variable?
          # remove operators already on the stack that have higher
          # or equal precedence
          # append them to the output list
          while operator_stack.size > 0 &&
                !operator_stack[-1].starter? &&
                operator_stack[-1].precedence >= token.precedence
            op = operator_stack.pop
            parsed_expression << op
          end
          # push the operator onto the operator stack
          operator_stack.push(token) unless token.terminal?
        else
          # the token is an operand, append it to the output list
          parsed_expression << token
        end
        last_was_function = token.function?
        last_was_variable = token.variable?
      end
    end
  end
  parsed_expressions << parsed_expression
  parsed_expressions
end

# returns an Array of values
def eval_scalar(interpreter, parsed_expressions, _)
  # expected = parsed_expressions[0].length
  result_values = []
  parsed_expressions.each do |parsed_expression|
    stack = []
    parsed_expression.each do |token|
      stack.push token.evaluate(interpreter, stack)
    end
    # should be only one item on stack
    # actual = stack.length
    # fail(Exception,
    #      "Expected #{expected} items, "
    #      "#{actual} remaining on evaluation stack") if
    #  actual != expected
    # very each item is of correct type
    item = stack[0]
    # fail(Exception,
    #      "Expected item #{expected_result_class}, "
    #      "found item type #{item.class} remaining on evaluation stack") if
    #  item.class.to_s != expected_result_class
    result_values << item unless item.class.to_s == 'NilClass'
  end
  # actual = result_values.length
  # fail(Exception,
  #      "Expected #{expected} items, "
  #      "#{actual} remaining on evaluation stack") if
  #   actual != expected
  result_values
end

# Value scalar expression (an R-value)
class ValueScalarExpression
  def initialize(text)
    fail(Exception, 'Expression cannot be empty') if text.length == 0
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
      fail(Exception, 'ValueScalarExpression: Expected some values') if
        values.length == 0
    else
      values = []
    end
    values
  end
end

# Value matrix expression (an R-value)
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
    fail BASICException, "Undefined value #{@variable}" if dimensions.nil?

    fail BASICException, "Need dimensions in #{@variable}" if
      dimensions.size == 0
    print_1(dimensions, printer, interpreter, carriage) if
      dimensions.size == 1
    print_2(dimensions, printer, interpreter, carriage) if
      dimensions.size == 2
    fail BASICException, "Too many dimensions in #{@variable}" if
      dimensions.size > 2
  end

  private

  def print_1(dimensions, printer, interpreter, carriage)
    upper = dimensions[0].to_v

    (1..upper).each do |index|
      varname = @variable.to_s_1(index)
      value = interpreter.get_value(varname)
      printer.print_item(value.to_s)
      printer.last_was_numeric
      carriage.print(printer, interpreter)
    end
    printer.newline
    printer.newline
  end

  def print_2(dimensions, printer, interpreter, carriage)
    upper_i = dimensions[0].to_v
    upper_j = dimensions[1].to_v

    (1..upper_i).each do |i|
      (1..upper_j).each do |j|
        varname = @variable.to_s_2(i, j)
        value = interpreter.get_value(varname)
        printer.print_item(value.to_s)
        printer.last_was_numeric
        carriage.print(printer, interpreter)
      end
      printer.newline
    end
    printer.newline
  end
end

# Abstract target expression
class AbstractTargetExpression
  def initialize(text)
    fail(Exception, 'Expression cannot be empty') if text.length == 0
    @unparsed_expression = text

    words = split(text)
    tokens = tokenize(words)
    @parsed_expressions = parse(tokens)
    check_length
    check_all_lengths
    check_resolve_types
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  private

  def check_length
    fail(BASICException, 'Value list is empty (length 0)') if
      @parsed_expressions.length == 0
  end

  def check_all_lengths
    @parsed_expressions.each do |parsed_expression|
      fail(BASICException, 'Value is not assignable (length 0)') if
        parsed_expression.length == 0
    end
  end

  def check_resolve_types
    @parsed_expressions.each do |parsed_expression|
      fail(BASICException,
           "Value is not assignable (type #{parsed_expression[-1].class})") if
        parsed_expression[-1].class.to_s != 'ScalarValue'
    end
  end
end

# target scalar expression (an L-value)
class TargetScalarExpression < AbstractTargetExpression
  def initialize(text)
    super
    @parsed_expressions.each do |parsed_expression|
      parsed_expression[-1] = ScalarReference.new(parsed_expression[-1])
    end
  end

  # returns an Array of targets
  def evaluate(interpreter)
    values = eval_scalar(interpreter, @parsed_expressions, 'ScalarReference')
    fail(Exception, 'Expected some values') if values.length == 0
    values
  end
end

# A dimension expression (evaluates to dimensions)
class DimensionExpression < AbstractTargetExpression
  def initialize(text)
    super
    @parsed_expressions.each do |parsed_expression|
      parsed_expression[-1] = VariableDimension.new(parsed_expression[-1])
    end
  end

  def evaluate(interpreter)
    values = eval_scalar(interpreter, @parsed_expressions, 'VariableDimension')
    fail(Exception, 'Expected some values') if values.length == 0
    values
  end
end

# User function definition
# Define the user function name, arguments, and expression
class UserFunctionDefinition
  attr_reader :name
  attr_reader :arguments
  attr_reader :template

  def initialize(text)
    # parse into name '=' expression
    parts = text.split('=', 2)
    fail(BASICException, "'#{text}' is not a valid assignment") if
      parts.size != 2
    user_function_prototype = UserFunctionPrototype.new(parts[0])
    @name = user_function_prototype.name
    @arguments = user_function_prototype.arguments
    @template = ValueScalarExpression.new(parts[1])
  end
end

# User function prototype
# Define the user function name and arguments
class UserFunctionPrototype
  attr_reader :name
  attr_reader :arguments

  def initialize(text)
    fail(BASICException, "Invalid function specification #{text}") unless
      /\AFN[A-Z]\([A-Z]\)\z/.match(text)
    @name = text[0..2]
    arg0 = text[4..4]
    @arguments = [arg0]
  end

  def to_s
    @name
  end
end

# Printable expression (part of a PRINT statement)
class PrintableExpression
  def initialize(text)
    @arithmetic_expression = nil
    @text_constant = nil
    begin
      @text_constant = TextConstant.new(text)
    rescue BASICException
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

  def print(printer, interpreter, carriage)
    if @arithmetic_expression.nil?
      printer.print_item @text_constant.to_formatted_s(interpreter)
    else
      numeric_constants = @arithmetic_expression.evaluate(interpreter)
      numeric_constant = numeric_constants[0]
      printer.print_item numeric_constant.to_formatted_s(interpreter)
      printer.last_was_numeric
    end
    carriage.print(printer, interpreter)
  end
end

# Boolean expression
class BooleanExpression
  def initialize(text)
    parts = text.split(/([=<>]+)/)
    fail(BASICException, "'#{text}' is not a boolean expression") if
      parts.size != 3
    @a = ValueScalarExpression.new(parts[0])
    @operator = make_boolean_operator(parts[1])
    @b = ValueScalarExpression.new(parts[2])
  end

  def evaluate(interpreter)
    avs = @a.evaluate(interpreter)
    av = avs[0].to_v
    bvs = @b.evaluate(interpreter)
    bv = bvs[0].to_v
    @operator.evaluate(av, bv)
  end

  def to_s
    @a.to_s + ' ' + @operator.to_s + ' ' + @b.to_s
  end
end

# An assignment (part of a LET statement)
class Assignment
  def initialize(text)
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    fail(BASICException, "'#{text}' is not a valid assignment") if
      parts.size != 2
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
