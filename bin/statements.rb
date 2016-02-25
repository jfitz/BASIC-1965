def squeeze_out_spaces(text)
  text = text.strip
  in_remark = text.start_with?('REM')
  squeezed_text = ''
  in_quotes = false
  text.each_char do |c|
    in_quotes = !in_quotes if c == '"'
    squeezed_text += c if c != ' ' || in_quotes || in_remark
  end
  squeezed_text
end

# Statement factory class
class StatementFactory
  def initialize
    @statement_definitions = statement_definitions
  end

  def parse(line)
    line_num = nil
    statement = nil
    m = /\A\d+/.match(line)
    unless m.nil?
      line_num = LineNumber.new(m[0])
      line_text = m.post_match
      statement = create(line_text)
    end
    [line_num, statement]
  end

  private

  def create(text)
    squeezed = squeeze_out_spaces(text)
    statement = UnknownStatement.new(text)
    statement = EmptyStatement.new if squeezed == ''
    keyword = ''
    @statement_definitions.each_key do |def_keyword|
      length = def_keyword.length
      stmt_keyword = squeezed[0..length - 1]
      keyword = def_keyword if
        stmt_keyword.size > keyword.size &&
        stmt_keyword == def_keyword
    end
    statement = @statement_definitions[keyword].new(text, squeezed) unless
      keyword.size == 0
    statement
  end

  def statement_definitions
    {
      'END' => EndStatement,
      'STOP' => StopStatement,
      'RETURN' => ReturnStatement,
      'IF' => IfStatement,
      'REM' => RemarkStatement,
      'DIM' => DimStatement,
      'DEF' => DefineFunctionStatement,
      'LET' => LetStatement,
      'FOR' => ForStatement,
      'GOTO' => GotoStatement,
      'NEXT' => NextStatement,
      'READ' => ReadStatement,
      'DATA' => DataStatement,
      'RESTORE' => RestoreStatement,
      'INPUT' => InputStatement,
      'GOSUB' => GosubStatement,
      'PRINT' => PrintStatement,
      'TRACE' => TraceStatement,
      'MATPRINT' => MatPrintStatement,
      'MATREAD' => MatReadStatement,
      'MAT' => MatLetStatement
    }
  end
end

# parent of all statement classes
class AbstractStatement
  attr_reader :errors

  def initialize(keyword, text, squeezed)
    @keyword = keyword
    @text = text
    squeezed_keyword = squeeze_out_spaces(keyword)
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    @errors = []
  end

  def pre_execute(_)
    0
  end

  def list
    @text
  end

  def pretty
    if @errors.size == 0
      ' ' + to_s
    else
      @text
    end
  end

  def execute(interpreter, trace)
    if @errors.size == 0
      execute_cmd(interpreter, trace)
    else
      @errors.each do |error|
        puts "line #{interpreter.current_line_number}: #{error}"
      end
    end
  end

  protected

  # converts text line to constant values
  def textline_to_constants(line)
    values = []
    text_values = line.split(',')
    text_values.each do |value|
      v = value.strip
      fail(BASICException, "Value '#{value}' not numeric") unless
        NumericConstant.init?(v)
      values << NumericConstant.new(v)
    end
    values
  end

  protected

  def make_coord(c)
    '(' + c.to_s + ')'
  end

  def make_coords(r, c)
    '(' + r.to_s + ',' + c.to_s + ')'
  end
end

# unknown statement
class UnknownStatement < AbstractStatement
  def initialize(line)
    super('', line, line)
    @errors << "Unknown statement '#{@text.strip}'"
  end

  def to_s
    @text
  end

  def execute_cmd(_, _)
    0
  end
end

# empty statement (line number only)
class EmptyStatement < AbstractStatement
  def initialize
    super('', '', '')
  end

  def to_s
    ''
  end

  def execute_cmd(_, _)
    0
  end
end

# REMARK
class RemarkStatement < AbstractStatement
  def initialize(line, _)
    # override the method to squeeze spaces from line
    squeezed = line.strip
    super('REM', line, squeezed)
  end

  def to_s
    @keyword + @rest
  end

  def execute_cmd(_, _)
    0
  end
