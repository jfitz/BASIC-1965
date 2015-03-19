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
      @expression = Assignment.new(line.gsub(/ /, ''))
    rescue BASICException => message
      @errors << message
      @expression = line
    end
  end
  
  def to_s
    @keyword + ' ' + @expression.to_s
  end
  
  def execute_cmd(interpreter)
    # diagnostics
    # @expression.dump
    # puts
    # end diagnostics
    interpreter.set_value(@expression.target, @expression.value(interpreter))
  end
end

class InputStatement < AbstractStatement
  def initialize(line)
    super('INPUT')
    # todo: allow subscripted variables
    # todo: allow text prompt (?)
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      begin
        var_name = VariableValue.new(text_item)
      rescue BASICException
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
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
    values = Array.new
    while values.size < @variable_list.size do
      print '?'
      input_line = gets
      input_line.chomp!
      text_values = input_line.split(/,/)
      text_values.each do | value |
        begin
          var_value = NumericConstant.new(value)
          values << var_value.evaluate(interpreter)
        rescue BASICException
          raise BASICException, "Invalid value #{value}", caller
        end
      end
    end
    name_value_pairs = zip(@variable_list, values)
    name_value_pairs.each do | hash |
      interpreter.set_value(hash['name'], hash['value'])
    end
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
  private
  def split_args(text)
    args = Array.new
    current_arg = String.new
    in_string = false
    (0..text.size-1).each do | i |
      c = text[i,1]
      if [',', ';'].include?(c) and not in_string then
        args << current_arg
        current_arg = String.new
        args << c
      else
        current_arg += c
      end
      in_string = !in_string if ['"'].include?(c)
    end
    args << current_arg if current_arg.size > 0
    args
  end
  
  public
  def initialize(line)
    super('PRINT')
    item_list = split_args(line.sub(/^ +/, ''))
    # variable/constant, [separator, variable/constant]... [separator]
    @print_item_list = Array.new
    var_name = nil
    item_list.each do | print_item |
      if print_item == ',' or print_item == ';' then
        @print_item_list << { 'variable' => var_name, 'carriage' => print_item }
        var_name = nil
      else
        begin
          print_item.sub!(/^ +/, '')
          print_item.sub!(/ +$/, '')
          var_name = PrintableExpression.new(print_item)
        rescue BASICException
          @errors << "Invalid expression #{print_item} class: #{print_item.class}"
        end
      end
    end
    @print_item_list << { 'variable' => var_name, 'carriage' => '' } if not var_name.nil?
    @print_item_list << { 'variable' => var_name, 'carriage' => '' } if @print_item_list.empty?
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
        printer.null
      when ','
        printer.tab
      else
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
  def initialize(control_variable_name, loop_start_number, start_value, end_value, step_value)
    if start_value.class.to_s != 'Fixnum' and start_value.class.to_s != 'Float' then
      raise Exception, "Invalid start value #{start_value} #{start_value.class}", caller
    end
    if end_value.class.to_s != 'Fixnum' and end_value.class.to_s != 'Float' then
      raise Exception, "Invalid end value #{end_value} #{end_value.class}", caller
    end
    if step_value.class.to_s != 'Fixnum' and step_value.class.to_s != 'Float' then
      raise Exception, "Invalid step value #{step_value} #{step_value.class}", caller
    end
    @control_variable_name = control_variable_name
    @loop_start_number = loop_start_number
    @start_value = start_value
    @end_value = end_value
    @step_value = step_value
    @current_value = start_value
  end
  
  def bump_control_variable(interpreter)
    @current_value = @current_value + @step_value
    interpreter.set_value(@control_variable_name, @current_value)
  end
  
  def control_variable_name
    @control_variable_name
  end
  
  def end_value
    @end_value
  end
  
  def loop_start_number
    @loop_start_number
  end
  
  def terminated?(interpreter)
    current_value = interpreter.get_value(@control_variable_name).to_v
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
      @control_variable = VariableValue.new(parts[0])
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
    fornext_control = ForNextControl.new(@control_variable.to_s, interpreter.get_next_line, from_value, to_value, step_value)
    interpreter.set_fornext(fornext_control)
  end
end

class NextStatement < AbstractStatement
  def initialize(line)
    super('NEXT')
    # parse control variable
    @control_variable = nil
    begin
      @control_variable = VariableValue.new(line.gsub(/ /, ''))
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
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      begin
        var_name = VariableValue.new(text_item)
      rescue BASICException
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  def execute_cmd(interpreter)
    @variable_list.each do | text_item |
      var_name = VariableValue.new(text_item)
      interpreter.set_value(var_name, interpreter.read_data)
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
      interpreter.store_data(x.evaluate(interpreter))
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
    interpreter.stop
  end
end

