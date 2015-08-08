#!/usr/bin/ruby

require 'benchmark'
require 'exceptions'
require 'constants'
require 'operators'
require 'expressions'
require 'statements'

# Contain line numbers
class LineNumber
  attr_reader :line_number

  def initialize(line_number)
    if line_number.class.to_s == 'String' && /\A\d+\z/.match(line_number)
      @line_number = line_number.to_i
    elsif line_number.class.to_s == 'Fixnum'
      @line_number = line_number
    else
      fail BASICException, 'Invalid line number'
    end
  end

  def eql?(other)
    @line_number == other.line_number
  end

  def ==(other)
    @line_number == other.line_number
  end

  def hash
    @line_number.hash
  end

  def succ
    LineNumber.new(@line_number + 1)
  end

  def <=>(other)
    @line_number <=> other.line_number
  end

  def >(other)
    @line_number > other.line_number
  end

  def >=(other)
    @line_number >= other.line_number
  end

  def <(other)
    @line_number < other.line_number
  end

  def <=(other)
    @line_number <= other.line_number
  end

  def to_s
    @line_number.to_s
  end
end

# Contain line number ranges
# used in LIST and DELETE commands
class LineNumberRange
  attr_reader :line_numbers

  def initialize(text, program_line_numbers)
    @line_numbers = []
    @range_type = :empty
    if text == ''
      @line_numbers = program_line_numbers
      @range_type = :all
    else
      begin
        line_number = LineNumber.new(text)
        @line_numbers << line_number if
          program_line_numbers.include?(line_number)
        @range_type = :single
      rescue BASICException
        begin
          @line_numbers = line_range(text, program_line_numbers)
        rescue BASICException
          @line_numbers = line_list(text, program_line_numbers)
        end
        @range_type = :range
      end
    end
  end

  def single?
    @range_type == :single
  end

  def range?
    @range_type == :range
  end

  def all?
    @range_type == :all
  end

  private

  def line_range(spec, program_line_numbers)
    list = []
    spec = spec.sub(/^\s+/, '').sub(/\s+$/, '')
    regex = Regexp.new('^\d+-\d+$')
    fail(BASICException, 'Invalid list specification') if regex !~ spec
    parts = spec.split('-')
    start_val = LineNumber.new(parts[0])
    end_val = LineNumber.new(parts[1])
    fail(BASICException, 'Invalid list specification') if end_val < start_val
    program_line_numbers.each do |line_number|
      list << line_number if line_number >= start_val && line_number <= end_val
    end
    list
  end

  def line_list(spec, program_line_numbers)
    list = []
    spec = spec.sub(/^\s+/, '').sub(/\s+$/, '')
    two_regex = Regexp.new('\A\d+\+\d+\z')
    one_regex = Regexp.new('\A\d+\+\z')
    if two_regex =~ spec
      parts = spec.split('+')
      start_val = LineNumber.new(parts[0])
      count = parts[1].to_i
    elsif one_regex =~ spec
      parts = spec.split('+')
      start_val = LineNumber.new(parts[0])
      count = 20
    else
      fail(BASICException, 'Invalid list specification')
    end
    program_line_numbers.each do |line_number|
      if line_number >= start_val && count >= 0
        list << line_number
        count -= 1
      end
    end
    list
  end
end