end

# DIM
class DimStatement < AbstractStatement
  def initialize(line, squeezed)
    super('DIM', line, squeezed)
    text_list = split_args(@rest, false)
    # variable [comma, variable]...
    @expression_list = []
    if text_list.size > 0
      text_list.each do |text_item|
        begin
          @expression_list << DimensionExpression.new(text_item)
        rescue BASICException
          @errors << "Invalid variable #{text_item}"
        end
      end
    else
      @errors << 'No variables specified'
    end
  end

  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end

  def execute_cmd(interpreter, _)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      subscripts = variable.subscripts
      if subscripts.size == 0
        fail BASICException, 'DIM statement requires subscript range'
      end
      interpreter.set_dimensions(variable.name, subscripts)
    end
  end
end

# LET
class LetStatement < AbstractStatement
  def initialize(line, squeezed)
    super('LET', line, squeezed)
    begin
      @assignment = ScalarAssignment.new(@rest)
      if @assignment.count_target != 1
        @errors << 'Assignment must have only one left-hand value'
      end
      if @assignment.count_value != 1
        @errors << 'Assignment must have only one right-hand value'
      end
    rescue BASICException => e
      @errors << e.message
    end
  end

  def to_s
    @keyword + ' ' + @assignment.to_s
  end

  def execute_cmd(interpreter, trace)
    l_values = @assignment.eval_target(interpreter)
    l_value = l_values[0]
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    interpreter.set_value(l_value, r_value)
    printer = interpreter.print_handler
    printer.trace_output(' ' + l_value.to_s + ' = ' + r_value.to_s) if trace
  end
end

# INPUT
class InputStatement < AbstractStatement
  def initialize(line, squeezed)
    super('INPUT', line, squeezed)
    @default_prompt = TextConstant.new('"? "')
    @prompt = @default_prompt
    text_list = split_args(@rest, false)
    if text_list.length > 0
      if TextConstant.init?(text_list[0])
        @prompt = TextConstant.new(text_list[0])
        text_list.delete_at(0)
      end
      ## todo: check list length again (after removing prompt item)
      # variable [comma, variable]...
      @expression_list = build_expression_list(text_list)
    else
      @errors << 'No variables specified'
    end
  end

  def to_s
    if @prompt != @default_prompt
      @keyword + ' ' + @prompt.to_s + ', ' + @expression_list.join(', ')
    else
      @keyword + ' ' + @expression_list.join(', ')
    end
  end

  def execute_cmd(interpreter, trace)
    printer = interpreter.print_handler
    values = input_values
    name_value_pairs =
      zip(@expression_list, values[0, @expression_list.length])
    name_value_pairs.each do |hash|
      l_values = hash['name'].evaluate(interpreter)
      l_value = l_values[0]
      value = hash['value']
      interpreter.set_value(l_value, value)
      printer.trace_output(' ' + l_value.to_s + ' = ' + value.to_s) if trace
    end
    printer.implied_newline
  end

  private

  def zip(names, values)
    fail(BASICException, 'Unequal lists') if names.size != values.size
    results = []
    (0...names.size).each do |i|
      results << { 'name' => names[i], 'value' => values[i] }
    end
    results
  end

  def input_values
    values = []
    prompt = @prompt
    while values.size < @expression_list.size
      print prompt.value
      input_line = gets
      values += textline_to_constants(input_line.chomp)
      prompt = @default_prompt
    end
    values
  end

  def build_expression_list(text_list)
    expression_list = []
    text_list.each do |text_item|
      begin
        expression_list << TargetScalarExpression.new(text_item)
      rescue BASICException
        @errors << "Invalid variable #{text_item}"
      end
    end
    expression_list
  end
end

