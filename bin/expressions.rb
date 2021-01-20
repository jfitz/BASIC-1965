# Array with values
class BASICArray
  def self.make_array(dims, init_value)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |col|
      coords = AbstractElement.make_coord(col)
      values[coords] = init_value
    end

    values
  end

  def self.zero_values(dimensions)
    case dimensions.size
    when 1
      BASICArray.make_array(dimensions, NumericConstant.new(0))
    when 2
      raise BASICSyntaxError, 'Too many dimensions in array'
    end
  end

  def self.one_values(dimensions)
    case dimensions.size
    when 1
      BASICArray.make_array(dimensions, NumericConstant.new(1))
    when 2
      raise BASICSyntaxError, 'Too many dimensions in array'
    end
  end

  attr_reader :dimensions

  def initialize(dimensions, values)
    @dimensions = dimensions
    @values = values
  end

  def clone
    Array.new(@dimensions.clone, @values.clone)
  end

  def scalar?
    false
  end

  def array?
    true
  end

  def matrix?
    false
  end

  def values(interpreter)
    values = {}

    base = $options['base'].value
    (base..@dimensions[0].to_i).each do |col|
      value = get_value(col)
      coords = AbstractElement.make_coord(col)
      values[coords] = value
    end

    values
  end

  def get_value(col)
    coords = AbstractElement.make_coord(col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def to_s
    'ARRAY: ' + @values.to_s
  end

  def print(printer, interpreter)
    case @dimensions.size
    when 0
      raise BASICSyntaxError, 'Need dimension in array'
    when 1
      print_1(printer, interpreter)
    else
      raise BASICSyntaxError, 'Too many dimensions in array'
    end
  end

  def write(printer, interpreter)
    case @dimensions.size
    when 0
      raise BASICSyntaxError, 'Need dimension in array'
    when 1
      write_1(printer, interpreter)
    else
      raise BASICSyntaxError, 'Too many dimensions in array'
    end
  end

  private

  def print_1(printer, interpreter)
    n_cols = @dimensions[0].to_i

    fs_carriage = CarriageControl.new($options['field_sep'].value)

    base = $options['base'].value
    (base..n_cols).each do |col|
      value = get_value(col)
      value.print(printer)
      fs_carriage.print(printer, interpreter) if col < n_cols
    end
  end

  def write_1(printer, interpreter)
    n_cols = @dimensions[0].to_i

    fs_carriage = CarriageControl.new(',')

    base = $options['base'].value
    (base..n_cols).each do |col|
      value = get_value(col)
      value.write(printer)
      fs_carriage.write(printer, interpreter) if col < n_cols
    end
  end
end

# Matrix with values
class Matrix
  def self.make_array(dims, init_value)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |col|
      coords = AbstractElement.make_coord(col)
      values[coords] = init_value
    end

    values
  end

  def self.make_matrix(dims, init_value)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |row|
      (base..dims[1].to_i).each do |col|
        coords = AbstractElement.make_coords(row, col)
        values[coords] = init_value
      end
    end

    values
  end

  def self.zero_values(dimensions)
    case dimensions.size
    when 1
      Matrix.make_array(dimensions, NumericConstant.new(0))
    when 2
      Matrix.make_matrix(dimensions, NumericConstant.new(0))
    end
  end

  def self.one_values(dimensions)
    case dimensions.size
    when 1
      Matrix.make_array(dimensions, NumericConstant.new(1))
    when 2
      Matrix.make_matrix(dimensions, NumericConstant.new(1))
    end
  end

  def self.identity_values(dimensions)
    new_values = Matrix.make_matrix(dimensions, NumericConstant.new(0))
    one = NumericConstant.new(1)

    base = $options['base'].value

    (base..dimensions[0].to_i).each do |row|
      coords = AbstractElement.make_coords(row, row)
      new_values[coords] = one
    end

    new_values
  end

  attr_reader :dimensions

  def initialize(dimensions, values)
    @dimensions = dimensions
    @values = values
  end

  def clone
    Matrix.new(@dimensions.clone, @values.clone)
  end

  def scalar?
    false
  end

  def array?
    false
  end

  def matrix?
    true
  end

  def numeric_constant?
    value = get_value_2(0, 0)
    value.numeric_constant?
  end

  def text_constant?
    value = get_value_2(0, 0)
    value.text_constant?
  end

  def values_1
    values = {}

    base = $options['base'].value

    (base..@dimensions[0].to_i).each do |col|
      value = get_value_1(col)
      coords = AbstractElement.make_coord(col)
      values[coords] = value
    end

    values
  end

  def values_2
    values = {}

    base = $options['base'].value

    (base..@dimensions[0].to_i).each do |row|
      (base..@dimensions[1].to_i).each do |col|
        value = get_value_2(row, col)
        coords = AbstractElement.make_coords(row, col)
        values[coords] = value
      end
    end

    values
  end

  def get_value_1(col)
    coords = AbstractElement.make_coord(col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def get_value_2(row, col)
    coords = AbstractElement.make_coords(row, col)
    return @values[coords] if @values.key?(coords)
    NumericConstant.new(0)
  end

  def to_s
    'MATRIX: ' + @values.to_s
  end

  def print(printer, interpreter)
    case @dimensions.size
    when 0
      raise BASICSyntaxError, 'Need dimensions in matrix'
    when 1
      print_1(printer, interpreter)
    when 2
      print_2(printer, interpreter)
    else
      raise BASICSyntaxError, 'Too many dimensions in matrix'
    end
  end

  def write(printer, interpreter)
    case @dimensions.size
    when 0
      raise BASICSyntaxError, 'Need dimensions in matrix'
    when 1
      write_1(printer, interpreter)
    when 2
      write_2(printer, interpreter)
    else
      raise BASICSyntaxError, 'Too many dimensions in matrix'
    end
  end

  def transpose_values
    raise(BASICSyntaxError, 'TRN requires matrix') unless @dimensions.size == 2
    new_values = {}

    base = $options['base'].value

    (base..@dimensions[0].to_i).each do |row|
      (base..@dimensions[1].to_i).each do |col|
        value = get_value_2(row, col)
        coords = AbstractElement.make_coords(col, row)
        new_values[coords] = value
      end
    end

    new_values
  end

  def determinant
    raise(BASICExpressionError, 'DET requires matrix') unless @dimensions.size == 2

    raise BASICRuntimeError.new(:te_mat_no_sq, 'DET') if
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
    inv_values = Matrix.identity_values(@dimensions)

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

  private

  def print_1(printer, interpreter)
    n_cols = @dimensions[0].to_i

    base = $options['base'].value
    fs_carriage = CarriageControl.new($options['field_sep'].value)
    # gs_carriage = CarriageControl.new('NL')
    rs_carriage = CarriageControl.new('NL')

    (base..n_cols).each do |col|
      value = get_value_1(col)
      value.print(printer)
      fs_carriage.print(printer, interpreter) if col < n_cols
    end

    rs_carriage.print(printer, interpreter)
  end

  def print_2(printer, interpreter)
    n_rows = @dimensions[0].to_i
    n_cols = @dimensions[1].to_i

    base = $options['base'].value
    fs_carriage = CarriageControl.new($options['field_sep'].value)
    gs_carriage = CarriageControl.new('NL')
    rs_carriage = CarriageControl.new('NL')

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
        value = get_value_2(row, col)
        value.print(printer)
        fs_carriage.print(printer, interpreter) if col < n_cols
      end

      gs_carriage.print(printer, interpreter) if row < n_rows
    end

    rs_carriage.print(printer, interpreter)
  end

  def write_1(printer, interpreter)
    n_cols = @dimensions[0].to_i

    base = $options['base'].value
    fs_carriage = CarriageControl.new(',')
    # gs_carriage = CarriageControl.new(';')
    rs_carriage = CarriageControl.new('NL')

    (base..n_cols).each do |col|
      value = get_value_1(col)
      value.write(printer)
      fs_carriage.write(printer, interpreter) if col < n_cols
    end

    rs_carriage.write(printer, interpreter)
  end

  def write_2(printer, interpreter)
    n_rows = @dimensions[0].to_i
    n_cols = @dimensions[1].to_i

    base = $options['base'].value
    fs_carriage = CarriageControl.new(',')
    gs_carriage = CarriageControl.new(';')
    rs_carriage = CarriageControl.new('NL')

    (base..n_rows).each do |row|
      (base..n_cols).each do |col|
        value = get_value_2(row, col)
        value.write(printer)
        fs_carriage.write(printer, interpreter) if col < n_cols
      end

      gs_carriage.write(printer, interpreter) if row < n_rows
    end

    rs_carriage.write(printer, interpreter)
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
    base = $options['base'].value

    (base..@dimensions[1].to_i).each do |col|
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

    base = $options['base'].value

    (base..@dimensions[0].to_i).each do |row|
      new_col = 1
      next if row == exclude_row

      (base..@dimensions[1].to_i).each do |col|
        next if col == exclude_col
        coords = AbstractElement.make_coords(new_row, new_col)
        new_values[coords] = get_value_2(row, col)
        new_col += 1
      end

      new_row += 1
    end

    new_values
  end

  def calc_factor(values, row, col)
    denom_coords = AbstractElement.make_coords(col, col)
    denominator = values[denom_coords]
    numer_coords = AbstractElement.make_coords(row, col)
    numerator = values[numer_coords]
    numerator.divide(denominator)
  end

  def adjust_matrix_entry(values, row, col, wcol, factor)
    value_coords = AbstractElement.make_coords(row, wcol)
    minuend_coords = AbstractElement.make_coords(col, wcol)
    subtrahend = values[value_coords]
    minuend = values[minuend_coords]
    new_value = subtrahend - minuend.multiply(factor)
    values[value_coords] = new_value
  end

  def upper_triangle(n_cols, n_rows, values, inv_values)
    base = $options['base'].value

    (base..n_cols - 1).each do |col|
      (col + 1..n_rows).each do |row|
        # adjust values for this row
        factor = calc_factor(values, row, col)
        (base..n_cols).each do |wcol|
          adjust_matrix_entry(values, row, col, wcol, factor)
          adjust_matrix_entry(inv_values, row, col, wcol, factor)
        end
      end
    end
  end

  def lower_triangle(n_cols, values, inv_values)
    base = $options['base'].value

    n_cols.downto(base + 1) do |col|
      (col - 1).downto(base).each do |row|
        # adjust values for this row
        factor = calc_factor(values, row, col)
        (base..n_cols).each do |wcol|
          adjust_matrix_entry(values, row, col, wcol, factor)
          adjust_matrix_entry(inv_values, row, col, wcol, factor)
        end
      end
    end
  end

  def unitize(n_cols, n_rows, values, inv_values)
    base = $options['base'].value

    (base..n_rows).each do |row|
      denom_coords = AbstractElement.make_coords(row, row)
      denominator = values[denom_coords]
      (base..n_cols).each do |col|
        unitize_matrix_entry(values, row, col, denominator)
        unitize_matrix_entry(inv_values, row, col, denominator)
      end
    end
  end

  def unitize_matrix_entry(values, row, col, denominator)
    coords = AbstractElement.make_coords(row, col)
    numerator = values[coords]
    new_value = numerator.divide(denominator)
    values[coords] = new_value
  end
end

# Entry for cross-reference list
class XrefEntry
  attr_reader :variable
  attr_reader :signature
  attr_reader :is_ref

  def self.make_signature(arguments)
    return nil if arguments.nil?

    sigil_chars = {
      numeric: '_',
      integer: '%',
      string: '$',
      boolean: '?'
    }

    sigils = []

    arguments.each do |arg|
      content_type = :empty
      # TODO: I think we can remove check for Array
      if arg.class.to_s == 'Array'
        # an array is a parsed expression
        unless arg.empty?
          a0 = arg[-1]
          content_type = a0.content_type
        end
      else
        content_type = arg.content_type
      end

      sigils << sigil_chars[content_type]
    end

    return sigils
  end
  
  def initialize(variable, signature, is_ref)
    @variable = variable
    @signature = signature
    @is_ref = is_ref
  end

  def eql?(other)
    @variable == other.variable &&
      @signature == other.signature &&
      @is_ref == other.is_ref
  end

  def hash
    @variable.hash + @signature.hash + @is_ref.hash
  end

  def asize(x)
    return -1 if x.nil?
    x.size
  end

  def <=>(other)
    return -1 if self < other
    return 1 if self > other
    0
  end

  def ==(other)
    @variable == other.variable &&
      @signature == other.signature &&
      @is_ref == other.is_ref
  end

  def >(other)
    return true if @variable > other.variable
    return false if @variable < other.variable

    return true if asize(@signature) > asize(other.signature)
    return false if asize(@signature) < asize(other.signature)

    !@is_ref && other.is_ref
  end

  def >=(other)
    return true if @variable > other.variable
    return false if @variable < other.variable

    return true if asize(@signature) > asize(other.signature)
    return false if asize(@signature) < asize(other.signature)

    !@is_ref && other.is_ref
  end

  def <(other)
    return true if @variable < other.variable
    return false if @variable > other.variable

    return true if asize(@signature) < asize(other.signature)
    return false if asize(@signature) > asize(other.signature)

    @is_ref && !other.is_ref
  end

  def <=(other)
    return true if @variable < other.variable
    return false if @variable > other.variable

    return true if asize(@signature) < asize(other.signature)
    return false if asize(@signature) > asize(other.signature)

    @is_ref && !other.is_ref
  end

  def n_dims
    @signature.size
  end

  def to_s
    dims = ''
    dims = '(' + @signature.join(',') + ')' unless @signature.nil?

    ref = ''
    ref = '=' if @is_ref

    @variable.to_s + dims + ref
  end

  def to_text
    dims = ''
    dims = '(' + @signature.join(',') + ')' unless @signature.nil?

    @variable.to_s + dims
  end
end

# Expression parser
class Parser
  def initialize(default_shape)
    @operator_stack = []
    @elements_stack = []
    @current_elements = []
    @parens_stack = []
    @shape_stack = [default_shape]
    @parens_group = []
    @previous_element = InitialOperator.new
  end

  def parse(element)
    ## puts "ELEMENT: #{element}"
    ## puts "OP STK: #{@operator_stack.map(&:to_s)}"
    ## puts "ELEM STK: #{@elements_stack.map(&:to_s)}"
    ## puts "CURR ELEM: #{@current_elements.map(&:to_s)}"
    ## puts "PAREN STK: #{@parens_stack.map(&:to_s)}"
    ## puts "SHAPE STK: #{@shape_stack.map(&:to_s)}"
    ## puts "PARENS GR: #{@parens_group.map(&:to_s)}"
    if element.group_separator?
      group_separator(element)
    elsif element.operator?
      operator_higher(element)
    elsif element.function_variable?
      function_variable(element)
    else
      # the element is an operand, append it to the output list
      @current_elements << element
    end

    @previous_element = element
  end

  def expressions
    raise(BASICExpressionError, 'Too many operators') unless
      @operator_stack.empty?

    expressions = []

    @parens_group.each do |expression|
      expressions << Expression.new(expression)
    end

    expressions << Expression.new(@current_elements) unless
      @current_elements.empty?

    expressions
  end

  private

  def stack_to_elements(stack, elements)
    until stack.empty? || stack[-1].starter?
      op = stack.pop
      elements << op
    end
  end

  def stack_to_precedence(stack, elements, element)
    while !stack.empty? &&
          !stack[-1].starter? &&
          stack[-1].precedence >= element.precedence
      op = stack.pop
      elements << op
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
      start_associated_group(element, @previous_element.default_shape)
    elsif @previous_element.variable?
      start_associated_group(element, :scalar)
    else
      start_simple_group(element)
    end
  end

  # a group associated with a function or variable
  # (arguments or subscripts)
  def start_associated_group(element, shape)
    @elements_stack.push(@current_elements)
    @current_elements = []
    @operator_stack.push(ParamStart.new(element))
    @parens_stack << @parens_group
    @parens_group = []
    @shape_stack.push(shape)
  end

  def start_simple_group(element)
    @operator_stack.push(element)
    @parens_stack << @parens_group
    @parens_group = []
    @shape_stack.push(:scalar)
  end

  # pop the operator stack until the corresponding left paren is found
  # Append each operator to the end of the output list
  def pop_to_group_start
    stack_to_elements(@operator_stack, @current_elements)
    @parens_group << @current_elements
    @current_elements = []
  end

  # pop the operator stack until the corresponding left paren is removed
  # Append each operator to the end of the output list
  def end_group(group_end_element)
    stack_to_elements(@operator_stack, @current_elements)
    @parens_group << @current_elements

    raise(BASICExpressionError, 'Too few operators') if @operator_stack.empty?

    # remove the '(' or '[' starter
    start_op = @operator_stack.pop

    error = 'Bracket/parenthesis mismatch, found ' + group_end_element.to_s +
            ' to match ' + start_op.to_s

    raise(BASICExpressionError, error) unless group_end_element.match?(start_op)

    if start_op.param_start?
      expressions = []
      @parens_group.each { |group| expressions << Expression.new(group) }
      list = List.new(expressions)
      @operator_stack.push(list)
      @current_elements = @elements_stack.pop
    end

    @parens_group = @parens_stack.pop
    @shape_stack.pop
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def operator_higher(element)
    stack_to_precedence(@operator_stack, @current_elements, element)

    # push the operator onto the operator stack
    @operator_stack.push(element) unless element.terminal?
  end

  def function_variable(element)
    if element.user_function?
      start_user_function(element)
    elsif element.function?
      start_function(element)
    elsif element.variable?
      start_variable(element)
    end
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_user_function(element)
    stack_to_precedence(@operator_stack, @current_elements, element)

    # push the variable onto the operator stack
    variable = UserFunction.new(element)
    @operator_stack.push(variable)
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_function(element)
    stack_to_precedence(@operator_stack, @current_elements, element)

    # push the function onto the operator stack
    @operator_stack.push(element)
  end

  # remove operators already on the stack that have higher
  # or equal precedence
  # append them to the output list
  def start_variable(element)
    stack_to_precedence(@operator_stack, @current_elements, element)
    # push the variable onto the operator stack
    if @shape_stack[-1] == :declaration
      variable = Declaration.new(element)
    else
      variable = Variable.new(element, @shape_stack[-1], [])
    end

    @operator_stack.push(variable)
  end
end

# independent expression
class Expression
  attr_reader :elements

  def initialize(elements)
    @elements = elements
  end

  def empty?
    @elements.empty?
  end

  def content_type
    content_type = :empty

    unless @elements.empty?
      element0 = @elements[-1]
      content_type = element0.content_type
    end

    content_type
  end

  def dump
    lines = []

    @elements.each { |element| lines << element.dump }

    lines
  end

  def numerics
    vars = []
    previous = nil

    # backwards so the unary operator (if any) is seen first
    @elements.reverse_each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        vars += AbstractExpression.parsed_expressions_numerics(sublist)
      elsif element.numeric_constant?
        if !previous.nil? &&
           previous.operator? &&
           previous.unary? &&
           previous.to_s == '-'
          vars << element.negate
        else
          vars << element
        end
      end
      previous = element
    end

    vars
  end

  def strings
    strs = []

    @elements.each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        strs += AbstractExpression.parsed_expressions_strings(sublist)
      elsif element.text_constant?
        strs << element
      end
    end

    strs
  end

  def booleans
    bools = []

    @elements.each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        bools += AbstractExpression.parsed_expressions_booleans(sublist)
      elsif element.boolean_constant?
        bools << element
      end
    end

    bools
  end

  def variables
    vars = []
    previous = nil

    @elements.each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        vars += AbstractExpression.parsed_expressions_variables(sublist)
      elsif element.variable?
        arguments = nil

        if element.array?
          token = NumericConstantToken.new('0')
          constant = NumericConstant.new(token)
          arguments = [constant]
        end

        if element.matrix?
          token = NumericConstantToken.new('0')
          constant = NumericConstant.new(token)
          arguments = [constant, constant]
        end

        arguments = previous.list if !previous.nil? && previous.list?

        is_ref = element.reference?

        signature = XrefEntry.make_signature(arguments)
        vars << XrefEntry.new(element.to_s, signature, is_ref)
      end

      previous = element
    end

    vars
  end

  def operators
    opers = []

    @elements.each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        opers += AbstractExpression.parsed_expressions_operators(sublist)
      elsif element.operator?
        arguments = element.arguments

        is_ref = false

        signature = XrefEntry.make_signature(arguments)
        opers << XrefEntry.new(element.to_s, signature, is_ref)
      end
    end

    opers
  end

  def functions
    vars = []
    previous = nil

    @elements.each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        vars += AbstractExpression.parsed_expressions_functions(sublist)
      elsif element.function? && !element.user_function?
        arguments = nil
        arguments = previous.list if !previous.nil? && previous.list?

        is_ref = element.reference?

        signature = XrefEntry.make_signature(arguments)
        vars << XrefEntry.new(element.to_s, signature, is_ref)
      end

      previous = element
    end

    vars
  end

  def userfuncs
    vars = []

    previous = nil

    @elements.each do |element|
      if element.list?
        # recurse into expressions in list
        sublist = element.list
        vars += AbstractExpression.parsed_expressions_userfuncs(sublist)
      elsif element.user_function?
        arguments = nil
        arguments = previous.list if !previous.nil? && previous.list?

        is_ref = element.reference?

        signature = XrefEntry.make_signature(arguments)
        vars << XrefEntry.new(element.to_s, signature, is_ref)
      end

      previous = element
    end

    vars
  end
end

# base class for expressions
class AbstractExpression
  attr_reader :comprehension_effort

  def initialize(tokens, shape)
    @tokens = tokens
    @numeric_constant = tokens.size == 1 && tokens[0].numeric_constant?
    @text_constant = tokens.size == 1 && tokens[0].text_constant?
    @target = false
    @carriage = false

    # build elements and parse into expression
    elements = tokens_to_elements(tokens)
    parser = Parser.new(shape)
    elements.each { |element| parser.parse(element) }
    expressions = parser.expressions
    set_arguments_1(expressions)

    @shape = shape

    @comprehension_effort = 1
    expressions.each do |expression|
      prev = nil

      elements = expression.elements
      elements.each do |element|
        @comprehension_effort += 1 if element.operator?

        @comprehension_effort += 1 if
          element.operator? && !prev.nil? && prev.operator?

        @comprehension_effort += 1 if element.function?

        # function? includes user-defined funcs,
        # so the next line makes comprehension effort 2
        @comprehension_effort += 1 if element.user_function?
        prev = element
      end
    end

    @expressions = expressions
  end

  def to_s
    @tokens.map(&:to_s).join
  end

  def dump
    lines = []

    @expressions.each do |expression|
      elements = expression.elements
      # TODO: remove Array check
      x = elements.map(&:dump)
      if x.class.to_s == 'Array'
        lines += x.flatten
      else
        lines << x
      end
    end

    lines
  end

  def carriage_control?
    @carriage
  end

  def count
    @expressions.length
  end

  def numeric_constant?
    @numeric_constant
  end

  def text_constant?
    @text_constant
  end

  def target?
    @target
  end

  # returns an Array of values
  def evaluate(interpreter)
    interpreter.evaluate_n(@expressions)
  end

  def numerics
    AbstractExpression.parsed_expressions_numerics(@expressions)
  end

  def strings
    AbstractExpression.parsed_expressions_strings(@expressions)
  end

  def booleans
    AbstractExpression.parsed_expressions_booleans(@expressions)
  end

  def variables
    AbstractExpression.parsed_expressions_variables(@expressions)
  end

  def operators
    AbstractExpression.parsed_expressions_operators(@expressions)
  end

  def functions
    AbstractExpression.parsed_expressions_functions(@expressions)
  end

  def userfuncs
    AbstractExpression.parsed_expressions_userfuncs(@expressions)
  end

  private

  def set_arguments_1(expressions)
    expressions.each do |expression|
      set_arguments_2(expression)
    end
  end

  def set_arguments_2(expression)
    content_type_stack = []

    elements = expression.elements

    elements.each do |element|
      if element.list?
        set_arguments_1(element.list)
      elsif element.operator?
        element.set_arguments(content_type_stack)
        content_type_stack.push(element)
      else
        element.pop_stack(content_type_stack)
        content_type_stack.push(element)
      end
    end

    raise(BASICExpressionError, 'Bad expression') if
      content_type_stack.size > 1
  end

  def self.parsed_expressions_numerics(expressions)
    vars = []

    expressions.each do |expression|
      vars.concat expression.numerics
    end

    vars
  end

  def self.parsed_expressions_strings(expressions)
    strs = []

    expressions.each do |expression|
      strs.concat expression.strings
    end

    strs
  end

  def self.parsed_expressions_booleans(expressions)
    bools = []

    expressions.each do |expression|
      bools.concat expression.booleans
    end

    bools
  end

  def self.parsed_expressions_variables(expressions)
    vars = []

    expressions.each do |expression|
      vars.concat expression.variables
    end

    vars
  end

  def self.parsed_expressions_operators(expressions)
    opers = []

    expressions.each do |expression|
      opers.concat expression.operators
    end

    opers
  end

  def self.parsed_expressions_functions(expressions)
    vars = []

    expressions.each do |expression|
      vars.concat expression.functions
    end

    vars
  end

  def self.parsed_expressions_userfuncs(expressions)
    vars = []

    expressions.each do |expression|
      vars.concat expression.userfuncs
    end

    vars
  end

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

    if element.nil?
      raise(BASICExpressionError,
            "Token '#{token.class}:#{token}' is not a value or operator")
    end

    element
  end

  def binary_classes
    # first match is used; select order with care
    # UserFunction before VariableName
    [
      GroupStart,
      GroupEnd,
      ParamSeparator,
      BinaryOperatorPlus,
      BinaryOperatorMinus,
      BinaryOperatorMultiply,
      BinaryOperatorDivide,
      BinaryOperatorPower,
      BinaryOperatorEqual,
      BinaryOperatorNotEqual,
      BinaryOperatorLess,
      BinaryOperatorLessEqual,
      BinaryOperatorGreater,
      BinaryOperatorGreaterEqual,
      BooleanConstant,
      NumericConstant,
      UserFunctionName,
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
      UnaryOperatorPlus,
      UnaryOperatorMinus,
      UnaryOperatorHash,
      BooleanConstant,
      NumericConstant,
      UserFunctionName,
      VariableName,
      TextConstant
    ]
  end
end

# Value expression (an R-value)
class ValueExpression < AbstractExpression
  def self.set_content_type(expression)
    stack = []

    elements = expression.elements

    elements.each do |element|
      element.set_content_type(stack)
      stack.push element.content_type
    end

    stack[0]
  end

  def initialize(_, shape)
    super

    types = []

    @expressions.each do |expression|
      type = ValueExpression.set_content_type(expression)
      types << type
    end
  end

  def printable?
    true
  end

  def filehandle?
    return false if @expressions.empty?

    expression = @expressions[0]
    elements = expression.elements
    element = elements[0]
    last_token = elements[-1]
    last_token.operator? && last_token.pound?
  end

  def scalar?
    @shape == :scalar
  end

  def print(printer, interpreter)
    numeric_constants = evaluate(interpreter)

    return if numeric_constants.empty?

    numeric_constant = numeric_constants[0]
    numeric_constant.print(printer)
  end

  def write(printer, interpreter)
    numeric_constants = evaluate(interpreter)

    return if numeric_constants.empty?

    numeric_constant = numeric_constants[0]
    numeric_constant.write(printer)
  end

  def compound_print(printer, interpreter)
    compounds = evaluate(interpreter)

    return if compounds.empty?

    compound = compounds[0]
    compound.print(printer, interpreter)
  end

  def compound_write(printer, interpreter)
    compounds = evaluate(interpreter)

    return if compounds.empty?

    compound = compounds[0]
    compound.write(printer, interpreter)
  end
end

# Declaration expression
class DeclarationExpression < AbstractExpression
  def initialize(tokens)
    super(tokens, :declaration)

    check_length
    check_all_lengths
    check_resolve_types
  end

  private

  def check_length
    raise(BASICExpressionError, 'Value list is empty (length 0)') if
      @expressions.empty?
  end

  def check_all_lengths
    @expressions.each do |expression|
      raise(BASICExpressionError, 'Value is not declaration (length 0)') if
        expression.empty?
    end
  end

  def check_resolve_types
    @expressions.each do |expression|
      elements = expression.elements
      last_element = elements[-1]
      if last_element.class.to_s != 'Declaration'
        raise(BASICExpressionError,
              "Value is not declaration (type #{last_element.class})")
      end
    end
  end
end

# Target expression
class TargetExpression < AbstractExpression
  def initialize(tokens, shape)
    super

    check_length
    check_all_lengths
    check_resolve_types

    @target = true

    @expressions.each do |expression|
      elements = expression.elements

      elements[-1].valref = :reference
    end
  end

  def filehandle?
    false
  end

  private

  def check_length
    raise(BASICSyntaxError, 'Value list is empty (length 0)') if
      @expressions.empty?
  end

  def check_all_lengths
    @expressions.each do |expression|
      elements = expression.elements

      raise(BASICExpressionError, 'Value is not assignable (length 0)') if
        elements.empty?
    end
  end

  def check_resolve_types
    @expressions.each do |expression|
      elements = expression.elements

      if elements[-1].class.to_s != 'Variable' &&
         elements[-1].class.to_s != 'UserFunction'
        raise(BASICExpressionError,
              "Value is not assignable (type #{expression[-1].class})")
      end
    end
  end
end

# User function definition
# Define the user function name, arguments, and expression
class UserFunctionDefinition
  attr_reader :name
  attr_reader :arguments
  attr_reader :sig
  attr_reader :expression
  attr_reader :numerics
  attr_reader :strings
  attr_reader :booleans
  attr_reader :variables
  attr_reader :operators
  attr_reader :functions
  attr_reader :userfuncs
  attr_reader :comprehension_effort

  def initialize(tokens)
    # parse into name '=' expression
    line_text = tokens.map(&:to_s).join
    parts = split_tokens(tokens)

    raise(BASICExpressionError, "'#{line_text}' is not a valid assignment") if
      parts.size != 3

    user_function_prototype = UserFunctionPrototype.new(parts[0])
    @name = user_function_prototype.name
    @arguments = user_function_prototype.arguments
    @sig = XrefEntry.make_signature(@arguments)
    @expression = ValueExpression.new(parts[2], :scalar)
    @numerics = @expression.numerics
    @strings = @expression.strings
    @booleans = @expression.booleans
    @variables = @expression.variables
    @operators = @expression.operators
    @functions = @expression.functions

    # add parameters to function as references
    @arguments.each do |argument|
      @variables << XrefEntry.new(argument.to_s, nil, true)
    end

    signature = XrefEntry.make_signature(@arguments)
    xr = XrefEntry.new(@name.to_s, signature, true)
    @userfuncs = [xr] + @expression.userfuncs

    @comprehension_effort = @expression.comprehension_effort
  end

  def dump
    lines = []
    lines << @name.dump
    @arguments.each { |arg| lines << arg.dump }
    lines += @expression.dump
    lines
  end

  def to_s
    vnames = @arguments.map(&:to_s).join(',')
    @name.to_s + '(' + vnames + ')' + '=' + @expression.to_s
  end

  def signature
    numeric_spec = { 'type' => :numeric, 'shape' => :scalar }
    sig = []

    @arguments.each do
      # arguments can only be numeric and scalar
      sig << numeric_spec
    end

    sig
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
    @name = UserFunctionName.new(tokens[0])
    @arguments = variable_names(tokens[2..-2])

    # arguments must be unique
    names = @arguments.map(&:to_s)
    raise(BASICExpressionError, 'Duplicate parameters') unless
      names.uniq.size == names.size
  end

  def to_s
    @name
  end

  private

  # verify tokens are UserFunction, open, close
  def check_tokens(tokens)
    raise(BASICSyntaxError, 'Invalid function specification') unless
      tokens.size >= 3 && tokens[0].user_function? &&
      tokens[1].groupstart? && tokens[-1].groupend?
  end

  # verify tokens variables and commas
  def variable_names(params)
    name_tokens = params.values_at(* params.each_index.select(&:even?))

    variable_names = []
    name_tokens.each do |name_token|
      variable_names << VariableName.new(name_token)
    end

    separators = params.values_at(* params.each_index.select(&:odd?))
    separators.each do |separator|
      raise(BASICSyntaxError, 'Invalid list separator') unless
        separator.separator?
    end

    variable_names
  end
end

# Assignment
class Assignment
  attr_reader :target
  attr_reader :numerics
  attr_reader :strings
  attr_reader :booleans
  attr_reader :variables
  attr_reader :operators
  attr_reader :functions
  attr_reader :userfuncs
  attr_reader :comprehension_effort

  def initialize(tokens, shape)
    # parse into variable, '=', expression
    @token_lists = split_tokens(tokens)

    line_text = tokens.map(&:to_s).join

    raise(BASICSyntaxError, "'#{line_text}' is not a valid assignment") if
      @token_lists.size != 3 ||
      !(@token_lists[1].operator? && @token_lists[1].equals?)

    @numerics = []
    @strings = []
    @booleans = []
    @variables = []
    @operators = []
    @functions = []
    @userfuncs = []

    @target = TargetExpression.new(@token_lists[0], shape)
    @expression = ValueExpression.new(@token_lists[2], shape)
    make_references
    @comprehension_effort = @target.comprehension_effort + @expression.comprehension_effort
  end

  def dump
    lines = []
    lines += @target.dump
    lines += @expression.dump
    lines << 'AssignmentOperator:='
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

  def make_references
    @numerics = @target.numerics + @expression.numerics
    @strings = @target.strings + @expression.strings
    @booleans = @target.booleans + @expression.booleans
    @variables = @target.variables + @expression.variables
    @operators = @target.operators + @expression.operators
    @functions = @target.functions + @expression.functions
    @userfuncs = @target.userfuncs + @expression.userfuncs
  end

  public

  def count_target
    @target.count
  end

  def count_value
    @expression.count
  end

  def eval_value(interpreter)
    @expression.evaluate(interpreter)
  end

  def eval_target(interpreter)
    @target.evaluate(interpreter)
  end

  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end
end
