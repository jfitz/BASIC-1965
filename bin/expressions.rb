# Hold a variable name (not a reference or value)
class VariableName < AbstractToken
  def self.init?(text)
    /\A[A-Z]\d?\z/.match(text)
  end

  attr_reader :precedence

  def initialize(text)
    fail(BASICException, "'#{text}' is not a variable name") unless
      VariableName.init?(text)
    @var_name = text
    @variable = true
    @operand = true
    @precedence = 6
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
  attr_reader :precedence

  def initialize(variable_name)
    fail(BASICException, "'#{variable_name}' is not a variable name") if
      variable_name.class.to_s != 'VariableName'
    @variable_name = variable_name
    @subscripts = []
    @variable = true
    @operand = true
    @precedence = 6
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

# Matrix with values
class Matrix
  def initialize(dimensions, values)
    @dimensions = dimensions
    @values = values
  end

  def matrix?
    true
  end

  def dimensions
    @dimensions
  end

  def get_value_1(col)
    coords = '(' + col.to_s + ')'
    return @values[coords] if @values.key?(coords)
    0
  end

  def get_value_2(row, col)
    coords = '(' + row.to_s + ',' + col.to_s + ')'
    return @values[coords] if @values.key?(coords)
    0
  end

  def to_s
    'MATRIX: ' + @values.to_s
  end
end

# Matrix value
class MatrixValue < Variable
  def initialize(variable_name)
    super
  end

  def evaluate(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)
    fail(BASICException, 'Variable has no dimensions') if dims.nil?
    values = {}
    if dims.size == 1
      n_cols = dims[0].to_i
      (1..n_cols).each do |col|
        coords = '(' + col.to_s + ')'
        var_name = @variable_name.to_s + coords
        values[coords] = interpreter.get_value(var_name)
      end
    end
    if dims.size == 2
      n_rows = dims[0].to_i
      n_cols = dims[1].to_i
      (1..n_rows).each do |row|
        (1..n_cols).each do |col|
          coords = '(' + row.to_s + ',' + col.to_s + ')'
          var_name = @variable_name.to_s + coords
          values[coords] = interpreter.get_value(var_name)
        end
      end
    end
    Matrix.new(dims, values)
  end
end

# Matrix reference
class MatrixReference < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  def dimensions?
    @subscripts.size > 0
  end

  def dimensions
    @subscripts
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

  attr_reader :precedence

  def initialize(parsed_expressions)
    @parsed_expressions = parsed_expressions
    @variable = true
    @precedence = 6
  end

  def list
    @parsed_expressions
  end

  def evaluate(interpreter, _)
    if @parsed_expressions[0].size > 0
      eval_scalar(interpreter, @parsed_expressions)
    else
      eval_scalar(interpreter, @parsed_expressions)
    end
  end

  def to_s
    "[#{@parsed_expressions.join('] [')}]"
  end
end

# Scalar function (provides a scalar)
class Function < AbstractToken

  attr_reader :precedence

  def initialize(text)
    @name = text
    @function = true
    @operand = true
    @precedence = 6
  end

  private

  def check_args(args)
    fail(BASICException, 'No arguments for function') if
      args.class.to_s != 'Array'
  end

  def check_value(value, type)
    fail(BASICException,
         "Argument #{x} #{x.class} not numeric") if
      value.class.to_s != type
  end

  def check_1_num_arg(args, type)
    check_args(args)
    num_args = args.length
    fail(BASICException,
         "Function #{@name} expects 1 argument, found #{num_args}") if
      num_args != 1
    x = args[0]
    check_value(x, type)
    x
  end

  def check_0_1_num_args(args, type)
    check_args(args)
    num_args = args.length
    if num_args == 0
      x = NumericConstant.new(100)
    elsif num_args == 1
      x = args[0]
    else
      fail(BASICException,
           "Function #{@name} expects 0 or 1 argument, found #{num_args}")
    end

    check_value(x, type)
    x
  end

  def check_1_2_num_args(args, type)
    check_args(args)
    num_args = args.length
    if num_args == 1
      x = args[0]
      check_value(x, type)
    elsif num_args == 2
      x = args[0]
      check_value(x, type)
      x = args[1]
      check_value(x, type)
    else
      fail(BASICException,
           "Function #{@name} expects 1 or 2 arguments, found #{num_args}")
    end
  end