# IF/THEN
class IfStatement < AbstractStatement
  def initialize(line, squeezed)
    super('IF', line, squeezed)
    parts = @rest.split('THEN')
    begin
      @boolean_expression = BooleanExpression.new(parts[0])
    rescue BASICException => e
      @errors << e.message
      @boolean_expression = parts[0]
    end
    @destination = LineNumber.new(parts[1])
  end

  def to_s
    @keyword + ' ' + @boolean_expression.to_s + ' THEN ' + @destination.to_s
  end

  def execute_cmd(interpreter, trace)
    @boolean_expression.evaluate(interpreter)
    interpreter.next_line_number = @destination if @boolean_expression.result
    if trace
      printer = interpreter.print_handler
      s = ' ' + @boolean_expression.a_value.to_s +
          ' ' + @boolean_expression.operator.to_s +
          ' ' + @boolean_expression.b_value.to_s +
          ' ' + @boolean_expression.result.to_s
      printer.trace_output(s)
    end
  end
end

# Common for PRINT and MAT PRINT
class AbstractPrintStatement < AbstractStatement
  def initialize(keyword, line, squeezed)
    super(keyword, line, squeezed)
  end

  def to_s
    varnames = []
    @print_item_pairs.each do |print_pair|
      print_expression = print_pair[0]
      value = print_expression.to_s
      carriage = print_pair[1].to_s
      item = ' ' + value + carriage
      varnames << item unless print_expression.empty?
    end
    @keyword + varnames.join('')
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
    @print_item_pairs.each do |print_pair|
      variable = print_pair[0]
      carriage = print_pair[1]
      variable.print(printer, interpreter, carriage)
    end
  end
end

# PRINT
class PrintStatement < AbstractPrintStatement
  def initialize(line, squeezed)
    super('PRINT', line, squeezed)

    item_list = split_args(@rest, true)
    # variable/constant, [separator, variable/constant]... [separator]

    print_item_list = []
    previous_item = CarriageControl.new('')
    item_list.each do |print_item|
      if print_item == ',' || print_item == ';'
        # the item is a carriage control item
        # save previous print thing, or create an empty one
        item = CarriageControl.new(print_item)
        print_item_list << item
      else
        # insert a plain carriage control
        item = CarriageControl.new('')
        print_item_list << item if previous_item.printable?
        begin
          item = ScalarPrintableExpression.new(print_item.strip)
          print_item_list << item
        rescue BASICException => e
          @errors << "Invalid print item '#{print_item}': #{e.message}"
        end
      end
      previous_item = item
    end

    # add implied items at end of list
    print_item_list << ScalarPrintableExpression.new(nil) if
      print_item_list.size == 0
    print_item_list << CarriageControl.new('NL') if
      print_item_list[-1].class.to_s != 'CarriageControl'

    # convert to pairs
    @print_item_pairs = print_item_list.each_slice(2).to_a
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def initialize(line, squeezed)
    super('GOTO', line, squeezed)
    destination = @rest
    begin
      @destination = LineNumber.new(destination)
    rescue BASICException
      @errors << "Invalid line number #{destination}"
    end
  end

  def to_s
    @keyword + ' ' + @destination.to_s
  end

  def execute_cmd(interpreter, _)
    interpreter.next_line_number = @destination
  end
end

# GOSUB
class GosubStatement < AbstractStatement
  def initialize(line, squeezed)
    super('GOSUB', line, squeezed)
    destination = @rest
    begin
      @destination = LineNumber.new(destination)
    rescue BASICException
      @errors << "Invalid line number #{destination}"
    end
  end

  def to_s
    @keyword + ' ' + @destination.to_s
  end

  def execute_cmd(interpreter, _)
    interpreter.push_return(interpreter.next_line_number)
    interpreter.next_line_number = @destination
  end
end

# RETURN
class ReturnStatement < AbstractStatement
  def initialize(line, squeezed)
    super('RETURN', line, squeezed)
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter, _)
    interpreter.next_line_number = interpreter.pop_return
  end
end

