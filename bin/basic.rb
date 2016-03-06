#!/usr/bin/ruby

require 'benchmark'
require 'optparse'

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
    spec = spec.strip
    fail(BASICException, 'Invalid list specification') unless
      /\A\d+-\d+\z/.match(spec)
    parts = spec.split('-')
    start_val = LineNumber.new(parts[0])
    end_val = LineNumber.new(parts[1])
    fail(BASICException, 'Invalid list specification') if end_val < start_val
    list = []
    program_line_numbers.each do |line_number|
      list << line_number if line_number >= start_val && line_number <= end_val
    end
    list
  end

  def line_list(spec, program_line_numbers)
    spec = spec.strip
    if /\A\d+\+\d+\z/.match(spec)
      parts = spec.split('+')
      start_val = LineNumber.new(parts[0])
      count = parts[1].to_i
    elsif /\A\d+\+\z/.match(spec)
      parts = spec.split('+')
      start_val = LineNumber.new(parts[0])
      count = 20
    else
      fail(BASICException, 'Invalid list specification')
    end
    list = []
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
  def initialize(max_width, zone_width, print_rate)
    @column = 0
    @max_width = max_width
    @zone_width = zone_width
    @print_rate = print_rate
    @last_was_numeric = false
  end

  def print_item(text)
    text.each_char do |c|
      print_out(c)
      @column += 1
      newline if @column >= @max_width
    end
    @last_was_numeric = false
  end

  def last_was_numeric
    @last_was_numeric = true
  end

  def tab
    space_after_numeric if @last_was_numeric
    print_item(' ') while @column > 0 && @column % @zone_width != 0
    @last_was_numeric = false
  end

  def semicolon
    if @last_was_numeric
      space_after_numeric
      print_item(' ') while @column % 3 != 0
    end
    @last_was_numeric = false
  end

  def trace_output(s)
    newline_when_needed
    print_out(s)
    newline
  end

  private

  def space_after_numeric
    count = 3
    while @column > 0 && count > 0
      print_item(' ')
      count -= 1
    end
  end

  public

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
  attr_accessor :next_line_number

  def initialize(print_width, zone_width, output_speed)
    @running = false
    @randomizer = Random.new
    @data_store = []
    @data_index = 0
    @statement_factory = StatementFactory.new
    @printer = PrintHandler.new(print_width, zone_width, output_speed)
    @return_stack = []
    @fornexts = {}
    @dimensions = {}
    @user_functions = {}
    @user_var_names = {}
    @user_var_values = []
  end

  private

  def ascii_printables(text)
    ascii_text = ''
    text.each_char do |c|
      ascii_text += c if c >= ' ' && c <= '~'
    end
    ascii_text
  end

  public

  def parse_line(line)
    @statement_factory.parse(line)
  rescue BASICException => e
    puts "Syntax error: #{e.message}"
  end

  def cmd_list(linespec)
    linespec = linespec.strip
    if @program_lines.size > 0
      begin
        line_number_range =
          LineNumberRange.new(linespec, @program_lines.keys.sort)
        list_lines_errors(line_number_range.line_numbers)
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end

  def cmd_pretty(linespec)
    linespec = linespec.strip
    if @program_lines.size > 0
      begin
        line_number_range =
          LineNumberRange.new(linespec, @program_lines.keys.sort)
        pretty_lines_errors(line_number_range.line_numbers)
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end

  private

  def list_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      statement = @program_lines[line_number]
      puts "#{line_number}#{statement.list}"
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def pretty_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      statement = @program_lines[line_number]
      puts "#{line_number}#{statement.pretty}"
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def list_lines(line_numbers)
    line_numbers.each do |line_number|
      puts "#{line_number} #{@program_lines[line_number]}"
    end
  end

  def delete_lines(line_numbers)
    line_numbers.each { |line_number| @program_lines.delete(line_number) }
  end

  def list_and_delete_lines(line_numbers)
    list_lines(line_numbers)
    print 'DELETE THESE LINES? '
    answer = gets.chomp
    delete_lines(line_numbers) if answer == 'YES'
  end

  public

  def cmd_delete(linespec)
    linespec = linespec.strip
    if @program_lines.size > 0
      begin
        line_number_range =
          LineNumberRange.new(linespec, @program_lines.keys.sort)
        line_numbers = line_number_range.line_numbers
        if line_number_range.single?
          delete_lines(line_numbers)
        elsif line_number_range.range?
          list_and_delete_lines(line_numbers)
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
      @program_lines[line_number].pre_execute(self)
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

  private

  def print_trace_info(line)
    @printer.newline_when_needed
    @printer.print_out "#{@current_line_number}: #{line}"
    @printer.newline
  end

  def print_errors(current_line_number, statement)
    puts "Errors in line #{current_line_number}:"
    statement.errors.each { |error| puts error }
  end

  def execute_a_line(do_trace)
    statement = @program_lines[@current_line_number]
    print_trace_info(statement) if do_trace
    stop_running if statement.errors.size > 0
    print_errors(current_line_number, statement) if statement.errors.size > 0
    statement.execute(self, do_trace) if @running
  end

  public

  def program_loop(line_numbers, trace_flag)
    do_trace = trace_flag || @tron_flag
    # pick the next line number
    @next_line_number =
      line_numbers[line_numbers.index(@current_line_number) + 1]
    begin
      execute_a_line(do_trace)
      # set the next line number
      @current_line_number = nil
      @current_line_number =
        verify_next_line_number(line_numbers, @next_line_number) if @running
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

  def cmd_load(filename, trace_flag)
    filename = filename.strip
    if filename.size > 0
      begin
        File.open(filename, 'r') do |file|
          @program_lines = {}
          file.each_line do |line|
            line = ascii_printables(line)
            puts line if trace_flag
            store_program_line(line, false)
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
      filename = filename.strip
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
    upper_bound = upper_bound.to_v
    upper_bound = upper_bound.truncate
    upper_bound = upper_bound.to_f
    upper_bound = 1.to_f if upper_bound <= 0
    NumericConstant.new(@randomizer.rand(upper_bound))
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
        return line_number if statement.control == control_variable
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

  private

  def make_dimensions(variable, count)
    if @dimensions.key?(variable)
      @dimensions[variable]
    else
      Array.new(count, NumericConstant.new(10))
    end
  end

  public

  def check_subscripts(variable, subscripts)
    dimensions = make_dimensions(variable, subscripts.size)
    fail(BASICException, 'Incorrect number of subscripts') if
      subscripts.size != dimensions.size
    subscripts.zip(dimensions).each do |pair|
      fail(BASICException, "Subscript #{pair[0]} out of range #{pair[1]}") if
        pair[0] > pair[1]
    end
  end

  def get_value(variable)
    v = variable.to_s

    # first look in user function values stack
    length = @user_var_values.length
    x = nil
    if length > 0
      names_and_values = @user_var_values[-1]
      x = names_and_values[variable] if names_and_values.key?(variable)
    end
    # then look in general table
    if x.nil?
      @variables[v] = NumericConstant.new(0) unless @variables.key?(v)
      x = @variables[v]
    end
    x
  end

  def set_value(variable, value, trace)
    v = variable.to_s
    @variables[v] = value
    puts(' ' + variable.to_s + ' = ' + value.to_s) if trace
  end

  def set_values(name, values, trace)
    values.each do |coords, value|
      variable = name.to_s + coords
      set_value(variable, value, trace)
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

  def assign_fornext(fornext_control)
    control_variable = fornext_control.control
    control_variable_name = control_variable.to_s
    @fornexts[control_variable_name] = fornext_control
  end

  def retrieve_fornext(control_variable)
    control_variable_name = control_variable.to_s
    fornext = @fornexts[control_variable_name]
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

  def reset_data
    @data_index = 0
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
      cmd = ascii_printables(gets)
      if /\A\d/.match(cmd)
        # starts with a number, so maybe it is a program line
        need_prompt = store_program_line(cmd, true)
      else
        # immediate command -- execute
        done = execute_command(cmd)
        need_prompt = true
      end
    end
  end

  def store_program_line(cmd, print_errors)
    line_num, statement = parse_line(cmd)
    if !line_num.nil? && !statement.nil?
      @program_lines[line_num] = statement
      statement.errors.each { |error| puts error } if print_errors
      statement.errors.size > 0
    else
      true
    end
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
      elsif cmd[0..5] == 'PRETTY' then cmd_pretty(cmd[6..-1])
      elsif cmd[0..5] == 'DELETE' then cmd_delete(cmd[6..-1])
      elsif cmd[0..3] == 'LOAD' then cmd_load(cmd[4..-1], false)
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
    if cmd_load(filename, false)
      timing = Benchmark.measure { cmd_run(trace_flag) }
      print_timing(timing) if timing_flag
    end
    puts
    puts 'BASIC-1965 ended'
  end

  def load_and_list(filename, trace_flag)
    puts 'BASIC-1965 interpreter version -1'
    puts
    @program_lines = {}
    cmd_list('') if cmd_load(filename, trace_flag)
    puts
    puts 'BASIC-1965 ended'
  end

  def load_and_pretty(filename, trace_flag)
    puts 'BASIC-1965 interpreter version -1'
    puts
    @program_lines = {}
    cmd_pretty('') if cmd_load(filename, trace_flag)
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