end

class AbstractScalarFunction < Function
  def initialize(text)
    super
  end

  def default_type
    ScalarValue
  end
end

class AbstractMatrixFunction < Function
  def initialize(text)
    super
  end

  def default_type
    MatrixValue
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    result = xv.to_i
    NumericConstant.new(result)
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop
    x = check_0_1_num_args(args, 'NumericConstant')
    xv = x.to_v
    upper_bound = xv.truncate.to_f
    upper_bound = 1.to_f if upper_bound <= 0
    result = interpreter.rand(upper_bound)
    NumericConstant.new(result)
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = Math.exp(xv)
    NumericConstant.new(f)
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = xv > 0 ? Math.log(xv) : 0
    NumericConstant.new(f)
  end
end

# function ABS
class FunctionAbs < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    result = xv >= 0 ? xv : -xv
    NumericConstant.new(result)
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = xv > 0 ? Math.sqrt(xv) : 0
    NumericConstant.new(f)
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = Math.sin(xv)
    NumericConstant.new(f)
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = Math.cos(xv)
    NumericConstant.new(f)
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = xv >= 0 ? Math.tan(xv) : 0
    NumericConstant.new(f)
  end
end

# function ATN
class FunctionAtn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    xv = x.to_v
    f = xv >= 0 ? Math.atan(xv) : 0
    NumericConstant.new(f)
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'NumericConstant')
    result = 0
    result = 1 if x > 0
    result = -1 if x < 0
    NumericConstant.new(result)
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    x = check_1_num_arg(args, 'Matrix')
    dims = x.dimensions
    fail(BASICException, 'TRN requires matrix') if dims.size != 2
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    new_dims = [dims[1], dims[0]]
    new_values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = x.get_value_2(row, col)
        coords = '(' + col.to_s + ',' + row.to_s + ')'
        new_values[coords] = value
      end
    end
    Matrix.new(new_dims, new_values)
  end
end

# function IDN
class FunctionIdn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    check_1_2_num_args(args, 'NumericConstant')
    fail(BASICException, 'TRN requires matrix') if
      args.size == 2 && args[1] != args[0]
    n_rows = args[0].to_i
    n_cols = args[0].to_i
    new_dims = [args[0], args[0]]
    new_values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        if col == row
          value = NumericConstant.new(1)
        else
          value = NumericConstant.new(0)
        end
        coords = '(' + col.to_s + ',' + row.to_s + ')'
        new_values[coords] = value
      end
    end
    Matrix.new(new_dims, new_values)
  end
end