# Helper class for FOR/NEXT
class ForNextControl
  attr_reader :control_variable
  attr_reader :loop_start_number
  attr_reader :end_value

  def initialize(control_variable, loop_start_number,
                 start_value, end_value, step_value)
    if start_value.class.to_s != 'NumericConstant'
      fail Exception, "Invalid start value #{start_value} #{start_value.class}"
    end
    if end_value.class.to_s != 'NumericConstant'
      fail Exception, "Invalid end value #{end_value} #{end_value.class}"
    end
    if step_value.class.to_s != 'NumericConstant'
      fail Exception, "Invalid step value #{step_value} #{step_value.class}"
    end
    @control_variable = control_variable
    @loop_start_number = loop_start_number
    @start_value = start_value
    @end_value = end_value
    @step_value = step_value
    @current_value = start_value
  end

  def bump_control_variable(interpreter)
    @current_value = @current_value + @step_value
    interpreter.set_value(@control_variable, @current_value)
  end

  def front_terminated?
    if @step_value > 0
      @start_value > @end_value
    elsif @step_value < 0
      @start_value < @end_value
    else
      false
    end
  end

  def terminated?(interpreter)
    current_value = interpreter.get_value(@control_variable)
    if @step_value > 0
      current_value + @step_value > @end_value
    elsif @step_value < 0
      current_value + @step_value < @end_value
    else
      false
    end
  end
end

# FOR statement
class ForStatement < AbstractStatement
  def initialize(line, squeezed)
    super('FOR', line, squeezed)
    # parse control variable, '=', numeric_expression, "TO",
    # numeric_expression, "STEP", numeric_expression
    parts = @rest.split('=', 2)
    fail(BASICException, 'Syntax error') if parts.size != 2
    begin
      var_name = VariableName.new(parts[0])
      @control_variable = ScalarValue.new(var_name)
    rescue BASICException => e
      @errors << e.message
    end
    parts = parts[1].split('TO', 2)
    fail(BASICException, 'Syntax error') if parts.size != 2
    @start_value = ValueScalarExpression.new(parts[0])

    parts = parts[1].split('STEP', 2)
    @end_value = ValueScalarExpression.new(parts[0])

    @has_step_value = parts.size > 1
    @step_value = ValueScalarExpression.new('1')
    @step_value = ValueScalarExpression.new(parts[1]) if parts.size > 1
  end

  def to_s
    if @has_step_value
      "#{@keyword} #{@control_variable} = #{@start_value} TO #{@end_value} STEP #{@step_value}"
    else
      "#{@keyword} #{@control_variable} = #{@start_value} TO #{@end_value}"
    end
  end

  def execute_cmd(interpreter, _)
    loop_end_number = interpreter.find_closing_next(@control_variable.name)
    from_value = @start_value.evaluate(interpreter)[0]
    interpreter.set_value(@control_variable, from_value)
    to_value = @end_value.evaluate(interpreter)[0]
    step_value = @step_value.evaluate(interpreter)[0]
    fornext_control =
      ForNextControl.new(@control_variable, interpreter.next_line_number,
                         from_value, to_value, step_value)
    interpreter.assign_fornext(fornext_control)
    interpreter.next_line_number = loop_end_number if
      fornext_control.front_terminated?
  end
end

# NEXT
class NextStatement < AbstractStatement
  def initialize(line, squeezed)
    super('NEXT', line, squeezed)
    # parse control variable
    @control_variable = nil
    begin
      var_name = VariableName.new(@rest)
      @control_variable = ScalarValue.new(var_name)
    rescue BASICException => e
      @errors << e.message
    end
  end

  def to_s
    @keyword + ' ' + @control_variable.to_s
  end

  def control_variable
    @control_variable.name
  end

  def execute_cmd(interpreter, _)
    fornext_control = interpreter.retrieve_fornext(@control_variable)
    # check control variable value
    # if matches end value, stop here
    return if fornext_control.terminated?(interpreter)
    # set next line from top item
    interpreter.next_line_number = fornext_control.loop_start_number
    # change control variable value
    fornext_control.bump_control_variable(interpreter)
  end
end

# READ
class ReadStatement < AbstractStatement
  def initialize(line, squeezed)
    super('READ', line, squeezed)
    item_list = split_args(@rest, false)
    # variable [comma, variable]...
    @expression_list = []
    item_list.each do |item|
      begin
        @expression_list << TargetScalarExpression.new(item)
      rescue BASICException
        @errors << "Invalid variable #{text_item}"
      end
    end
  end

  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end

  def execute_cmd(interpreter, trace)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      value = interpreter.read_data
      interpreter.set_value(variable, value)
      printer = interpreter.print_handler
      printer.trace_output(' ' + variable.to_s + ' = ' + value.to_s) if trace
    end
  end
