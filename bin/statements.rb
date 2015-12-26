# parent of all statement classes
class AbstractStatement
  attr_reader :errors

  def initialize(keyword)
    @keyword = keyword
    @errors = []
  end

  def pre_execute(_)
    0
  end

  def execute(interpreter)
    if @errors.size == 0
      execute_cmd(interpreter)
    else
      @errors.each do |error|
        puts "line #{interpreter.current_line_number}: #{error}"
      end
    end
  end
end

# unknown statement
class UnknownStatement < AbstractStatement
  def initialize(line)
    super('')
    @line = line
    @errors << "Unknown command #{@line}"
  end

  def to_s
    @line
  end

  def execute_cmd(_)
    0
  end
end

# empty statement (line number only)
class EmptyStatement < AbstractStatement
  def initialize
    super('')
  end

  def to_s
    ''
  end

  def execute_cmd(_)
    0
  end
end

# REMARK
class RemarkStatement < AbstractStatement
  def initialize(line)
    super('REM')
    @contents = line
  end

  def to_s
    @keyword + @contents
  end

  def execute_cmd(_)
    0
  end
end

# DIM
class DimStatement < AbstractStatement
  def initialize(line)
    super('DIM')
    text_list = split_args(line.strip, false)
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

  def execute_cmd(interpreter)
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
  def initialize(line)
    super('LET')
    begin
      @assignment = Assignment.new(line.gsub(/ /, ''))
      if @assignment.count_target != 1
        @errors << 'Assignment must have only one left-hand value'
      end
      if @assignment.count_value != 1
        @errors << 'Assignment must have only one right-hand value'
      end
    rescue BASICException => message
      @errors << message
      @assignment = line
    end
  end

  def to_s
    @keyword + ' ' + @assignment.to_s
  end

  def execute_cmd(interpreter)
    l_values = @assignment.eval_target(interpreter)
    l_value = l_values[0]
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    interpreter.set_value(l_value, r_value)
  end
end

# INPUT
class InputStatement < AbstractStatement
  def initialize(line)
    super('INPUT')
    @default_prompt = TextConstant.new('"? "')
    @prompt = @default_prompt
    text_list = split_args(line.strip, false)
    if text_list.length > 0
      begin
        @prompt = TextConstant.new(text_list[0])
        text_list.delete_at(0)
      rescue BASICException
        # if the first item wasn't a text constant,
        # don't create a prompt and use it as data
      end
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

  def execute_cmd(interpreter)
    printer = interpreter.print_handler
    values = input_values
    name_value_pairs =
      zip(@expression_list, values[0, @expression_list.length])
    name_value_pairs.each do |hash|
      l_values = hash['name'].evaluate(interpreter)
      interpreter.set_value(l_values[0], hash['value'])
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
  def initialize(line)
    super('IF')
    parts = line.gsub(/ /, '').split(/\s*THEN\s*/)
    begin
      @boolean_expression = BooleanExpression.new(parts[0])
    rescue BASICException => message
      @errors << message
      @boolean_expression = parts[0]
    end
    @destination = LineNumber.new(parts[1])
  end

  def to_s
    @keyword + ' ' + @boolean_expression.to_s + ' THEN ' + @destination.to_s
  end

  def execute_cmd(interpreter)
    interpreter.set_next_line(@destination) if
      @boolean_expression.evaluate(interpreter)
  end
end

