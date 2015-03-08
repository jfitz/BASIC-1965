#!/usr/bin/ruby

require 'BASICException'
require 'Constants'
require 'Operators'
require 'Expressions'

$randomizer = Random.new

class LineNumber
  def initialize(number)
    regex = Regexp.new('^\d+$')
    raise(BASICException, "'#{number}' is not a line number", caller) if regex !~ number
    @line_number = number.to_i
  end
  
  def to_i
    @line_number
  end
  
  def to_s
    @line_number.to_s
  end
end

class PrintHandler
  def initialize
    @column = 0
  end
  
  def print_item(text)
    print text
    @column += text.size
  end
  
  def tab
    new_column = ((@column / 14) + 1) * 14
    (new_column - @column).times { | i | print ' ' }
    @column = new_column
  end
  
  def newline
    print "\n"
    @column = 0
  end
  
  def null
  end
end

class AbstractLine
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

class Unknown < AbstractLine
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

class Remark < AbstractLine
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

class Let < AbstractLine
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

class Input < AbstractLine
  def initialize(line)
    super('INPUT')
    # todo: allow subscripted variables
    # todo: allow text prompt (?)
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      begin
        var_name = VariableRef.new(text_item)
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

class If < AbstractLine
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

class Print < AbstractLine
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
          @errors << "Invalid expression #{print_item}"
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
      printer.print_item name.to_formatted_s(interpreter) if not name.nil?
      separator = print_item['carriage']
      case separator
      when ';'
        printer.null
      when ','
        printer.tab
      else printer.newline
      end
    end
  end
end

class Goto < AbstractLine
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

class Gosub < AbstractLine
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

class Return < AbstractLine
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
    current_value = interpreter.get_value(@control_variable_name)
    if @step_value > 0 then (current_value + @step_value > end_value)
    elsif @step_value < 0 then (current_value + @step_value < end_value)
    else true
    end
  end
end

class ForLine < AbstractLine
  def initialize(line)
    super('FOR')
    # parse control variable, "=", numeric_expression, "TO", numeric_expression, "STEP", numeric_expression
    parts = line.gsub(/ /, '').split('=', 2)
    raise(BASICException, "Syntax error", caller) if parts.size != 2
    begin
      @control_variable = VariableRef.new(parts[0])
    rescue BASICException => message
      @errors << message
    end
    parts = parts[1].split('TO', 2)
    raise(BASICException, "Syntax error", caller) if parts.size != 2
    @start_value = ArithmeticExpression.new(parts[0])
    parts = parts[1].split('STEP', 2)
    @end_value = ArithmeticExpression.new(parts[0])
    if parts.size > 1 then
      @has_step_value = true
      @step_value = ArithmeticExpression.new(parts[1])
    else
      @has_step_value = false
      @step_value = NumericConstant.new(1)
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
    from_value = @start_value.evaluate(interpreter)
    interpreter.set_value(@control_variable, from_value)
    to_value = @end_value.evaluate(interpreter)
    step_value = @step_value.evaluate(interpreter)
    fornext_control = ForNextControl.new(@control_variable.to_s, interpreter.get_next_line, from_value, to_value, step_value)
    interpreter.set_fornext(fornext_control)
  end
end

class NextLine < AbstractLine
  def initialize(line)
    super('NEXT')
    # parse control variable
    @control_variable = nil
    begin
      @control_variable = VariableRef.new(line.gsub(/ /, ''))
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

class Read < AbstractLine
  def initialize(line)
    super('READ')
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      begin
        var_name = VariableRef.new(text_item)
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
      var_name = VariableRef.new(text_item)
      interpreter.set_value(var_name, interpreter.read_data)
    end
  end
end

class DataLine < AbstractLine
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

class Stop < AbstractLine
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

class End < AbstractLine
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