# Print Handler class
# Handle tab stops and carriage control
class PrintHandler
  def initialize(max_width, print_rate)
    @column = 0
    @max_width = max_width
    @print_rate = print_rate
    @last_was_numeric = false
  end

  def print_item(text)
    if (@column + text.length) < @max_width
      print_out text
      @column += text.size
    else
      overflow = @column + text.length - @max_width
      first_count = text.length - overflow
      print_out text[0..first_count]
      newline
      print_out text[first_count + 1..text.length]
      @column = overflow
    end
    @last_was_numeric = false
  end

  def last_was_numeric
    @last_was_numeric = true
  end

  def tab
    if @last_was_numeric
      count = 3
      while @column > 0 && count > 0
        print_item(' ')
        count -= 1
      end
    end
    print_item(' ') while @column > 0 && @column % 16 != 0
    @last_was_numeric = false
  end

  def semicolon
    if @last_was_numeric
      count = 3
      while @column > 0 && count > 0
        print_item(' ')
        count -= 1
      end
      print_item(' ') while @column % 3 != 0
    end
    @last_was_numeric = false
  end

  def newline
    puts
    delay
    @column = 0
    @last_was_numeric = false
  end

  def newline_when_needed
    newline if @column > 0
  end

  def implied_newline
    @column = 0
  end

  def print_out(text)
    text.each_char do |c|
      print(c)
      delay
    end unless text.nil?
  end

  def delay
    sleep(1.0 / @print_rate) if @print_rate > 0
  end
end