# Common for PRINT and MAT PRINT
class AbstractPrintStatement < AbstractStatement
  def initialize(line)
    super
  end

  def to_s
    varnames = []
    @print_item_pairs.each do |print_pair|
      varnames << print_pair[0].to_s + print_pair[1].to_s
    end
    @keyword + ' ' + varnames.join(' ')
  end

  def execute_cmd(interpreter)
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
  def initialize(line)
    super('PRINT')
    item_list = split_args(line.strip, true)
    # variable/constant, [separator, variable/constant]... [separator]
    print_item_list = []
    last_was_variable = false
    item_list.each do |print_item|
      if print_item == ',' || print_item == ';'
        # the item is a carriage control item
        # save previous print thing, or create an empty one
        print_item_list << CarriageControl.new(print_item)
        last_was_variable = false
      else
        # insert a plain carriage control
        print_item_list << CarriageControl.new('') if last_was_variable
        begin
          # remove leading and trailing blanks
          print_item_list << PrintableExpression.new(print_item.strip)
          last_was_variable = true
        rescue BASICException => e
          @errors << "Invalid print item '#{print_item}': #{e.message}"
        end
      end
    end
    print_item_list << PrintableExpression.new('""') if
      print_item_list.size == 0
    print_item_list << CarriageControl.new('NL') if
      print_item_list[-1].class.to_s != 'CarriageControl'
    @print_item_pairs = print_item_list.each_slice(2).to_a
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def initialize(line)
    super('GOTO')
    destination = line
    begin
      @destination = LineNumber.new(destination)
    rescue BASICException
      @errors << "Invalid line number #{destination}"
    end
  end

  def to_s
    @keyword + ' ' + @destination.to_s
  end

  def execute_cmd(interpreter)
    interpreter.set_next_line(@destination)
  end
end

# GOSUB
class GosubStatement < AbstractStatement
  def initialize(line)
    super('GOSUB')
    destination = line
    begin
      @destination = LineNumber.new(destination)
    rescue BASICException
      @errors << "Invalid line number #{destination}"
    end
  end

  def to_s
    @keyword + ' ' + @destination.to_s
  end

  def execute_cmd(interpreter)
    interpreter.push_return(interpreter.get_next_line)
    interpreter.set_next_line(@destination)
  end
end

# RETURN
class ReturnStatement < AbstractStatement
  def initialize(_)
    super('RETURN')
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter)
    interpreter.set_next_line(interpreter.pop_return)
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
    @current_value =
      NumericConstant.new(@current_value.to_v + @step_value.to_v)
    interpreter.set_value(@control_variable, @current_value)
  end

  def front_terminated?(_)
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

# FOR
class ForStatement < AbstractStatement
  def initialize(line)
    super('FOR')
    # parse control variable, '=', numeric_expression, "TO",
    # numeric_expression, "STEP", numeric_expression
    parts = line.gsub(/ /, '').split('=', 2)
    fail(BASICException, 'Syntax error') if parts.size != 2
    begin
      var_name = VariableName.new(parts[0])
      @control_variable = ScalarValue.new(var_name)
    rescue BASICException => message
      @errors << message
    end
    parts = parts[1].split('TO', 2)
    fail(BASICException, 'Syntax error') if parts.size != 2
    @start_value = ValueScalarExpression.new(parts[0])
    parts = parts[1].split('STEP', 2)
    @end_value = ValueScalarExpression.new(parts[0])
    if parts.size > 1
      @has_step_value = true
      @step_value = ValueScalarExpression.new(parts[1])
    else
      @has_step_value = false
      @step_value = ValueScalarExpression.new('1')
    end
  end

  def to_s
    if @has_step_value
      "#{@keyword} #{@control_variable} = #{@start_value} TO #{@end_value} STEP #{@step_value}"
    else
      "#{@keyword} #{@control_variable} = #{@start_value} TO #{@end_value}"
    end
  end

  def execute_cmd(interpreter)
    loop_end_number = interpreter.find_closing_next(@control_variable.name)
    from_value = @start_value.evaluate(interpreter)[0]
    interpreter.set_value(@control_variable, from_value)
    to_value = @end_value.evaluate(interpreter)[0]
    step_value = @step_value.evaluate(interpreter)[0]
    fornext_control =
      ForNextControl.new(@control_variable, interpreter.get_next_line,
                         from_value, to_value, step_value)
    interpreter.assign_fornext(fornext_control)
    interpreter.set_next_line(loop_end_number) if
      fornext_control.front_terminated?(interpreter)
  end
end