class Interpreter
  def initialize
    @running = false
    @data_store = Array.new
    @data_index = 0
    @printer = PrintHandler.new
    @return_stack = Array.new
    @fornexts = Hash.new
  end
  
  def parse_line(line)
    m = /^\d+/.match(line)
    # convert to int for a sortable key
    line_num = m[0].to_i
    # strip leading blanks
    line_text = m.post_match.sub(/^ +/, '')
    # pick out the keyword
    object = Unknown.new(line_text)
      #todo: RESTORE
    if line_text[0..2] == 'REM' then object = Remark.new(line_text[3..-1])
    elsif line_text[0..2] == 'LET' then object = Let.new(line_text[3..-1])
    elsif line_text[0..4] == 'INPUT' then object = Input.new(line_text[5..-1])
    elsif line_text[0..1] == 'IF' then object = If.new(line_text[2..-1])
    elsif line_text[0..4] == 'PRINT' then object = Print.new(line_text[5..-1])
    elsif line_text[0..4] == 'GO TO' then object = Goto.new(line_text[5..-1])
    elsif line_text[0..3] == 'GOTO' then object = Goto.new(line_text[4..-1])
    elsif line_text[0..4] == 'GOSUB' then object = Gosub.new(line_text[5..-1])
    elsif line_text[0..2] == 'FOR' then object = ForLine.new(line_text[3..-1])
    elsif line_text[0..3] == 'NEXT' then object = NextLine.new(line_text[4..-1])
    elsif line_text[0..5] == 'RETURN' then object = Return.new
    elsif line_text[0..3] == 'READ' then object = Read.new(line_text[4..-1])
    elsif line_text[0..3] == 'DATA' then object = DataLine.new(line_text[4..-1])
    elsif line_text[0..3] == 'STOP' then object = Stop.new
    elsif line_text[0..2] == 'END' then object = End.new
    end
    [line_num, object]
  end

  def cmd_list
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      line_numbers.each { | line_num | puts "#{line_num.to_s} #{@program_lines[line_num]}" }
    else
      puts 'No program loaded'
    end
  end
  
  private
  def verify_next_line_number(line_numbers, next_line_number)
    if next_line_number == nil then
      raise BASICException, "Program terminated without END", caller
    end
    if !line_numbers.include?(next_line_number) then
      raise BASICException, "Line number #{next_line_number} not found", caller
    end
    next_line_number
  end
  
  public
  def cmd_run(trace_flag)
    @variables = Hash.new
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      # phase 1: do all initialization (store values in DATA lines)
      line_numbers.each do | line_number |
        line = @program_lines[line_number]
        line.pre_execute(self)
      end
      # phase 2: run each command
      # start with the first line number
      @current_line_number = line_numbers[0]
      @running = true
      while @running
        # pick the next line number
        @next_line_number = line_numbers[line_numbers.index(@current_line_number) + 1]
        begin
          line = @program_lines[@current_line_number]
          puts "#{@current_line_number}: #{line.to_s}" if trace_flag
          line.execute(self)
          if @running then
            # set the next line number (which may have been changed by execute() )
            @current_line_number = verify_next_line_number(line_numbers, @next_line_number)
          else
            @current_line_number = nil
          end
        rescue BASICException => message
          puts "#{message} in line #{current_line_number}"
          @running = false
        end
      end
    else
      puts 'No program loaded'
    end
  end

  def cmd_new
    @program_lines = Hash.new
  end
  
  def cmd_load(filename)
    filename = filename.sub(/^\s+/, '')
    if filename.size > 0 then
      begin
        File.open(filename, 'r') do | file |
          @program_lines = Hash.new
          file.each_line do | line |
            line.chomp!
            if line =~ /^\d+/ then
              line_parts = parse_line(line)
              line_num = line_parts[0]
              line_text = line_parts[1]
              @program_lines[line_num] = line_text
              if line_text.errors.size > 0 then
                line_text.errors.each { | error | puts error }
              end
            else
              # warn about line that does not begin with line number
            end
          end
        end
        true
      rescue Errno::ENOENT
        puts "File '#{filename}' not found"
        false
      end
    else
      puts "Filename not specified"
      false
    end
  end

  def cmd_save(filename)
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      filename.sub!(/^\s+/, '')
      if filename.size > 0 then
        begin
          File.open(filename, 'w') do | file |
            line_numbers.each { | line_num | file.puts "#{line_num.to_s} #{@program_lines[line_num]}" }
            file.close
          end
        rescue Errno::ENOENT
          puts "File '#{filename}' not opened"
        end
      else
        puts "Filename not specified"
      end
    else
      puts 'No program loaded'
    end
  end
  
  def stop
    @running = false
    puts "STOP in line #{@current_line_number}"
  end

  def current_line_number
    @current_line_number
  end

  def get_next_line
    @next_line_number
  end
  
  def set_next_line(line_number)
    @next_line_number = line_number
  end
  
  def get_value(variable)
    begin
      VariableRef.new(variable.to_s)
      if !@variables.has_key?(variable.to_s) then
        @variables[variable.to_s] = 0
      end
      @variables[variable.to_s]
    rescue
      raise BASICException, "Unknown variable #{variable}", caller
    end
  end
  
  def set_value(variable, value)
    begin
      VariableRef.new(variable.to_s)
      @variables[variable.to_s] = value
    rescue
      raise BASICException, "Unknown variable #{variable}", caller
    end
  end

  def evaluate(compiled_expression)
    stack = Array.new
    compiled_expression.each do | token |
      if token.is_operator or token.is_function then
        x = token.evaluate(stack)
        stack.push(x)
      else
        if token.class.to_s == 'ArgumentCounter' then
          stack.push(token)
        else
        # if token is numeric expression, push onto stack
          x = token.evaluate(self)
          case x.class.to_s
          when 'Fixnum'
              z = 0
          when 'Float'
              z = 0
          when 'NumericConstant'
              x = x.evaluate(self)
          when 'NumericExpression'
              x = x.evaluate(self)
          else throw "Unknown data type #{x.class}"
          end
          stack.push(x)
        end
      end
    end
    # should be only one item on stack
    # that is the result
    stack[0]
  end
  
  def print_handler
    @printer
  end
  
  def push_return(destination)
    @return_stack.push(destination)
  end
  
  def pop_return
    raise(BASICException, "RETURN without GOSUB", caller) if @return_stack.size == 0
    @return_stack.pop
  end
  
  def set_fornext(fornext_control)
    control_variable = fornext_control.control_variable_name
    @fornexts[control_variable] = fornext_control
  end
  
  def get_fornext(control_variable)
    fornext = @fornexts[control_variable.to_s]
    raise(BASICException, "NEXT without FOR", caller) if fornext == nil
    fornext
  end
  
  def store_data(value)
    @data_store << value
  end
  
  def read_data
    if @data_index < @data_store.size then
      @data_index += 1
      @data_store[@data_index - 1]
    else
      raise(BASICException, "Out of data", caller)
    end
  end

  def go
    puts "BASIC-1965 interpreter version -1"
    puts
    @program_lines = Hash.new
    need_prompt = true
    done = false
    while !done do
      # display prompt
      print "READY\n" if need_prompt

      # read input
      cmd = gets
      cmd.chomp!
      
      # process command
      if cmd =~ /^\d+/ then
        # program line -- store
        line_parts = parse_line(cmd)
        line_num = line_parts[0]
        line_text = line_parts[1]
        @program_lines[line_num] = line_text
        need_prompt = false
        if line_text.errors.size > 0 then
          line_text.errors.each { | error | puts error }
          need_prompt = true
        end
      else
        # immediate command -- execute
        if cmd == 'LIST' then cmd_list
        elsif cmd == 'RUN' then cmd_run(false)
        elsif cmd == 'TRACE' then cmd_run(true)
        elsif cmd == 'NEW' then cmd_new
        elsif cmd[0..3] == 'LOAD' then cmd_load(cmd[4..-1])
        elsif cmd[0..3] == 'SAVE' then cmd_save(cmd[4..-1])
        elsif cmd == 'EXIT' then done = true
        else print "Unknown command #{cmd}\n"
        end
        need_prompt = true
      end
    end
    puts
    puts "BASIC-1965 ended"
  end
  
  def load_and_run(filename, trace_flag)
    puts "BASIC-1965 interpreter version -1"
    puts
    @program_lines = Hash.new
    if cmd_load(filename) then
      cmd_run(trace_flag)
    end
    puts
    puts "BASIC-1965 ended"
  end
end

interpreter = Interpreter.new
if ARGV.size > 0 then
  filename = ARGV[0]
  trace_flag = false
  until ARGV.empty? do
    trace_flag = true if ARGV[0] == '-trace'
    ARGV.shift
  end
  # set_trace_func proc { | event, file, line, id, binding, classname |
  #  puts "#{classname}.#{id} #{file}:#{line} #{event}" if !['IO', 'Kernel', 'Module', 'Fixnum',  'NameError', 'Exception', 'NoMethodError', 'Symbol', 'String', 'NilClass', 'Hash'].include?(classname.to_s)
  # }
  interpreter.load_and_run(filename, trace_flag)
else
  interpreter.go
end