# the interpreter
class Interpreter
  attr_reader :current_line_number

  def initialize(output_speed)
    @running = false
    @randomizer = Random.new
    @data_store = []
    @data_index = 0
    @printer = PrintHandler.new(72, output_speed)
    @return_stack = []
    @fornexts = {}
    @dimensions = {}
    @user_functions = {}
    @user_var_names = {}
    @user_var_values = []
  end

  def parse_line(line)
    m = /^\d+/.match(line)
    line_num = LineNumber.new(m[0])
    # strip leading and trailing blanks (SPACEs and TABs)
    line_text = m.post_match.sub(/^\s+/, '').sub(/\s+$/, '')
    # pick out the keyword
    statement = UnknownStatement.new(line_text)
    begin
      if line_text == '' then statement = EmptyStatement.new
      elsif line_text[0..2] == 'REM'
        statement = RemarkStatement.new(line_text[3..-1])
      elsif line_text[0..2] == 'DIM'
        statement = DimStatement.new(line_text[3..-1])
      elsif line_text[0..2] == 'DEF'
        statement = DefineFunctionStatement.new(line_text[3..-1])
      elsif line_text[0..2] == 'LET'
        statement = LetStatement.new(line_text[3..-1])
      elsif line_text[0..4] == 'INPUT'
        statement = InputStatement.new(line_text[5..-1])
      elsif line_text[0..1] == 'IF'
        statement = IfStatement.new(line_text[2..-1])
      elsif line_text[0..4] == 'PRINT'
        statement = PrintStatement.new(line_text[5..-1])
      elsif line_text[0..4] == 'GO TO'
        statement = GotoStatement.new(line_text[5..-1])
      elsif line_text[0..3] == 'GOTO'
        statement = GotoStatement.new(line_text[4..-1])
      elsif line_text[0..4] == 'GOSUB'
        statement = GosubStatement.new(line_text[5..-1])
      elsif line_text[0..2] == 'FOR'
        statement = ForStatement.new(line_text[3..-1])
      elsif line_text[0..3] == 'NEXT'
        statement = NextStatement.new(line_text[4..-1])
      elsif line_text == 'RETURN' then statement = ReturnStatement.new
      elsif line_text[0..3] == 'READ'
        statement = ReadStatement.new(line_text[4..-1])
      elsif line_text[0..3] == 'DATA'
        statement = DataStatement.new(line_text[4..-1])
      elsif line_text == 'STOP' then statement = StopStatement.new
      elsif line_text == 'END'
        statement = EndStatement.new
      elsif line_text[0..4] == 'TRACE'
        statement = TraceStatement.new(line_text[5..-1])
      elsif line_text[0..8] == 'MAT PRINT'
        statement = MatPrintStatement.new(line_text[9..-1])
      end
    rescue BASICException => e
      puts "Syntax error: #{e.message}"
    end
    [line_num, statement]
  end

  def cmd_list(linespec)
    linespec = linespec.sub(/^\s+/, '').sub(/\s+$/, '')
    if @program_lines.size > 0
      begin
        line_number_range =
          LineNumberRange.new(linespec, @program_lines.keys.sort)
        line_numbers = line_number_range.line_numbers
        line_numbers.each do |line_number|
          puts "#{line_number} #{@program_lines[line_number]}"
        end
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end

  def cmd_delete(linespec)
    linespec = linespec.sub(/^\s+/, '').sub(/\s+$/, '')
    if @program_lines.size > 0
      begin
        line_number_range =
          LineNumberRange.new(linespec, @program_lines.keys.sort)
        line_numbers = line_number_range.line_numbers
        if line_number_range.single?
          line_numbers.each do |line_number|
            @program_lines.delete(line_number)
          end
        elsif line_number_range.range?
          line_numbers.each do |line_number|
            puts "#{line_number} #{@program_lines[line_number]}"
          end
          print 'DELETE THESE LINES? '
          answer = gets.chomp
          if answer == 'YES'
            line_numbers.each do |line_number|
              @program_lines.delete(line_number)
            end
          end
        elsif line_number_range.all?
          puts 'Type NEW to delete an entire program'
        end
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end

  private

  def verify_next_line_number(line_numbers, next_line_number)
    fail BASICException, 'Program terminated without END' if
      next_line_number.nil?
    fail BASICException, "Line number #{next_line_number} not found" unless
      line_numbers.include?(next_line_number)
    next_line_number
  end

  public

  def cmd_run(trace_flag)
    @variables = {}
    @tron_flag = false
    line_numbers = @program_lines.keys.sort

    if line_numbers.size > 0
      run_phase_1(line_numbers)
      run_phase_2(line_numbers, trace_flag)
    else
      puts 'No program loaded'
    end
  end

  def run_phase_1(line_numbers)
    # phase 1: do all initialization (store values in DATA lines)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      line.pre_execute(self)
    end
  end

  def run_phase_2(line_numbers, trace_flag)
    # phase 2: run each command
    # start with the first line number
    @current_line_number = line_numbers[0]
    @running = true
    begin
      program_loop(line_numbers, trace_flag) while @running
    rescue Interrupt
      stop_running
    end
  end

  def program_loop(line_numbers, trace_flag)
    # pick the next line number
    @next_line_number =
      line_numbers[line_numbers.index(@current_line_number) + 1]
    begin
      line = @program_lines[@current_line_number]
      puts "#{@current_line_number}: #{line}" if trace_flag || @tron_flag
      if line.errors.size > 0
        puts "Errors in line #{current_line_number}:"
        line.errors.each { |error| puts error }
        stop_running
      end
      line.execute(self) if @running
      # don't merge above statement into this block
      # the statement may change the running state
      if @running
        # set the next line number
        # (which may have been changed by execute() )
        @current_line_number =
          verify_next_line_number(line_numbers, @next_line_number)
      else
        @current_line_number = nil
      end
    rescue BASICException => message
      puts "#{message} in line #{current_line_number}"
      stop_running
    end
  end

  def trace(tron_flag)
    @tron_flag = tron_flag
  end

  def cmd_new
    @program_lines = {}
    @variables = {}
  end

  def cmd_load(filename)
    filename = filename.sub(/^\s+/, '').sub(/\s+$/, '')
    if filename.size > 0
      begin
        File.open(filename, 'r') do |file|
          @program_lines = {}
          file.each_line do |line|
            line.chomp!
            if line =~ /^\d+/
              line_parts = parse_line(line)
              line_num = line_parts[0]
              line_text = line_parts[1]
              @program_lines[line_num] = line_text
              if line_text.errors.size > 0
                line_text.errors.each { |error| puts error }
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
      puts 'Filename not specified'
      false
    end
  end

  def cmd_save(filename)
    if @program_lines.size > 0
      filename.sub!(/^\s+/, '')
      if filename.size > 0
        save_file(filename)
      else
        puts 'Filename not specified'
      end
    else
      puts 'No program loaded'
    end
  end

  def save_file(filename)
    line_numbers = @program_lines.keys.sort
    begin
      File.open(filename, 'w') do |file|
        line_numbers.each do |line_num|
          file.puts "#{line_num} #{@program_lines[line_num]}"
        end
        file.close
      end
    rescue Errno::ENOENT
      puts "File '#{filename}' not opened"
    end
  end

  def dump_vars
    @variables.each do |key, value|
      puts "#{key}: #{value}"
    end
    puts
  end

  def dump_user_functions
    @user_functions.each do |name, expression|
      puts "#{name}: #{expression}"
    end
    puts
  end

  def stop
    stop_running
    puts "STOP in line #{@current_line_number}"
  end

  def stop_running
    @running = false
  end

  def rand(upper_bound)
    @randomizer.rand(upper_bound)
  end

  def get_next_line
    @next_line_number
  end

  def set_next_line(line_number)
    @next_line_number = line_number
  end

  def find_closing_next(control_variable)
    # starting with @next_line_number
    line_numbers = @program_lines.keys
    forward_line_numbers =
      line_numbers.select { |line_number| line_number > @current_line_number }
    # find a NEXT statement with matching control variable
    forward_line_numbers.each do |line_number|
      statement = @program_lines[line_number]
      if statement.class.to_s == 'NextStatement'
        return line_number if statement.control_variable == control_variable
      end
    end
    fail(BASICException, 'FOR without NEXT') # if none found, error
  end

  def set_dimensions(variable, subscripts)
    @dimensions[variable] = subscripts
  end

  def get_dimensions(variable)
    @dimensions[variable]
  end

  def set_user_function(name, variable_names, expressions)
    @user_var_names[name] = variable_names
    @user_functions[name] = expressions
  end

  def get_user_function(name)
    @user_functions[name]
  end

  def get_user_var_names(name)
    @user_var_names[name]
  end

  def set_user_var_values(user_var_values)
    @user_var_values.push(user_var_values)
  end

  def clear_user_var_values
    @user_var_values.pop
  end

  def check_subscripts(variable, subscripts)
    if @dimensions.key?(variable)
      dimensions = @dimensions[variable]
    else
      dimensions = Array.new(subscripts.size, 10)
    end
    fail(BASICException, 'Incorrect number of subscripts') if
      subscripts.size != dimensions.size
    subscripts.zip(dimensions).each do |pair|
      fail(BASICException, "Subscript #{pair[0]} out of range #{pair[1]}") if
        pair[0] > pair[1]
    end
  end

  def get_value(variable)
    x = nil
    v = variable.to_s
    begin
      # first look in user function values stack
      length = @user_var_values.length
      if length > 0
        names_and_values = @user_var_values[-1]
        x = names_and_values[variable] if names_and_values.key?(variable)
      end
      # then look in general table
      if x.nil?
        @variables[v] = 0 unless @variables.key?(v)
        x = @variables[v]
      end
      case x.class.to_s
      when 'Fixnum'
        NumericConstant.new(x)
      when 'Float'
        NumericConstant.new(x)
      when 'NumericConstant'
        x
      else
        fail Exception, "Invalid variable value type #{x}"
      end
    rescue
      raise BASICException, "Unknown variable #{variable}", caller
    end
  end

  def set_value(variable, value)
    valid_classes = %w(Fixnum Float NumericConstant)
    fail Exception, "Bad variable value type #{c}" unless
      valid_classes.include?(value.class.to_s)
    v = variable.to_s
    if value.class.to_s == 'NumericConstant'
      @variables[v] = value.to_v
    else
      @variables[v] = value
    end
  end

  def print_handler
    @printer
  end

  def push_return(destination)
    @return_stack.push(destination)
  end

  def pop_return
    fail(BASICException, 'RETURN without GOSUB') if @return_stack.size == 0
    @return_stack.pop
  end

  def set_fornext(fornext_control)
    control_variable = fornext_control.control_variable
    control_variable_name = control_variable.to_s
    @fornexts[control_variable_name] = fornext_control
  end

  def get_fornext(control_variable)
    fornext = @fornexts[control_variable.to_s]
    fail(BASICException, 'NEXT without FOR') if fornext.nil?
    fornext
  end

  def store_data(values)
    @data_store += values
  end

  def read_data
    if @data_index < @data_store.size
      @data_index += 1
      @data_store[@data_index - 1]
    else
      fail BASICException, 'Out of data'
    end
  end

  def go
    puts 'BASIC-1965 interpreter version -1'
    puts
    @program_lines = {}
    interactive_loop
    puts
    puts 'BASIC-1965 ended'
  end

  def interactive_loop
    need_prompt = true
    done = false
    until done
      print "READY\n" if need_prompt
      cmd = gets.chomp
      if /\A\d/.match(cmd)
        # starts with a number, so maybe it is a program line
        need_prompt = store_program_line(cmd)
      else
        # immediate command -- execute
        done = execute_command(cmd)
        need_prompt = true
      end
    end
  end

  def store_program_line(cmd)
    line_parts = parse_line(cmd)
    line_num = line_parts[0]
    line_text = line_parts[1]
    @program_lines[line_num] = line_text
    line_text.errors.each { |error| puts error } if line_text.errors.size > 0
    line_text.errors.size > 0
  end

  def execute_command(cmd)
    done = false
    if cmd.size > 0
      if cmd == 'EXIT' then done = true
      elsif cmd == 'NEW' then cmd_new
      elsif cmd == 'RUN' then execute_run_command
      elsif cmd == 'TRACE' then cmd_run(true)
      elsif cmd == '.VARS' then dump_vars
      elsif cmd == '.UDFS' then dump_user_functions
      elsif cmd[0..3] == 'LIST' then cmd_list(cmd[4..-1])
      elsif cmd[0..5] == 'DELETE' then cmd_delete(cmd[6..-1])
      elsif cmd[0..3] == 'LOAD' then cmd_load(cmd[4..-1])
      elsif cmd[0..3] == 'SAVE' then cmd_save(cmd[4..-1])
      else print "Unknown command #{cmd}\n"
      end
    end
    done
  end

  def execute_run_command
    timing = Benchmark.measure { cmd_run(false) }
    print_timing(timing)
    puts
  end

  def load_and_run(filename, trace_flag, timing_flag)
    puts 'BASIC-1965 interpreter version -1'
    puts
    @program_lines = {}
    if cmd_load(filename)
      timing = Benchmark.measure { cmd_run(trace_flag) }
      print_timing(timing) if timing_flag
    end
    puts
    puts 'BASIC-1965 ended'
  end

  def print_timing(timing)
    user_time = timing.utime + timing.cutime
    sys_time = timing.stime + timing.cstime
    puts
    puts 'CPU time:'
    puts " user: #{user_time.round(2)}"
    puts " system: #{sys_time.round(2)}"
  end
end

if ARGV.size > 0
  filename = ''
  timing_flag = true
  trace_flag = false
  output_speed = 0
  ARGV.each do |arg|
    if arg[0] == '-'
      trace_flag = true if arg == '-trace'
      timing_flag = false if arg == '-notiming'
      output_speed = 10 if arg == '-tty'
    else
      filename = arg if filename == '' # take only the first filename
    end
  end
  ARGV.clear
  # set_trace_func proc { |event, file, line, id, binding, classname|
  #  puts "#{classname}.#{id} #{file}:#{line} #{event}" if !['IO',
  #    'Kernel', 'Module', 'Fixnum',  'NameError', 'Exception',
  #    'NoMethodError', 'Symbol', 'String', 'NilClass', 'Hash'
  #    ].include?(classname.to_s)
  # }
  interpreter = Interpreter.new(output_speed)
  interpreter.load_and_run(filename, trace_flag, timing_flag)
else
  interpreter = Interpreter.new(0)
  interpreter.go
end