end

# DATA
class DataStatement < AbstractStatement
  def initialize(line, squeezed)
    super('DATA', line, squeezed)
    @data_list = textline_to_constants(@rest)
  end

  def to_s
    @keyword + ' ' + @data_list.join(', ')
  end

  def pre_execute(interpreter)
    interpreter.store_data(@data_list)
  end

  def execute_cmd(_, _)
    0
  end
end

# RESTORE
class RestoreStatement < AbstractStatement
  def initialize(line, squeezed)
    super('RESTORE', line, squeezed)
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter, _)
    interpreter.reset_data
  end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def initialize(line, squeezed)
    super('DEF', line, squeezed)
    @name = ''
    @arguments = []
    @template = ''
    begin
      user_function_definition = UserFunctionDefinition.new(@rest)
      @name = user_function_definition.name
      @arguments = user_function_definition.arguments
      @template = user_function_definition.template
    rescue BASICException => e
      puts e.message
      @errors << e.message
    end
  end

  def to_s
    @keyword + ' ' + @name + "(#{@arguments.join(',')}) = " + @template.to_s
  end

  def pre_execute(interpreter)
    interpreter.set_user_function(@name, @arguments, @template)
  end

  def execute_cmd(_, _)
  end
end

# STOP
class StopStatement < AbstractStatement
  def initialize(line, squeezed)
    super('STOP', line, squeezed)
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
    printer.newline_when_needed
    interpreter.stop
  end
end

# END
class EndStatement < AbstractStatement
  def initialize(line, squeezed)
    super('END', line, squeezed)
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
    printer.newline_when_needed
    interpreter.stop
  end
end

# TRACE
class TraceStatement < AbstractStatement
  def initialize(line, squeezed)
    super('TRACE', line, squeezed)
    @operation = BooleanConstant.new(@rest)
  end

  def execute_cmd(interpreter, _)
    interpreter.trace(@operation.value)
  end

  def to_s
    @keyword + ' ' + (@operation.value ? 'ON' : 'OFF')
  end
end

# MAT PRINT
class MatPrintStatement < AbstractPrintStatement
  def initialize(line, squeezed)
    super('MAT PRINT', line, squeezed)
    item_list = split_args(@rest, true)

    print_item_list = []
    previous_item = CarriageControl.new('')
    item_list.each do |print_item|
      if print_item == ',' || print_item == ';'
        # the item is a carriage control item
        # save previous print thing, or create an empty one
        item = CarriageControl.new(print_item)
        print_item_list << item
      else
        # insert a plain carriage control
        item = CarriageControl.new('')
        print_item_list << item if previous_item.printable?
        begin
          item = MatrixPrintableExpression.new(print_item.strip)
          print_item_list << item
        rescue BASICException => e
          @errors << "Invalid print item '#{print_item}': #{e.message}"
        end
      end
      previous_item = item
    end

    # add implied items at end of list
    print_item_list << MatrixPrintableExpression.new(nil) if
      print_item_list.size == 0
    print_item_list << CarriageControl.new(',') if
      print_item_list[-1].class.to_s != 'CarriageControl'

    # convert to pairs
    @print_item_pairs = print_item_list.each_slice(2).to_a
  end
end

