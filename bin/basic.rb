#!/usr/bin/ruby

require 'pry'
require 'benchmark'
require 'optparse'

require 'exceptions'
require 'constants'
require 'operators'
require 'functions'
require 'expressions'
require 'tokens'
require 'statements'

# Contain line numbers
class LineNumber
  attr_reader :line_number

  def self.init?(text)
    /\A\d+\z/.match(text)
  end

  def initialize(line_number)
    if line_number.class.to_s == 'NumericConstantToken'
      @line_number = line_number.to_i
    else
      raise BASICException, 'Invalid line number'
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

# line number range, in form start-end
class LineNumberRange
  attr_reader :list

  def self.init?(text)
    /\A\d+-\d+\z/.match(text)
  end

  def initialize(spec, program_line_numbers)
    raise(BASICException, 'Invalid list specification') unless
      LineNumberRange.init?(spec)
    parts = spec.split('-')
    start_val = LineNumber.new(NumericConstantToken.new(parts[0]))
    end_val = LineNumber.new(NumericConstantToken.new(parts[1]))
    @list = []
    program_line_numbers.each do |line_number|
      @list << line_number if line_number >= start_val && line_number <= end_val
    end
  end
end

# line number range, in form start-count (count default is 20)
class LineNumberCountRange
  attr_reader :list

  def self.init?(text)
    /\A\d+\+\d+\z/.match(text) || /\A\d+\+\z/.match(text)
  end

  def initialize(spec, program_line_numbers)
    raise(BASICException, 'Invalid list specification') unless
      LineNumberCountRange.init?(spec)

    parts = spec.split('+')
    start_val = LineNumber.new(NumericConstantToken.new(parts[0]))
    count = parts.size > 1 ? parts[1].to_i : 20
    make_list(program_line_numbers, start_val, count)
  end

  private

  def make_list(program_line_numbers, start_val, count)
    @list = []
    program_line_numbers.each do |line_number|
      if line_number >= start_val && count >= 0
        @list << line_number
        count -= 1
      end
    end
  end
end

