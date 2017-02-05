# Scalar value (not a matrix)
class ScalarValue < Variable
  def initialize(variable_name)
    super
  end

  private

  def get_subscripts(stack)
    subscripts = stack.pop
    raise(Exception,
          'Variable expects subscripts, found empty parentheses') if
      subscripts.empty?
    subscripts
  end

  public

  # return a single value
  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      @subscripts = get_subscripts(stack)
      interpreter.check_subscripts(@variable_name, @subscripts)
      interpreter.get_value(self)
    else
      interpreter.get_value(@variable_name)
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
    if previous_is_array(stack)
      @subscripts = stack.pop
      num_args = @subscripts.length
      raise(BASICException,
            'Variable expects subscripts, found empty parentheses') if
        num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

# Array with values
class BASICArray
  attr_reader :dimensions

  def initialize(dimensions, values)
    @dimensions = dimensions
    @values = values
  end

  def clone
    Array.new(@dimensions.clone, @values.clone)
  end

  def array?
    true
  end

  def matrix?
    false
  end

  def values
    values = {}
    (0..@dimensions[0].to_i).each do |col|
      value = get_value(col)
      coords = make_coord(col)
      values[coords] = value
    end
    values
  end

  def get_value(col)
    coords = make_coord(col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def to_s
    'ARRAY: ' + @values.to_s
  end

  def print(printer, interpreter, carriage)
    case @dimensions.size
    when 0
      raise BASICException, 'Need dimension in array'
    when 1
      print_1(printer, interpreter, carriage)
    else
      raise BASICException, 'Too many dimensions in array'
    end
  end

  private

  def make_coord(c)
    [NumericConstant.new(c)]
  end

  def print_1(printer, interpreter, carriage)
    n_cols = @dimensions[0].to_i

    (0..n_cols).each do |col|
      value = get_value(col)
      value.print(printer)
      carriage.print(printer, interpreter)
    end
    printer.newline
  end
end

# Matrix with values
class Matrix
  attr_reader :dimensions

  def initialize(dimensions, values)
    @dimensions = dimensions
    @values = values
  end

  def clone
    Matrix.new(@dimensions.clone, @values.clone)
  end

  def array?
    false
  end

  def matrix?
    true
  end

  def values_1
    values = {}
    (1..@dimensions[0].to_i).each do |col|
      value = get_value_1(col)
      coords = make_coord(col)
      values[coords] = value
    end
    values
  end

  def values_2
    values = {}
    (1..@dimensions[0].to_i).each do |row|
      (1..@dimensions[1].to_i).each do |col|
        value = get_value_2(row, col)
        coords = make_coords(row, col)
        values[coords] = value
      end
    end
    values
  end

  def get_value_1(col)
    coords = make_coord(col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def get_value_2(row, col)
    coords = make_coords(row, col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def to_s
    'MATRIX: ' + @values.to_s
  end

  def print(printer, interpreter, carriage)
    case @dimensions.size
    when 0
      raise BASICException, 'Need dimensions in matrix'
    when 1
      print_1(printer, interpreter, carriage)
    when 2
      print_2(printer, interpreter, carriage)
    else
      raise BASICException, 'Too many dimensions in matrix'
    end
  end

  def transpose_values
    raise(BASICException, 'TRN requires matrix') unless @dimensions.size == 2
    new_values = {}
    (1..@dimensions[0].to_i).each do |row|
      (1..@dimensions[1].to_i).each do |col|
        value = get_value_2(row, col)
        coords = make_coords(col, row)
        new_values[coords] = value
      end
    end
    new_values
  end

  def determinant
    raise(BASICException, 'DET requires matrix') unless @dimensions.size == 2
    raise(BASICException, 'DET requires square matrix') if
      @dimensions[1] != @dimensions[0]
    case @dimensions[0].to_i
    when 1
      get_value_2(1, 1)
    when 2
      determinant_2
    else
      determinant_n
    end
  end

  def inverse_values
    # set all values
    values = values_2

    # create identity matrix
    i_matrix = Matrix.new(@dimensions, {})
    inv_values = i_matrix.identity_values

    n_rows = @dimensions[0].to_i
    n_cols = @dimensions[1].to_i

    # convert to upper triangular form
    upper_triangle(n_cols, n_rows, values, inv_values)
    # convert to lower triangular form
    lower_triangle(n_cols, values, inv_values)
    # normalize to ones
    unitize(n_cols, n_rows, values, inv_values)

    inv_values
  end

  def zero_values
    case @dimensions.size
    when 1
      make_array(@dimensions, NumericConstant.new(0))
    when 2
      make_matrix(@dimensions, NumericConstant.new(0))
    end
  end

  def one_values
    case @dimensions.size
    when 1
      make_array(@dimensions, NumericConstant.new(1))
    when 2
      make_matrix(@dimensions, NumericConstant.new(1))
    end
  end

  def identity_values
    new_values = make_matrix(@dimensions, NumericConstant.new(0))
    one = NumericConstant.new(1)
    (1..@dimensions[0].to_i).each do |row|
      coords = make_coords(row, row)
      new_values[coords] = one
    end
    new_values
  end

  private

  def make_coord(c)
    [NumericConstant.new(c)]
  end

  def make_coords(r, c)
    [NumericConstant.new(r), NumericConstant.new(c)]
  end

  def make_array(dims, init_value)
    values = {}
    (1..dims[0].to_i).each do |col|
      coords = make_coord(col)
      values[coords] = init_value
    end
    values
  end

  def make_matrix(dims, init_value)
    values = {}
    (1..dims[0].to_i).each do |row|
      (1..dims[1].to_i).each do |col|
        coords = make_coords(row, col)
        values[coords] = init_value
      end
    end
    values
  end

  def print_1(printer, interpreter, carriage)
    n_cols = @dimensions[0].to_i

    (1..n_cols).each do |col|
      value = get_value_1(col)
      value.print(printer)
      carriage.print(printer, interpreter)
    end
    printer.newline
    printer.newline
  end

  def print_2(printer, interpreter, carriage)
    n_rows = @dimensions[0].to_i
    n_cols = @dimensions[1].to_i

    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = get_value_2(row, col)
        value.print(printer)
        carriage.print(printer, interpreter)
      end
      printer.newline
    end
    printer.newline
  end

  def determinant_2
    a = get_value_2(1, 1)
    b = get_value_2(1, 2)
    c = get_value_2(2, 1)
    d = get_value_2(2, 2)
    a.multiply(d) - b.multiply(c)
  end

  def determinant_n
    minus_one = NumericConstant.new(-1)
    sign = NumericConstant.new(1)
    det = NumericConstant.new(0)
    # for each element in first row
    (1..@dimensions[1].to_i).each do |col|
      v = get_value_2(1, col)
      # create submatrix
      subm = submatrix(1, col)
      d = v.multiply(subm.determinant).multiply(sign)
      det += d
      sign = sign.multiply(minus_one)
    end
    det
  end

  def submatrix(exclude_row, exclude_col)
    one = NumericConstant.new(1)
    new_dims = [@dimensions[0] - one, @dimensions[1] - one]
    new_values = submatrix_values(exclude_row, exclude_col)
    Matrix.new(new_dims, new_values)
  end

  def submatrix_values(exclude_row, exclude_col)
    new_values = {}
    new_row = 1
    (1..@dimensions[0].to_i).each do |row|
      new_col = 1
      next if row == exclude_row
      (1..@dimensions[1].to_i).each do |col|
        next if col == exclude_col
        new_values[make_coords(new_row, new_col)] = get_value_2(row, col)
        new_col += 1
      end
      new_row += 1
    end
    new_values
  end

  def calc_factor(values, row, col)
    denom_coords = make_coords(col, col)
    denominator = values[denom_coords]
    numer_coords = make_coords(row, col)
    numerator = values[numer_coords]
    numerator.divide(denominator)
  end

  def adjust_matrix_entry(values, row, col, wcol, factor)
    value_coords = make_coords(row, wcol)
    minuend_coords = make_coords(col, wcol)
    subtrahend = values[value_coords]
    minuend = values[minuend_coords]
    new_value = subtrahend - minuend.multiply(factor)
    values[value_coords] = new_value
  end

  def upper_triangle(n_cols, n_rows, values, inv_values)
    (1..n_cols - 1).each do |col|
      (col + 1..n_rows).each do |row|
        # adjust values for this row
        factor = calc_factor(values, row, col)
        (1..n_cols).each do |wcol|
          adjust_matrix_entry(values, row, col, wcol, factor)
          adjust_matrix_entry(inv_values, row, col, wcol, factor)
        end
      end
    end
  end

  def lower_triangle(n_cols, values, inv_values)
    n_cols.downto(2) do |col|
      (col - 1).downto(1).each do |row|
        # adjust values for this row
        factor = calc_factor(values, row, col)
        (1..n_cols).each do |wcol|
          adjust_matrix_entry(values, row, col, wcol, factor)
          adjust_matrix_entry(inv_values, row, col, wcol, factor)
        end
      end
    end
  end

  def unitize(n_cols, n_rows, values, inv_values)
    (1..n_rows).each do |row|
      denom_coords = make_coords(row, row)
      denominator = values[denom_coords]
      (1..n_cols).each do |col|
        unitize_matrix_entry(values, row, col, denominator)
        unitize_matrix_entry(inv_values, row, col, denominator)
      end
    end
  end

  def unitize_matrix_entry(values, row, col, denominator)
    coords = make_coords(row, col)
    numerator = values[coords]
    new_value = numerator.divide(denominator)
    values[coords] = new_value
  end
end

# Array value
class ArrayValue < Variable
  def initialize(variable_name)
    super
  end

  def evaluate(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)
    raise(BASICException, 'Variable has no dimensions') if dims.nil?
    raise(BASICException, 'Array requires one dimension') if dims.size != 1
    values = evaluate_1(interpreter, dims[0].to_i)
    BASICArray.new(dims, values)
  end

  private

  def evaluate_1(interpreter, n_cols)
    values = {}
    (0..n_cols).each do |col|
      coords = make_coord(col)
      variable = Variable.new(@variable_name, coords)
      values[coords] = interpreter.get_value(variable)
    end
    values
  end
end

# Compound variable (array or matrix) reference
class CompoundReference < Variable
  def initialize(name)
    super
  end

  def dimensions?
    !@subscripts.empty?
  end

  def dimensions
    @subscripts
  end

  # return a single value, a reference to this object
  def evaluate(interpreter, stack)
    if previous_is_array(stack)
      @subscripts = stack.pop
      num_args = @subscripts.length
      raise(BASICException,
            'Variable expects subscripts, found empty parentheses') if
        num_args == 0
      interpreter.check_subscripts(@variable_name, @subscripts)
    end
    self
  end
end

# Array reference
class ArrayReference < CompoundReference
  def initialize(variable_value)
    super(variable_value.name)
  end
end

# Matrix value
class MatrixValue < Variable
  def initialize(variable_name)
    super
  end

  def evaluate(interpreter, _)
    dims = interpreter.get_dimensions(@variable_name)
    raise(BASICException, 'Variable has no dimensions') if dims.nil?
    values = evaluate_n(interpreter, dims)
    Matrix.new(dims, values)
  end

  private

  def evaluate_n(interpreter, dims)
    values = {}
    values = evaluate_1(interpreter, dims[0].to_i) if dims.size == 1
    values = evaluate_2(interpreter, dims[0].to_i, dims[1].to_i) if
      dims.size == 2
    values
  end

  def evaluate_1(interpreter, n_cols)
    values = {}
    (1..n_cols).each do |col|
      coords = make_coord(col)
      variable = Variable.new(@variable_name, coords)
      values[coords] = interpreter.get_value(variable)
    end
    values
  end

  def evaluate_2(interpreter, n_rows, n_cols)
    values = {}
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        coords = make_coords(row, col)
        variable = Variable.new(@variable_name, coords)
        values[coords] = interpreter.get_value(variable)
      end
    end
    values
  end
end

# Matrix reference
class MatrixReference < CompoundReference
  def initialize(variable_value)
    super(variable_value.name)
  end
end

# Dimensions to a variable
class VariableDimension < Variable
  def initialize(variable_value)
    super(variable_value.name)
  end

  # return a single value, a reference to this object
  def evaluate(_, stack)
    if previous_is_array(stack)
      @subscripts = stack.pop
      num_args = @subscripts.length
      raise(BASICException,
            'Variable expects subscripts, found empty parentheses') if
        num_args == 0
    end
    self
  end
end

# User-defined function (provides a scalar value)
class UserFunction < AbstractScalarFunction
  def self.accept?(token)
    classes = %w(UserFunctionToken)
    classes.include?(token.class.to_s)
  end

  def self.init?(text)
    /\AFN[A-Z]\z/.match(text)
  end

  def initialize(text)
    text = text.to_s if text.class.to_s == 'UserFunctionToken'
    raise(BASICException, "'#{text}' is not a valid function") unless
      UserFunction.init?(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    expression = interpreter.get_user_function(@name)
    # verify function is defined
    raise(BASICException, "Function #{@name} not defined") if expression.nil?

    # verify arguments
    user_var_values = stack.pop
    raise(BASICException, 'No arguments for function') if
      user_var_values.class.to_s != 'Array'
    check_arg_types(user_var_values,
                    ['NumericConstant'] * user_var_values.length)

    # dummy variable names and their (now known) values
    result = expression.evaluate_with_vars(interpreter, @name, user_var_values)
    result[0]
  end
end

# Expression parser
class Parser
  def initialize(default_type)
    @parsed_expressions = []
    @operator_stack = []
    @expression_stack = []
    @current_expression = []
    @parens_stack = []
    @type_stack = [default_type]
    @parens_group = []
    @previous_element = InitialOperator.new
  end

  def parse(element)
    if element.group_separator?
      group_separator(element)
    elsif element.operator?
      operator_higher(element)
    elsif element.function_variable?
      function_variable(element)
    else
      # the element is an operand, append it to the output list
      @current_expression << element
    end

    @previous_element = element
  end

  def expressions
    raise(BASICException, 'Expression error') unless @operator_stack.empty?
    @parsed_expressions.concat @parens_group unless @parens_group.empty?
    @parsed_expressions << @current_expression unless @current_expression.empty?
    @parsed_expressions
  end

  private

  def stack_to_expression(stack, expression)
    until stack.empty? || stack[-1].starter?
      op = stack.pop
      expression << op
    end
  end

  def stack_to_precedence(stack, expression, element)
    while !stack.empty? &&
          !stack[-1].starter? &&
          stack[-1].precedence >= element.precedence
      op = stack.pop
      expression << op
    end
  end

  def group_separator(element)
    if element.group_start?
      start_group(element)
    elsif element.separator?
      pop_to_group_start
    elsif element.group_end?
      end_group(element)
    end
  end

  def start_group(element)
    if @previous_element.function?
      start_associated_group(element, @previous_element.default_type)
    elsif @previous_element.variable?
      start_associated_group(element, ScalarValue)
    else
      start_simple_group(element)
    end
  end

  # a group associated with a function or variable
  # (arguments or subscripts)
  def start_associated_group(element, type)
    @expression_stack.push(@current_expression)
    @current_expression = []
    @operator_stack.push(ParamStart.new(element))
    @parens_stack << @parens_group
    @parens_group = []
    @type_stack.push(type)
  end

  def start_simple_group(element)
    @operator_stack.push(element)
    @parens_stack << @parens_group
    @parens_group = []
    @type_stack.push(ScalarValue)
  end

  # pop the operator stack until the corresponding left paren is found
  # Append each operator to the end of the output list
  def pop_to_group_start
    stack_to_expression(@operator_stack, @current_expression)
    @parens_group << @current_expression
    @current_expression = []
  end

  # pop the operator stack until the corresponding left paren is removed
  # Append each operator to the end of the output list
  def end_group(group_end_element)
    stack_to_expression(@operator_stack, @current_expression)
    @parens_group << @current_expression
    raise(BASICException, 'Expression error') if @operator_stack.empty?
    # remove the '(' or '[' starter
    start_op = @operator_stack.pop
    error = 'Bracket/parenthesis mismatch, found ' + group_end_element.to_s +
            ' to match ' + start_op.to_s
    raise(BASICException, error) unless group_end_element.compatible?(start_op)
    if start_op.param_start?
      list = List.new(@parens_group)
      @operator_stack.push(list)
      @current_expression = @expression_stack.pop
    end
    @parens_group = @parens_stack.pop
    @type_stack.pop
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def operator_higher(element)
    stack_to_precedence(@operator_stack, @current_expression, element)
    # push the operator onto the operator stack
    @operator_stack.push(element) unless element.terminal?
  end

  def function_variable(element)
    if element.function?
      start_function(element)
    elsif element.variable?
      start_variable(element)
    end
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_function(element)
    stack_to_precedence(@operator_stack, @current_expression, element)
    # push the function onto the operator stack
    @operator_stack.push(element)
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_variable(element)
    stack_to_precedence(@operator_stack, @current_expression, element)
    # push the variable onto the operator stack
    variable_name = @type_stack[-1].new(element)
    @operator_stack.push(variable_name)
  end
end

# base class for expressions
class AbstractExpression
  def initialize(tokens, default_type)
    @unparsed_expression = tokens.map(&:to_s).join

    elements = tokens_to_elements(tokens)

    parser = Parser.new(default_type)
    elements.each do |element|
      parser.parse(element)
    end
    @parsed_expressions = parser.expressions
  end

  def to_s
    @unparsed_expression
  end

  def count
    @parsed_expressions.length
  end

  # returns an Array of values
  def evaluate(interpreter)
    values = interpreter.evaluate(@parsed_expressions)
  end

  def evaluate_with_vars(interpreter, name, user_var_values)
    interpreter.set_user_var_values(name, user_var_values)
    result = evaluate(interpreter)
    interpreter.clear_user_var_values
    result
  end

  private

  def tokens_to_elements(tokens)
    elements = []
    tokens.each do |token|
      follows_operand = !elements.empty? && elements[-1].operand?
      elements << token_to_element(token, follows_operand)
    end
    elements << TerminalOperator.new
  end

  def token_to_element(token, follows_operand)
    return FunctionFactory.make(token.to_s) if
      FunctionFactory.valid?(token.to_s)

    element = nil
    (follows_operand ? binary_classes : unary_classes).each do |c|
      element = c.new(token) if element.nil? && c.accept?(token)
    end
    raise(BASICException,
          "Token '#{token.class}:#{token}' is not a value or operator") if
      element.nil?
    element
  end

  def binary_classes
    # first match is used; select order with care
    # UserFunction before VariableName
    [
      GroupStart,
      GroupEnd,
      ParamSeparator,
      BinaryOperator,
      NumericConstant,
      UserFunction,
      VariableName,
      TextConstant
    ]
  end

  def unary_classes
    # first match is used; select order with care
    # UserFunction before VariableName
    [
      GroupStart,
      GroupEnd,
      ParamSeparator,
      UnaryOperator,
      NumericConstant,
      UserFunction,
      VariableName,
      TextConstant
    ]
  end
end

# Value scalar expression (an R-value)
class ValueScalarExpression < AbstractExpression
  def initialize(tokens)
    super(tokens, ScalarValue)
  end

  def printable?
    true
  end

  def print(printer, interpreter)
    numeric_constants = evaluate(interpreter)
    numeric_constant = numeric_constants[0]
    numeric_constant.print(printer)
  end
end

# Value array expression (an R-value)
class ValueCompoundExpression < AbstractExpression
  def initialize(tokens, classref)
    super
  end

  def printable?
    true
  end

  def print(printer, interpreter, carriage)
    compounds = evaluate(interpreter)
    compound = compounds[0]
    compound.print(printer, interpreter, carriage)
  end
end

# Value array expression (an R-value)
class ValueArrayExpression < ValueCompoundExpression
  def initialize(tokens)
    super(tokens, ArrayValue)
  end
end

# Value matrix expression (an R-value)
class ValueMatrixExpression < ValueCompoundExpression
  def initialize(tokens)
    super(tokens, MatrixValue)
  end
end

# Target expression
class TargetExpression < AbstractExpression
  def initialize(tokens, type)
    super(tokens, ScalarValue)

    check_length
    check_all_lengths
    check_resolve_types

    @parsed_expressions.each do |parsed_expression|
      parsed_expression[-1] = type.new(parsed_expression[-1])
    end
  end

  private

  def check_length
    raise(BASICException, 'Value list is empty (length 0)') if
      @parsed_expressions.empty?
  end

  def check_all_lengths
    @parsed_expressions.each do |parsed_expression|
      raise(BASICException, 'Value is not assignable (length 0)') if
        parsed_expression.empty?
    end
  end

  def check_resolve_types
    @parsed_expressions.each do |parsed_expression|
      raise(BASICException,
            "Value is not assignable (type #{parsed_expression[-1].class})") if
        parsed_expression[-1].class.to_s != 'ScalarValue'
    end
  end
end

# User function definition
# Define the user function name, arguments, and expression
class UserFunctionDefinition
  attr_reader :name
  attr_reader :arguments
  attr_reader :template

  def initialize(tokens)
    # parse into name '=' expression
    line_text = tokens.map(&:to_s).join
    parts = split_tokens(tokens)
    raise(BASICException, "'#{line_text}' is not a valid assignment") if
      parts.size != 3
    user_function_prototype = UserFunctionPrototype.new(parts[0])
    @name = user_function_prototype.name
    @arguments = user_function_prototype.arguments
    @template = ValueScalarExpression.new(parts[2])
  end

  private

  def split_tokens(tokens)
    results = []
    nonkeywords = []
    tokens.each do |token|
      if token.operator? && token.equals?
        results << nonkeywords unless nonkeywords.empty?
        nonkeywords = []
        results << token
      else
        nonkeywords << token
      end
    end
    results << nonkeywords unless nonkeywords.empty?
    results
  end
end

# User function prototype
# Define the user function name and arguments
class UserFunctionPrototype
  attr_reader :name
  attr_reader :arguments

  def initialize(tokens)
    check_tokens(tokens)
    variables = check_params(tokens[2..-2])
    @name = tokens[0].to_s
    @arguments = variables.map(&:to_s)
    # arguments must be unique
    raise(BASICException, 'Duplicate parameters') unless
      @arguments.uniq.size == @arguments.size
  end

  def to_s
    @name
  end

  private

  # verify tokens are UserFunction, open, close
  def check_tokens(tokens)
    raise(BASICException, 'Invalid function specification') unless
      tokens.size >= 3 && tokens[0].user_function? &&
      tokens[1].groupstart? && tokens[-1].groupend?
  end

  # verify tokens variables and commas
  def check_params(params)
    variables = params.values_at(* params.each_index.select(&:even?))
    variables.each do |variable|
      raise(BASICException, 'Invalid parameter') unless variable.variable?
    end
    separators = params.values_at(* params.each_index.select(&:odd?))
    separators.each do |separator|
      raise(BASICException, 'Invalid list separator') unless
        separator.separator?
    end
    variables
  end
end

# Abstract assignment
class AbstractAssignment
  def initialize(tokens)
    # parse into variable, '=', expression
    @token_lists = split_tokens(tokens)
    line_text = tokens.map(&:to_s).join
    raise(BASICException, "'#{line_text}' is not a valid assignment") if
      @token_lists.size != 3 ||
      !(@token_lists[1].operator? && @token_lists[1].equals?)
  end

  def split_tokens(tokens)
    results = []
    nonkeywords = []
    tokens.each do |token|
      if token.operator? && token.equals?
        results << nonkeywords unless nonkeywords.empty?
        nonkeywords = []
        results << token
      else
        nonkeywords << token
      end
    end
    results << nonkeywords unless nonkeywords.empty?
    results
  end

  def count_target
    @target.count
  end

  def eval_target(interpreter)
    @target.evaluate(interpreter)
  end

  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end

  def to_postfix_s
    @expression.to_postfix_s
  end
end

# An assignment (part of a LET statement)
class ScalarAssignment < AbstractAssignment
  def initialize(tokens)
    super
    @target = TargetExpression.new(@token_lists[0], ScalarReference)
    @expression = ValueScalarExpression.new(@token_lists[2])
  end

  def count_value
    @expression.count
  end

  def eval_value(interpreter)
    @expression.evaluate(interpreter)
  end
end

# An assignment (part of an ARR LET statement)
class ArrayAssignment < AbstractAssignment
  def initialize(tokens)
    super
    @target = TargetExpression.new(@token_lists[0], ArrayReference)
    @expression = ValueArrayExpression.new(@token_lists[2])
  end

  def count_value
    @expression.count
  end

  def eval_value(interpreter)
    @expression.evaluate(interpreter)
  end
end

# An assignment (part of a MAT LET statement)
class MatrixAssignment < AbstractAssignment
  def initialize(tokens)
    super
    @target = TargetExpression.new(@token_lists[0], MatrixReference)
    @functions = {
      'CON' => FunctionCon,
      'ZER' => FunctionZer,
      'IDN' => FunctionIdn
    }
    @special_form = @token_lists[2].size == 1 &&
                    @functions.key?(@token_lists[2][0].to_s)
    @expression = if @special_form
                    @token_lists[2][0].to_s
                  else
                    ValueMatrixExpression.new(@token_lists[2])
                  end
  end

  def count_value
    if @special_form
      1
    else
      @expression.count
    end
  end

  def eval_value(interpreter)
    if @special_form
      # special form obtains variable name and dimensions at run-time
      vs = @target.evaluate(interpreter)
      v = vs[0]
      raise(Exception, 'Expected matrix reference') if
        v.class.to_s != 'MatrixReference'
      name = v.name
      dims = interpreter.get_dimensions(name)

      f = @functions[@expression].new('')
      matrix = f.evaluate(interpreter, [dims])
      [matrix]
    else
      @expression.evaluate(interpreter)
    end
  end
end