# MAT READ
class MatReadStatement < AbstractStatement
  def initialize(line, squeezed)
    super('MAT READ', line, squeezed)
    item_list = split_args(@rest, false)
    # variable [comma, variable]...
    @expression_list = []
    item_list.each do |item|
      begin
        expression = TargetMatrixExpression.new(item)
        @expression_list << expression
      rescue BASICException
        @errors << "Invalid variable #{text_item}"
      end
    end
  end

  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end

  def execute_cmd(interpreter, trace)
    @expression_list.each do |expression|
      targets = expression.evaluate(interpreter)
      targets.each do |target|
        name = target.name
        interpreter.set_dimensions(name, target.dimensions) if
          target.dimensions?
        read_values(name, interpreter, trace)
      end
    end
  end

  private

  def read_values(name, interpreter, trace)
    dims = interpreter.get_dimensions(name)
    fail(BASICException, 'Dimensions for MAT READ must be 1 or 2') unless
      [1, 2].include?(dims.size)
    read_vector(name, dims[0].to_i, interpreter, trace) if dims.size == 1
    read_matrix(name, dims[0].to_i, dims[1].to_i, interpreter, trace) if
      dims.size == 2
  end

  def read_vector(name, n_cols, interpreter, trace)
    (1..n_cols).each do |col|
      value = interpreter.read_data
      variable = name.to_s + make_coord(col)
      printer.print_out(' ' + variable.to_s + ' = ' + value.to_s) if trace
      interpreter.set_value(variable, value)
    end
  end

  def read_matrix(name, n_rows, n_cols, interpreter, trace)
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = interpreter.read_data
        variable = name.to_s + make_coords(row, col)
        printer.print_out(' ' + variable.to_s + ' = ' + value.to_s) if trace
        interpreter.set_value(variable, value)
      end
    end
  end
end

# MAT assignment
class MatLetStatement < AbstractStatement
  def initialize(line, squeezed)
    super('MAT', line, squeezed)
    begin
      @assignment = MatrixAssignment.new(@rest)
      if @assignment.count_target != 1
        @errors << 'Assignment must have only one left-hand value'
      end
      if @assignment.count_value != 1
        @errors << 'Assignment must have only one right-hand value'
      end
    rescue BASICException => e
      @errors << e.message
      @assignment = @rest
    end
  end

  def to_s
    @keyword + ' ' + @assignment.to_s
  end

  def execute_cmd(interpreter, trace)
    l_value = first_target(interpreter)
    name = l_value.name
    r_value = first_value(interpreter)
    dims = r_value.dimensions
    interpreter.set_dimensions(name, dims)
    assign_vector(name, r_value, interpreter, trace) if dims.size == 1
    assign_matrix(name, r_value, interpreter, trace) if dims.size == 2
  end

  private

  def first_target(interpreter)
    l_values = @assignment.eval_target(interpreter)
    l_values[0]
  end

  def first_value(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    fail(BASICException, 'Expected Matrix') if r_value.class.to_s != 'Matrix'
    r_value
  end

  def assign_vector(name, vector, interpreter, trace)
    printer = interpreter.print_handler
    dims = vector.dimensions
    n_cols = dims[0].to_i
    (1..n_cols).each do |col|
      value = vector.get_value_1(col)
      variable = name.to_s + make_coord(col)
      printer.print_out(' ' + variable.to_s + ' = ' + value.to_s) if trace
      interpreter.set_value(variable, value)
    end
  end

  def assign_matrix(name, matrix, interpreter, trace)
    printer = interpreter.print_handler
    dims = matrix.dimensions
    n_rows = dims[0].to_i
    n_cols = dims[1].to_i
    (1..n_rows).each do |row|
      (1..n_cols).each do |col|
        value = matrix.get_value_2(row, col)
        variable = name.to_s + make_coords(row, col)
        printer.trace_output(' ' + variable.to_s + ' = ' + value.to_s) if trace
        interpreter.set_value(variable, value)
      end
    end
  end
end

# Carriage control for PRINT and MAT PRINT statements
class CarriageControl
  def initialize(text)
    valid_operators = ['NL', ',', ';', '']
    fail(BASICException, "'#{text}' is not a valid separator") unless
      valid_operators.include?(text)
    @operator = text
  end

  def printable?
    false
  end

  def to_s
    case @operator
    when ';'
      ';'
    when ','
      ','
    when 'NL'
      ''
    when ''
      ''
    end
  end

  def print(printer, _)
    case @operator
    when ','
      printer.tab
    when ';'
      printer.semicolon
    when 'NL'
      printer.newline
    when ''
      # do nothing
    end
  end
end