# NEXT
class NextStatement < AbstractStatement
  def initialize(line)
    super('NEXT')
    # parse control variable
    @control_variable = nil
    begin
      var_name = VariableName.new(line.gsub(/ /, ''))
      @control_variable = ScalarValue.new(var_name)
    rescue BASICException => message
      @errors << message
      @boolean_expression = line
    end
  end

  def to_s
    @keyword + ' ' + @control_variable.to_s
  end

  def control_variable
    @control_variable.name
  end

  def execute_cmd(interpreter)
    fornext_control = interpreter.retrieve_fornext(@control_variable)
    # check control variable value
    # if matches end value, stop here
    return if fornext_control.terminated?(interpreter)
    # set next line from top item
    interpreter.set_next_line(fornext_control.loop_start_number)
    # change control variable value
    fornext_control.bump_control_variable(interpreter)
  end
end

# READ
class ReadStatement < AbstractStatement
  def initialize(line)
    super('READ')
    item_list = split_args(line.strip, false)
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

  def execute_cmd(interpreter)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      interpreter.set_value(variable, interpreter.read_data)
    end
  end
end

# DATA
class DataStatement < AbstractStatement
  def initialize(line)
    super('DATA')
    @data_list = textline_to_constants(line)
  end

  def to_s
    @keyword + ' ' + @data_list.join(', ')
  end

  def pre_execute(interpreter)
    interpreter.store_data(@data_list)
  end

  def execute_cmd(_)
    0
  end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def initialize(line)
    super('DEF')
    begin
      user_function_definition = UserFunctionDefinition.new(line.gsub(/ /, ''))
    rescue BASICException => message
      puts message
      @errors << message
      @assignment = line
    end
    @name = user_function_definition.name
    @arguments = user_function_definition.arguments
    @template = user_function_definition.template
  end

  def to_s
    @keyword + ' ' + @name + "(#{@arguments.join(', ')}) = " + @template.to_s
  end

  def pre_execute(interpreter)
    interpreter.set_user_function(@name, @arguments, @template)
  end

  def execute_cmd(_)
  end
end

# STOP
class StopStatement < AbstractStatement
  def initialize(_)
    super('STOP')
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter)
    printer = interpreter.print_handler
    printer.newline_when_needed
    interpreter.stop
  end
end

# END
class EndStatement < AbstractStatement
  def initialize(_)
    super('END')
  end

  def to_s
    @keyword
  end

  def execute_cmd(interpreter)
    printer = interpreter.print_handler
    printer.newline_when_needed
    interpreter.stop
  end
end

# TRACE
class TraceStatement < AbstractStatement
  def initialize(line)
    super('TRACE')
    @operation = BooleanConstant.new(line.gsub(/ /, ''))
  end

  def execute_cmd(interpreter)
    interpreter.trace(@operation.value)
  end

  def to_s
    @keyword + ' ' + (@operation.value ? 'ON' : 'OFF')
  end
end

# MAT PRINT
class MatPrintStatement < AbstractPrintStatement
  def initialize(line)
    super('MAT PRINT')
    item_list = split_args(line.strip, true)
    # variable/constant, [separator, variable/constant]... [separator]
    print_item_list_1 = ctor_print_item_list_1(item_list)
    print_item_list_2 = ctor_print_item_list_2(print_item_list_1)
    @print_item_pairs = print_item_list_2.each_slice(2).to_a
  end

  private

  def ctor_print_item_list_1(item_list)
    print_item_list = []
    item_list.each do |print_item|
      if print_item == ',' || print_item == ';'
        # the item is a carriage control item
        print_item_list << CarriageControl.new(print_item)
      else
        begin
          print_item_list << ValueMatrixExpression.new(print_item.strip)
        rescue BASICException => e
          @errors << "Invalid print item '#{print_item}': #{e.message}"
        end
      end
    end
    print_item_list
  end

  def ctor_print_item_list_2(item_list)
    last_was_var = false
    print_item_list = []
    # build list of print things and carriage control things
    # one of each, alternating
    item_list.each do |print_item|
      this_is_var = print_item.class.to_s == 'ValueMatrixExpression'
      if last_was_var
        # insert a plain carriage control
        print_item_list << CarriageControl.new(',') if this_is_var
        print_item_list << print_item
      else
        print_item_list << print_item if this_is_var
      end
      last_was_var = this_is_var
    end
    print_item_list << CarriageControl.new(',') if
      print_item_list.size == 0 ||
      print_item_list[-1].class.to_s != 'CarriageControl'
    print_item_list
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