# class to make functions, given the name
class FunctionFactory
  @@functions = {
    'INT' => FunctionInt,
    'RND' => FunctionRnd,
    'EXP' => FunctionExp,
    'LOG' => FunctionLog,
    'ABS' => FunctionAbs,
    'SQR' => FunctionSqr,
    'SIN' => FunctionSin,
    'COS' => FunctionCos,
    'TAN' => FunctionTan,
    'ATN' => FunctionAtn,
    'SGN' => FunctionSgn,
    'TRN' => FunctionTrn,
    'IDN' => FunctionIdn
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
class UserFunction < AbstractScalarFunction
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
      current_arg += c
      if c == '"'
        args << current_arg
        current_arg = ''
      end
    else
      if [',', ';'].include?(c) && parens_level == 0
        args << current_arg if current_arg.length > 0
        current_arg = ''
        args << c if keep_separators
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
def split_input(text)
  # split the input infix string
  parts = text.split(%r{([\+\-\*\/\(\)\^,])})
  # remove empty elements
  short_parts = parts.reject(&:empty?)
  # we have split a value like '12E+3' into three parts (12E + 3)
  # put them back into a single item
  regrouped_parts = []
  while short_parts.size > 0
    first_three = short_parts[0..2].join('')
    if short_parts.size >= 3 && NumericConstant.init?(first_three)
      regrouped_parts << first_three
      short_parts = short_parts[3..-1]
    else
      regrouped_parts << short_parts[0]
      short_parts = short_parts[1..-1]
    end
  end
  regrouped_parts
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

# returns an Array of values
def eval_scalar(interpreter, parsed_expressions)
  # expected = parsed_expressions[0].length
  result_values = []
  parsed_expressions.each do |parsed_expression|
    stack = []
    parsed_expression.each do |token|
      value = token.evaluate(interpreter, stack)
      stack.push value
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
    result_values << item unless item.nil?
  end
  # actual = result_values.length
  # fail(Exception,
  #      "Expected #{expected} items, "
  #      "#{actual} remaining on evaluation stack") if
  #   actual != expected
  result_values
end

# base class for expressions
class AbstractExpression
  def initialize(text, default_type)
    fail(Exception, 'Expression cannot be empty') if text.length == 0
    @unparsed_expression = text

    words = split_input(text)
    tokens = tokenize(words)
    @parsed_expressions = parse(tokens, default_type)
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  private

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
      elsif tokens.size > 0 && tokens[-1].operand? &&
            BinaryOperator.init?(word)
        tokens << BinaryOperator.new(word)
      elsif !(tokens.size > 0 && tokens[-1].operand?) &&
            UnaryOperator.init?(word)
        tokens << UnaryOperator.new(word)
      elsif FunctionFactory.valid?(word)
        tokens << FunctionFactory.make(word)
      elsif NumericConstant.init?(word)
        tokens << NumericConstant.new(word)
      elsif VariableName.init?(word)
        tokens << VariableName.new(word)
      else
        fail BASICException, "'#{word}' is not a value or operator"
      end
    end
    tokens << TerminalOperator.new
  end

  def stack_to_expression(stack, expression)
    while !stack[-1].starter?
      op = stack.pop
      expression << op
      fail(BASICException, 'Expression error') if stack.size == 0
    end
  end

  def stack_to_precedence(stack, expression, token)
    while stack.size > 0 &&
          !stack[-1].starter? &&
          stack[-1].precedence >= token.precedence
      op = stack.pop
      expression << op
    end
  end

  # returns an Array of parsed expressions
  def parse(tokens, default_type)
    parsed_expressions = []
    operator_stack = []
    expression_stack = []
    parsed_expression = []
    parens_stack = []
    type_stack = [default_type]

    parens_group = []
    previous_token = InitialOperator.new
    # scan the token list from left to right
    tokens.each do |token|
      fail(BASICException, 'Function requires parentheses') if
        !token.group_start? && previous_token.function?
      if token.group_start? && previous_token.function?
        # start parsing the list of function arguments
        expression_stack.push(parsed_expression)
        parsed_expression = []
        operator_stack.push(ParamStart.new)
        parens_stack << parens_group
        parens_group = []
        type_stack.push(previous_token.default_type)
      elsif token.group_start? && previous_token.variable?
        # start parsing the list of subscripts
        expression_stack.push(parsed_expression)
        parsed_expression = []
        operator_stack.push(ParamStart.new)
        parens_stack << parens_group
        parens_group = []
        type_stack.push(ScalarValue)
      elsif token.group_start?
        # neither arguments or subscripts; just a grouping parens
        operator_stack.push(token)
        parens_stack << parens_group
        parens_group = []
        type_stack.push(ScalarValue)
      elsif token.separator?
        # pop the operator stack until the corresponding left paren is found
        # Append each operator to the end of the output list
        stack_to_expression(operator_stack, parsed_expression)
        parens_group << parsed_expression
        parsed_expression = []
      elsif token.group_end?
        # pop the operator stack until the corresponding left paren is removed
        # Append each operator to the end of the output list
        stack_to_expression(operator_stack, parsed_expression)
        parens_group << parsed_expression
        start_op = operator_stack.pop  # remove the '(' or '[' starter
        if start_op.param_start?
          list = List.new(parens_group)
          operator_stack.push(list)
          parsed_expression = expression_stack.pop
        end
        parens_group = parens_stack.pop
        type_stack.pop
      elsif token.operator?
        # remove operators already on the stack that have higher
        # or equal precedence
        # append them to the output list
        stack_to_precedence(operator_stack, parsed_expression, token)
        # push the operator onto the operator stack
        operator_stack.push(token) unless token.terminal?
      elsif token.function?
        # remove operators already on the stack that have higher
        # or equal precedence
        # append them to the output list
        stack_to_precedence(operator_stack, parsed_expression, token)
        # push the operator onto the operator stack
        operator_stack.push(token)
      elsif token.variable?
        # remove operators already on the stack that have higher
        # or equal precedence
        # append them to the output list
        stack_to_precedence(operator_stack, parsed_expression, token)
        # push the operator onto the operator stack
        variable_name = type_stack[-1].new(token)
        operator_stack.push(variable_name)
      else
        # the token is an operand, append it to the output list
        parsed_expression << token
      end
      previous_token = token
    end
    fail(BASICException, 'Expression error') if operator_stack.size > 0
    parsed_expressions << parsed_expression
    parsed_expressions
  end
end

# Value scalar expression (an R-value)
class ValueScalarExpression < AbstractExpression
  def initialize(text)
    super(text, ScalarValue)
  end

  # returns an Array of values
  def evaluate(interpreter)
    if @parsed_expressions.size > 0
      values = eval_scalar(interpreter, @parsed_expressions)
      fail(Exception, 'ValueScalarExpression: Expected some values') if
        values.length == 0
    else
      values = []
    end
    values
  end
end

# Value matrix expression (an R-value)
class ValueMatrixExpression < AbstractExpression
  def initialize(text)
    super(text, MatrixValue)
  end

  def empty?
    false
  end

  def printable?
    true
  end

  # returns an Array of Matrix objects
  def evaluate(interpreter)
    if @parsed_expressions.size > 0
      values = eval_scalar(interpreter, @parsed_expressions)
      fail(Exception, 'ValueMatrixExpression: Expected some values') if
        values.length == 0
    else
      values = []
    end
    values
  end
end

# Abstract target expression
class AbstractTargetExpression < AbstractExpression
  def initialize(text)
    super(text, ScalarValue)

    check_length
    check_all_lengths
    check_resolve_types
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
    values = eval_scalar(interpreter, @parsed_expressions)
    fail(Exception, 'Expected some values') if values.length == 0
    values
  end
end

# target matrix expression (an L-value)
class TargetMatrixExpression < AbstractTargetExpression
  def initialize(text)
    super
    @parsed_expressions.each do |parsed_expression|
      parsed_expression[-1] = MatrixReference.new(parsed_expression[-1])
    end
  end

  # returns an Array of targets
  def evaluate(interpreter)
    values = eval_scalar(interpreter, @parsed_expressions)
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
    values = eval_scalar(interpreter, @parsed_expressions)
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
class AbstractPrintableExpression
  def printable?
    true
  end
end

# Printable expression for scalar
class ScalarPrintableExpression < AbstractPrintableExpression
  def initialize(text)
    @scalar_expression = nil
    @text_constant = nil
    return false if text.nil?
    if TextConstant.init?(text)
      @text_constant = TextConstant.new(text)
    else
      @scalar_expression = ValueScalarExpression.new(text)
    end
  end

  def empty?
    @text_constant.nil? && @scalar_expression.nil?
  end

  def to_s
    r = ''
    r = @text_constant.to_s unless @text_constant.nil?
    r = @scalar_expression.to_s unless @scalar_expression.nil?
    r
  end

  def print(printer, interpreter, carriage)
    unless @text_constant.nil?
      printer.print_item @text_constant.to_formatted_s
      carriage.print(printer, interpreter)
    end
    unless @scalar_expression.nil?
      numeric_constants = @scalar_expression.evaluate(interpreter)
      numeric_constant = numeric_constants[0]
      printer.print_item numeric_constant.to_formatted_s
      printer.last_was_numeric
      carriage.print(printer, interpreter)
    end
    # for a nil expression, print nothing but do print the carriage operation
    carriage.print(printer, interpreter) if empty?
  end
end

# Printable expression for matrix
class MatrixPrintableExpression < AbstractPrintableExpression
  def initialize(text)
    @matrix_expression = nil
    return false if text.nil?
    @matrix_expression = ValueMatrixExpression.new(text)
  end

  def empty?
    @matrix_expression.nil?
  end

  def to_s
    @matrix_expression.to_s
  end

  def print(printer, interpreter, carriage)
    numeric_constants = @matrix_expression.evaluate(interpreter)
    matrix = numeric_constants[0]
    print_matrix(matrix, printer, interpreter, carriage)
    # for a nil expression, print nothing but do print the carriage operation
    carriage.print(printer, interpreter) if empty?
  end

  private

  def print_matrix(matrix, printer, interpreter, carriage)
    dimensions = matrix.dimensions
    fail BASICException, "Undefined matrix" if dimensions.nil?

    case dimensions.size
    when 0
      fail BASICException, "Need dimensions in matrix"
    when 1
      print_1(matrix, dimensions, printer, interpreter, carriage)
    when 2
      print_2(matrix, dimensions, printer, interpreter, carriage)
    else
      fail BASICException, "Too many dimensions in matrix"
    end
  end

  def print_1(matrix, dimensions, printer, interpreter, carriage)
    upper = dimensions[0].to_v

    (1..upper).each do |index|
      value = matrix.get_value_1(index)
      printer.print_item(value.to_formatted_s)
      printer.last_was_numeric
      carriage.print(printer, interpreter)
      printer.last_was_numeric
    end
    printer.newline
    printer.newline
  end

  def print_2(matrix, dimensions, printer, interpreter, carriage)
    upper_i = dimensions[0].to_v
    upper_j = dimensions[1].to_v

    (1..upper_i).each do |i|
      (1..upper_j).each do |j|
        value = matrix.get_value_2(i, j)
        printer.print_item(value.to_formatted_s)
        printer.last_was_numeric
        carriage.print(printer, interpreter)
        printer.last_was_numeric
      end
      printer.newline
    end
    printer.newline
  end
end

# Boolean expression
class BooleanExpression
  def initialize(text)
    parts = text.split(/([=<>]+)/)
    fail(BASICException, "'#{text}' is not a boolean expression") if
      parts.size != 3
    @operators = make_operators

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

  private

  def make_operators
    {
      '=' => BooleanOperatorEq,
      '<>' => BooleanOperatorNotEq,
      '>' => BooleanOperatorGreater,
      '>=' => BooleanOperatorGreaterEq,
      '<' => BooleanOperatorLess,
      '<=' => BooleanOperatorLessEq
    }
  end

  def make_boolean_operator(text)
    fail(BASICException, "'#{text}' is not an operator") unless
      @operators.key?(text)

    @operators[text].new
  end
end

# An assignment (part of a LET statement)
class ScalarAssignment
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

# An assignment (part of a MAT LET statement)
class MatrixAssignment
  def initialize(text)
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    fail(BASICException, "'#{text}' is not a valid assignment") if
      parts.size != 2
    @target = TargetMatrixExpression.new(parts[0])
    @expression = ValueMatrixExpression.new(parts[1])
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
