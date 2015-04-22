class AbstractStatement
  def initialize(keyword)
    @keyword = keyword
    @errors = Array.new
  end
  
  def errors
    @errors
  end

  def pre_execute(interpreter)
    0
  end
  
  def execute(interpreter)
    if (@errors.size == 0) then
      execute_cmd(interpreter)
    else
      @errors.each { | error | puts "line #{interpreter.current_line_number}: #{error}" }
    end
  end
end

class UnknownStatement < AbstractStatement
  def initialize(line)
    super('')
    @line = line
    @errors << "Unknown command #{@line}"
  end
  
  def to_s
    @line
  end
  
  def execute_cmd(interpreter)
    0
  end
end

class RemarkStatement < AbstractStatement
  def initialize(line)
    super('REM')
    @contents = line
  end
  
  def to_s
    @keyword + @contents
  end

  def execute_cmd(interpreter)
    0
  end
end

class LetStatement < AbstractStatement
  def initialize(line)
    super('LET')
    begin
      @assignment = Assignment.new(line.gsub(/ /, ''))
      if @assignment.count_target != 1 then
        @errors << 'Assignment must have only one left-hand value'
      end
      if @assignment.count_value != 1 then
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
    # diagnostics
    ## @expression.dump
    ## puts
    # end diagnostics
    l_values = @assignment.eval_target(interpreter)
    r_values = @assignment.eval_value(interpreter)
    interpreter.set_value(l_values, r_values)
  end
end

class InputStatement < AbstractStatement
  def initialize(line)
    super('INPUT')
    @default_prompt = TextConstant.new('"? "')
    @prompt = @default_prompt
    # todo: allow text prompt (default to ?)
    text_list = split_args(line.gsub(/^ +/, ''), false)
    if text_list.length > 0 then
      begin
        @prompt = TextConstant.new(text_list[0])
        text_list.delete_at(0)
      rescue BASICException
      end
      # variable [comma, variable]...
      @expression_list = Array.new
      text_list.each do | text_item |
        begin
          @expression_list << TargetExpression.new(text_item)
        rescue BASICException
          @errors << "Invalid variable #{text_item}"
        end
      end
    else
      @errors << "No variables specified"
    end
  end
  
  def to_s
    @keyword + ' ' + (@prompt != @default_prompt ? @prompt.to_s + ', ' : '') + @expression_list.join(', ')
  end
  
  private
  def zip(names, values)
    raise(BASICException, "Unequal lists", caller) if names.size != values.size
    results = Array.new
    (0...names.size).each do | i |
      results << { 'name' => names[i], 'value' => values[i] }
    end    
    results
  end
  
  public
  def execute_cmd(interpreter)
    printer = interpreter.print_handler
    values = Array.new
    prompt = @prompt
    while values.size < @expression_list.size do
      print prompt.value
      input_line = gets
      input_line.chomp!
      text_values = input_line.split(/,/)
      text_values.each do | value |
        begin
          var_value = NumericConstant.new(value)
          values << var_value.evaluate(interpreter, nil)
        rescue BASICException
          raise BASICException, "Invalid value #{value}", caller
        end
      end
      prompt = @default_prompt
    end
    name_value_pairs = zip(@expression_list, values)
    name_value_pairs.each do | hash |
      interpreter.set_value(hash['name'].evaluate(interpreter), hash['value'])
    end
    printer.implied_newline
  end
end

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
    interpreter.set_next_line(@destination.to_i) if @boolean_expression.evaluate(interpreter)
  end
end

class PrintStatement < AbstractStatement
  public
  def initialize(line)
    super('PRINT')
    item_list = split_args(line.sub(/^ +/, ''), true)
    # variable/constant, [separator, variable/constant]... [separator]
    @print_item_list = Array.new
    print_thing = nil
    item_list.each do | print_item |
      if print_item == ',' or print_item == ';' then
        # the item is a carriage control item
        # save previous print thing, or create an empty one
        print_thing = PrintableExpression.new('""') if print_thing == nil
        @print_item_list << { 'variable' => print_thing, 'carriage' => print_item }
        print_thing = nil
      else
        begin
          # store previous print thing
          if print_thing != nil then
            @print_item_list << { 'variable' => print_thing, 'carriage' => '' }
          end
          # remove leading and trailing blanks
          print_item.sub!(/^ +/, '')
          print_item.sub!(/ +$/, '')
          print_thing = PrintableExpression.new(print_item)
        rescue BASICException => e
          @errors << "Invalid print item '#{print_item}': #{e.message}"
        end
      end
    end
    @print_item_list << { 'variable' => print_thing, 'carriage' => 'NL' } if not print_thing.nil?
    @print_item_list << { 'variable' => PrintableExpression.new('""'), 'carriage' => 'NL' } if @print_item_list.empty?
  end
  
  def to_s
    varnames = Array.new
    @print_item_list.each { | print_item | varnames << print_item['variable'] }
    @keyword + ' ' + varnames.join(', ')
  end
  
  def execute_cmd(interpreter)
    printer = interpreter.print_handler
    @print_item_list.each do | print_item |

      name = print_item['variable']
      if not name.nil?
        v = name.to_formatted_s(interpreter)
        printer.print_item v
      end

      separator = print_item['carriage']
      case separator
      when ';'
        printer.halftab
      when ','
        printer.tab
      when 'NL'
        printer.newline
      end

    end
  end
end