# Contain line number ranges
# used in LIST and DELETE commands
class LineListSpec
  attr_reader :line_numbers
  attr_reader :range_type

  def initialize(text, program_line_numbers)
    @line_numbers = []
    @range_type = :empty
    if text == ''
      @line_numbers = program_line_numbers
      @range_type = :all
    elsif LineNumber.init?(text)
      make_single(text, program_line_numbers)
    elsif LineNumberRange.init?(text)
      make_range(text, program_line_numbers)
    elsif LineNumberCountRange.init?(text)
      make_count_range(text, program_line_numbers)
    end
  end

  private

  def make_single(text, program_line_numbers)
    line_number = LineNumber.new(NumericConstantToken.new(text))
    @line_numbers << line_number if
      program_line_numbers.include?(line_number)
    @range_type = :single
  end

  def make_range(text, program_line_numbers)
    range = LineNumberRange.new(text, program_line_numbers)
    @line_numbers = range.list
    @range_type = :range
  end

  def make_count_range(text, program_line_numbers)
    range = LineNumberCountRange.new(text, program_line_numbers)
    @line_numbers = range.list
    @range_type = :range
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
  attr_reader :printer

  def initialize(print_width, zone_width, output_speed, echo_input)
    @running = false
    @randomizer = Random.new(1)
    @data_store = []
    @data_index = 0
    @statement_factory = StatementFactory.new
    @echo_input = echo_input
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
    if !@program_lines.empty?
      begin
        line_numbers = @program_lines.keys.sort
        line_number_range = LineListSpec.new(linespec, line_numbers)
        line_numbers = line_number_range.line_numbers
        list_lines_errors(line_numbers)
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end

  def cmd_pretty(linespec)
    linespec = linespec.strip
    if !@program_lines.empty?
      begin
        line_numbers = @program_lines.keys.sort
        line_number_range = LineListSpec.new(linespec, line_numbers)
        line_numbers = line_number_range.line_numbers
        pretty_lines_errors(line_numbers)
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
      text = statement.list
      puts line_number.to_s + text
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def pretty_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      statement = @program_lines[line_number]
      text = statement.pretty
      puts line_number.to_s + text
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def list_lines(line_numbers)
    line_numbers.each do |line_number|
      statement = @program_lines[line_number]
      text = statement.list
      puts line_number.to_s + text
    end
  end

  def delete_specific_lines(line_numbers)
    line_numbers.each { |line_number| @program_lines.delete(line_number) }
  end

  def list_and_delete_lines(line_numbers)
    list_lines(line_numbers)
    print 'DELETE THESE LINES? '
    answer = gets.chomp
    delete_specific_lines(line_numbers) if answer == 'YES'
  end

  public

  def cmd_delete(linespec)
    if @program_lines.empty?
      puts 'No program loaded'
    else
      delete_lines(linespec.strip)
    end
  end

  private

  def delete_lines(linespec)
    line_numbers = @program_lines.keys.sort
    line_number_range = LineListSpec.new(linespec.strip, line_numbers)
    line_numbers = line_number_range.line_numbers
    case line_number_range.range_type
    when :single
      delete_specific_lines(line_numbers)
    when :range
      list_and_delete_lines(line_numbers)
    when :all
      puts 'Type NEW to delete an entire program'
    end
  rescue BASICException => e
    puts e
  end

  def verify_next_line_number
    raise BASICException, 'Program terminated without END' if
      @next_line_number.nil?
    line_numbers = @program_lines.keys.sort
    raise BASICException, "Line number #{@next_line_number} not found" unless
      line_numbers.include?(@next_line_number)
  end

  public

  def cmd_run(trace_flag)
    @variables = {}
    @tron_flag = false

    if @program_lines.empty?
      puts 'No program loaded'
    else
      run_phase_1
      run_phase_2(trace_flag)
    end
  end

  def run_phase_1
    # phase 1: do all initialization (store values in DATA lines)
    line_numbers = @program_lines.keys.sort
    line_numbers.each do |line_number|
      @program_lines[line_number].pre_execute(self)
    end
  end

  def run_phase_2(trace_flag)
    # phase 2: run each command
    # start with the first line number
    line_numbers = @program_lines.keys.sort
    @current_line_number = line_numbers[0]
    @running = true
    begin
      program_loop(trace_flag || @tron_flag) while @running
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
    if statement.errors.empty?
      statement.execute(self, do_trace)
    else
      stop_running
      print_errors(current_line_number, statement)
    end
  end

  def program_loop(trace_flag)
    # pick the next line number
    @next_line_number = find_next_line_number
    begin
      execute_a_line(trace_flag)
      # set the next line number
      @current_line_number = nil
      if @running
        verify_next_line_number
        @current_line_number = @next_line_number
      end
    rescue BASICException => message
      puts "#{message} in line #{current_line_number}"
      stop_running
    end
  end

  def find_next_line_number
    line_numbers = @program_lines.keys.sort
    index = line_numbers.index(@current_line_number)
    line_numbers[index + 1]
  end

  public

  def trace(tron_flag)
    @tron_flag = tron_flag
  end

  def cmd_new
    @program_lines = {}
    @variables = {}
  end

  def cmd_load(filename, trace_flag)
    filename = filename.strip
    if !filename.empty?
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
    if @program_lines.empty?
      puts 'No program loaded'
    else
      filename = filename.strip
      if filename.empty?
        puts 'Filename not specified'
      else
        save_file(filename)
      end
    end
  end

  def save_file(filename)
    line_numbers = @program_lines.keys.sort
    begin
      File.open(filename, 'w') do |file|
        line_numbers.each do |line_num|
          text = @program_lines[line_num]
          file.puts line_num + ' ' + text
        end
        file.close
      end
    rescue Errno::ENOENT
      puts "File '#{filename}' not opened"
    end
  end

  # returns an Array of values
  def evaluate(parsed_expressions)
    # expected = parsed_expressions[0].length
    result_values = []
    parsed_expressions.each do |parsed_expression|
      stack = []
      parsed_expression.each do |element|
        value = element.evaluate(self, stack)
        stack.push value
      end
      # should be only one item on stack
      # actual = stack.length
      # raise(Exception,
      #      "Expected #{expected} items, "
      #      "#{actual} remaining on evaluation stack") if
      #  actual != expected
      # very each item is of correct type
      item = stack[0]
      # raise(Exception,
      #      "Expected item #{expected_result_class}, "
      #      "found item type #{item.class} remaining on evaluation stack") if
      #  item.class.to_s != expected_result_class
      result_values << item unless item.nil?
    end
    # actual = result_values.length
    # raise(Exception,
    #      "Expected #{expected} items, "
    #      "#{actual} remaining on evaluation stack") if
    #   actual != expected
    result_values
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
    upper_bound = 1 if upper_bound <= 0
    upper_bound = upper_bound.to_f
    NumericConstant.new(@randomizer.rand(upper_bound))
  end

  def read_line
    input_line = gets
    input_text = input_line.chomp
    puts(input_text) if @echo_input
    input_text
  end

  def find_closing_next(control_variable)
    # starting with @next_line_number
    line_numbers = @program_lines.keys.sort
    forward_line_numbers =
      line_numbers.select { |line_number| line_number > @current_line_number }
    # find a NEXT statement with matching control variable
    forward_line_numbers.each do |line_number|
      statement = @program_lines[line_number]
      if statement.class.to_s == 'NextStatement'
        return line_number if statement.control == control_variable
      end
    end
    raise(BASICException, 'FOR without NEXT') # if none found, error
  end

  def set_dimensions(variable, subscripts)
    name = variable.name
    @dimensions[name] = subscripts
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

  def set_user_var_values(name, user_var_values)
    param_names = @user_var_names[name]
    param_names_values = param_names.zip(user_var_values)
    names_and_values = Hash[param_names_values]
    @user_var_values.push(names_and_values)
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
    raise(BASICException, 'Incorrect number of subscripts') if
      subscripts.size != dimensions.size
    subscripts.zip(dimensions).each do |pair|
      raise(BASICException, "Subscript #{pair[0]} out of range #{pair[1]}") if
        pair[0] > pair[1]
    end
  end

  def get_value(variable)
    value = nil
    # first look in user function values stack
    length = @user_var_values.length
    if length > 0
      names_and_values = @user_var_values[-1]
      value = names_and_values[variable]
    end
    # then look in general table
    if value.nil?
      v = variable.to_s
      @variables[v] = NumericConstant.new(0) unless @variables.key?(v)
      value = @variables[v]
    end
    value
  end

  def set_value(variable, value, trace)
    # check that value type matches variable type
    raise(BASICException, 'Type mismatch') if
      variable.content_type != value.class.to_s
    v = variable.to_s
    @variables[v] = value
    puts(' ' + variable.to_s + ' = ' + value.to_s) if trace
  end

  def set_values(name, values, trace)
    values.each do |coords, value|
      variable = Variable.new(name, coords)
      set_value(variable, value, trace)
    end
  end

  def push_return(destination)
    @return_stack.push(destination)
  end

  def pop_return
    raise(BASICException, 'RETURN without GOSUB') if @return_stack.empty?
    @return_stack.pop
  end

  def assign_fornext(fornext_control)
    control_variable = fornext_control.control
    @fornexts[control_variable] = fornext_control
  end

  def retrieve_fornext(control_variable)
    fornext = @fornexts[control_variable]
    raise(BASICException, 'NEXT without FOR') if fornext.nil?
    fornext
  end

  def store_data(values)
    @data_store += values
  end

  def read_data
    raise BASICException, 'Out of data' if @data_index >= @data_store.size
    @data_index += 1
    @data_store[@data_index - 1]
  end

  def reset_data
    @data_index = 0
  end

  def go
    @program_lines = {}
    interactive_loop
  end

  def interactive_loop
    need_prompt = true
    done = false
    until done
      print "READY\n" if need_prompt
      cmd = ascii_printables(gets)
      if /\A\d/ =~ cmd
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
      !statement.errors.empty?
    else
      true
    end
  end

  def execute_command(cmd)
    return false if cmd.empty?
    return true if cmd == 'EXIT'
    cmd4 = cmd[0..3]
    cmd6 = cmd[0..5]
    if simple_command?(cmd)
      execute_simple_command(cmd)
    elsif command_4?(cmd4)
      execute_4_command(cmd4, cmd[4..-1])
    elsif command_6?(cmd6)
      execute_6_command(cmd6, cmd[6..-1])
    else
      print "Unknown command #{cmd}\n"
    end
    false
  end

  private

  def simple_command?(text)
    %w(NEW RUN TRACE .VARS .UDFS).include?(text)
  end

  def execute_simple_command(text)
    case text
    when 'NEW'
      cmd_new
    when 'RUN'
      execute_run_command
    when 'TRACE'
      cmd_run(true)
    when '.VARS'
      dump_vars
    when '.UDFS'
      dump_user_functions
    end
  end

  def command_4?(text)
    %w(LIST LOAD SAVE).include?(text)
  end

  def execute_4_command(cmd, rest)
    case cmd
    when 'LIST'
      cmd_list(rest)
    when 'LOAD'
      cmd_load(rest, false)
    when 'SAVE'
      cmd_save(rest)
    end
  end

  def command_6?(text)
    %w(PRETTY DELETE).include?(text)
  end

  def execute_6_command(cmd, rest)
    case cmd
    when 'PRETTY'
      cmd_pretty(rest)
    when 'DELETE'
      cmd_delete(rest)
    end
  end

  public

  def execute_run_command
    timing = Benchmark.measure { cmd_run(false) }
    print_timing(timing)
    puts
  end

  def load_and_run(filename, trace_flag, timing_flag)
    @program_lines = {}
    if cmd_load(filename, false)
      timing = Benchmark.measure { cmd_run(trace_flag) }
      print_timing(timing) if timing_flag
    end
  end

  def load_and_list(filename, trace_flag)
    @program_lines = {}
    cmd_list('') if cmd_load(filename, trace_flag)
  end

  def load_and_pretty(filename, trace_flag)
    @program_lines = {}
    cmd_pretty('') if cmd_load(filename, trace_flag)
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
  opt.on('--echo-input') { |o| options[:echo_input] = o }
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
echo_input = options.key?(:echo_input) || false

puts 'BASIC-1965 interpreter version -1'
puts
if !run_filename.nil?
  interpreter =
    Interpreter.new(print_width, zone_width, output_speed, echo_input)
  interpreter.load_and_run(run_filename, trace_flag, timing_flag)
elsif !list_filename.nil?
  interpreter = Interpreter.new(print_width, zone_width, 0, echo_input)
  interpreter.load_and_list(list_filename, trace_flag)
elsif !pretty_filename.nil?
  interpreter = Interpreter.new(print_width, zone_width, 0, echo_input)
  interpreter.load_and_pretty(pretty_filename, trace_flag)
else
  interpreter = Interpreter.new(print_width, zone_width, 0, echo_input)
  interpreter.go
end
puts
puts 'BASIC-1965 ended'