options = {}
OptionParser.new do |opt|
  opt.on('-r', '--run SOURCE') { |o| options[:run_name] = o }
  opt.on('-l', '--list SOURCE') { |o| options[:list_name] = o }
  opt.on('-p', '--pretty-list SOURCE') { |o| options[:pretty_name] = o }
  opt.on('--trace') { |o| options[:trace] = o }
  opt.on('--notiming') { |o| options[:notiming] = o }
  opt.on('--tty') { |o| options[:tty] = o }
  opt.on('--print-width WIDTH') { |o| options[:print_width] = o }
  opt.on('--zone-width WIDTH') { |o| options[:zone_width] = o }
end.parse!

run_filename = options[:run_name]
list_filename = options[:list_name]
pretty_filename = options[:pretty_name]
trace_flag = options.key?(:trace) || false
notiming_flag = options.key?(:notiming) || false
timing_flag = !notiming_flag
output_speed = 0
output_speed = 10 if options.key?(:tty)
print_width = 72
print_width = options[:print_width].to_i if options.key?(:print_width)
zone_width = 16
zone_width = options[:zone_width].to_i if options.key?(:zone_width)

if !run_filename.nil?
  interpreter = Interpreter.new(print_width, zone_width, output_speed)
  interpreter.load_and_run(run_filename, trace_flag, timing_flag)
elsif !list_filename.nil?
  interpreter = Interpreter.new(print_width, zone_width, 0)
  interpreter.load_and_list(list_filename, trace_flag)
elsif !pretty_filename.nil?
  interpreter = Interpreter.new(print_width, zone_width, 0)
  interpreter.load_and_pretty(pretty_filename, trace_flag)
else
  interpreter = Interpreter.new(print_width, zone_width, 0)
  interpreter.go
end