class GotoStatement < AbstractStatement
  def initialize(line)
    super('GO TO')
    destination = line.sub(/ /, '')
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
    next_line_number = @destination.to_i
    interpreter.set_next_line(next_line_number)
  end
end

class GosubStatement < AbstractStatement
  def initialize(line)
    super('GOSUB')
    destination = line.sub(/ /, '')
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
    next_line_number = @destination.to_i
    interpreter.set_next_line(next_line_number)
  end
end

class ReturnStatement < AbstractStatement
  def initialize
    super('RETURN')
  end
  
  def to_s
    @keyword
  end
  
  def execute_cmd(interpreter)
    interpreter.set_next_line(interpreter.pop_return)
  end
end

class ForNextControl
  def initialize(control_variable, loop_start_number, start_value, end_value, step_value)
    if start_value.class.to_s != 'Fixnum' and start_value.class.to_s != 'Float' then
      raise Exception, "Invalid start value #{start_value} #{start_value.class}", caller
    end
    if end_value.class.to_s != 'Fixnum' and end_value.class.to_s != 'Float' then
      raise Exception, "Invalid end value #{end_value} #{end_value.class}", caller
    end
    if step_value.class.to_s != 'Fixnum' and step_value.class.to_s != 'Float' then
      raise Exception, "Invalid step value #{step_value} #{step_value.class}", caller
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
  
  def control_variable
    @control_variable
  end
  
  def end_value
    @end_value
  end
  
  def loop_start_number
    @loop_start_number
  end
  
  def terminated?(interpreter)
    current_value = interpreter.get_value(@control_variable).to_v
    if @step_value > 0 then (current_value + @step_value > @end_value)
    elsif @step_value < 0 then (current_value + @step_value < @end_value)
    else true
    end
  end
end

class ForStatement < AbstractStatement
  def initialize(line)
    super('FOR')
    # parse control variable, "=", numeric_expression, "TO", numeric_expression, "STEP", numeric_expression
    parts = line.gsub(/ /, '').split('=', 2)
    raise(BASICException, "Syntax error", caller) if parts.size != 2
    begin
      var_name = VariableName.new(parts[0])
      @control_variable = VariableValue.new(var_name)
    rescue BASICException => message
      @errors << message
    end
    parts = parts[1].split('TO', 2)
    raise(BASICException, "Syntax error", caller) if parts.size != 2
    @start_value = ValueExpression.new(parts[0])
    parts = parts[1].split('STEP', 2)
    @end_value = ValueExpression.new(parts[0])
    if parts.size > 1 then
      @has_step_value = true
      @step_value = ValueExpression.new(parts[1])
    else
      @has_step_value = false
      @step_value = ValueExpression.new('1')
    end
  end
  
  def to_s
    if @has_step_value then
      @keyword + ' ' + @control_variable.to_s + ' = ' + @start_value.to_s + ' TO ' + @end_value.to_s + ' STEP ' + @step_value.to_s
    else
      @keyword + ' ' + @control_variable.to_s + ' = ' + @start_value.to_s + ' TO ' + @end_value.to_s
    end
  end
  
  def execute_cmd(interpreter)
    from_value = @start_value.evaluate(interpreter).to_v
    interpreter.set_value(@control_variable, from_value)
    to_value = @end_value.evaluate(interpreter).to_v
    step_value = @step_value.evaluate(interpreter).to_v
    fornext_control = ForNextControl.new(@control_variable, interpreter.get_next_line, from_value, to_value, step_value)
    interpreter.set_fornext(fornext_control)
  end
end

class NextStatement < AbstractStatement
  def initialize(line)
    super('NEXT')
    # parse control variable
    @control_variable = nil
    begin
      var_name = VariableName.new(line.gsub(/ /, ''))
      @control_variable = VariableValue.new(var_name)
    rescue BASICException => message
      @errors << message
      @boolean_expression = line
    end
  end
  
  def to_s
    @keyword + ' ' + @control_variable.to_s
  end
  
  def execute_cmd(interpreter)
    fornext_control = interpreter.get_fornext(@control_variable)
    # check control variable value
    # if matches end value, stop here
    return if fornext_control.terminated?(interpreter)
    # set next line from top item
    interpreter.set_next_line(fornext_control.loop_start_number)
    # change control variable value
    fornext_control.bump_control_variable(interpreter)
    interpreter.set_fornext(fornext_control)
  end
end

class ReadStatement < AbstractStatement
  def initialize(line)
    super('READ')
    text_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @expression_list = Array.new
    text_list.each do | text_item |
      begin
        @expression_list << TargetExpression.new(text_item)
      rescue BASICException
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end
  
  def execute_cmd(interpreter)
    @expression_list.each do | expression |
      variable = expression.evaluate(interpreter)
      interpreter.set_value(variable, interpreter.read_data)
    end
  end
end

class DataStatement < AbstractStatement
  def initialize(line)
    super('DATA')
    @data_list = line.gsub(/ /, '').split(',')
    # number [comma, number]...
    @data_list.each do | text_item |
      begin
        NumericConstant.new(text_item)
      rescue BASICException
        @errors << "Invalid value #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @data_list.join(', ')
  end

  def pre_execute(interpreter)
    @data_list.each do | text_item |
      x = NumericConstant.new(text_item)
      interpreter.store_data(x)
    end
  end
  
  def execute_cmd(interpreter)
    0
  end
end

class StopStatement < AbstractStatement
  def initialize
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

class EndStatement < AbstractStatement
  def initialize
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

