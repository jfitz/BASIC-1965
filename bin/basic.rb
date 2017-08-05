#!/usr/bin/ruby

require 'benchmark'
require 'optparse'
require 'singleton'

require_relative 'exceptions'
require_relative 'tokens'
require_relative 'tokenbuilders'
require_relative 'tokenizers'
require_relative 'constants'
require_relative 'operators'
require_relative 'functions'
require_relative 'expressions'
require_relative 'io'
require_relative 'statements'

# Contain line numbers
class LineNumber
  attr_reader :line_number

  def self.init?(text)
    /\A\d+\z/.match(text)
  end

  def initialize(line_number)
    raise BASICException, "Invalid line number '#{line_number}'" unless
      line_number.class.to_s == 'NumericConstantToken'
    @line_number = line_number.to_i
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
    else
      raise(BASICException, 'Invalid list specification')
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

# Line class to hold a line of code
class Line
  attr_reader :statement
  attr_reader :tokens

  def initialize(text, statement, tokens, comment)
    @text = text
    @statement = statement
    @tokens = tokens
    @comment = comment
  end

  def list
    @text
  end

  def pretty
    text = AbstractToken.pretty_tokens([], @tokens)
    unless @comment.nil?
      space = @text.size - (text.size + @comment.to_s.size)
      space = 5 if space < 5
      text += ' ' * space
      text += @comment.to_s
    end
    text
  end

  def profile
    @statement.profile
  end

  def renumber(renumber_map)
    @statement.renumber(renumber_map)
    keywords = @statement.keywords
    tokens = @statement.tokens
    text = AbstractToken.pretty_tokens(keywords, tokens)
    Line.new(text, @statement, keywords + tokens, @comment)
  end

  def check(program, console_io, line_number)
    @statement.program_check(program, console_io, line_number)
  end
end

# the interpreter
class Interpreter
  attr_reader :current_line_number
  attr_accessor :next_line_number
  attr_reader :console_io
  attr_reader :trace_out

  def initialize(console_io, int_floor, ignore_rnd_arg, randomize)
    @running = false
    @randomizer = Random.new(1)
    @randomizer = Random.new if randomize
    @int_floor = int_floor
    @ignore_rnd_arg = ignore_rnd_arg
    @console_io = console_io
    @data_store = DataStore.new
    @file_handlers = {}
    @return_stack = []
    @fornexts = {}
    @dimensions = {}
    @user_functions = {}
    @user_var_names = {}
    @user_var_values = []
    @program_lines = {}
    @variables = {}
    @get_value_seen = []
  end

  private

  def verify_next_line_number
    raise BASICException, 'Program terminated without END' if
      @next_line_number.nil?
    line_numbers = @program_lines.keys
    unless line_numbers.include?(@next_line_number)
      raise(BASICException, "Line number #{@next_line_number} not found")
    end
  end

  public

  def run(program, trace_flag, show_timing)
    @program = program
    @program_lines = program.lines
    @trace_flag = trace_flag

    # reset profile metrics
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement
      statement.profile_count = 0
      statement.profile_time = 0
    end

    @null_out = NullOut.new

    timing = Benchmark.measure { run_and_time }
    print_timing(timing, console_io) if show_timing
  end

  def run_and_time
    # run the program
    @variables = {}
    @trace_out = @trace_flag ? @console_io : @null_out
    @running = true
    run_phase_1
    run_phase_2 if @running
  end

  def print_timing(timing, console_io)
    user_time = timing.utime + timing.cutime
    sys_time = timing.stime + timing.cstime
    @console_io.newline
    @console_io.print_line('CPU time:')
    @console_io.print_line(" user: #{user_time.round(2)}")
    @console_io.print_line(" system: #{sys_time.round(2)}")
    @console_io.newline
  end

  def run_phase_1
    # phase 1: do all initialization (store values in DATA lines)
    @current_line_number = @program_lines.min[0]
    preexecute_loop
  end

  def run_phase_2
    # phase 2: run each command
    # start with the first line number
    @current_line_number = @program_lines.min[0]
    begin
      program_loop while @running
    rescue Interrupt
      stop_running
    end
    @file_handlers.each { |_, fh| fh.close }
  end

  def print_trace_info(line)
    @trace_out.newline_when_needed
    @trace_out.print_out @current_line_number.to_s + ':' + line.pretty
    @trace_out.newline
  end

  def print_errors(current_line_number, statement)
    @console_io.print_line("Errors in line #{current_line_number}:")
    statement.errors.each { |error| puts error }
  end

  def preexecute_a_statement
    line = @program_lines[@current_line_number]
    statement = line.statement
    if statement.errors.empty?
      statement.pre_execute(self)
    else
      stop_running
      print_errors(current_line_number, statement)
    end
  end

  def preexecute_loop
    while !@current_line_number.nil? && @running
      preexecute_a_statement
      @current_line_number = @program.find_next_line_number(@current_line_number)
    end
  rescue BASICException => e
    message = "#{e.message} in line #{@current_line_number}"
    @console_io.print_line(message)
    stop_running
  end

  def execute_a_statement
    line = @program_lines[@current_line_number]
    current_line_number = @current_line_number
    statement = line.statement
    print_trace_info(line)
    if statement.errors.empty?
      timing = Benchmark.measure { statement.execute(self) }
      user_time = timing.utime + timing.cutime
      sys_time = timing.stime + timing.cstime
      time = user_time + sys_time
      statement.profile_time += time
      statement.profile_count += 1
    else
      stop_running
      print_errors(current_line_number, statement)
    end
    @get_value_seen = []
  end

  def program_loop
    # pick the next line number
    @next_line_number = @program.find_next_line_number(@current_line_number)
    begin
      execute_a_statement
      # set the next line number
      @current_line_number = nil
      if @running
        verify_next_line_number
        @current_line_number = @next_line_number
      end
    rescue BASICException => e
      if @current_line_number.nil?
        message = e.message
      else
        message = "#{e.message} in line #{@current_line_number}"
      end
      @console_io.print_line(message)
      stop_running
    end
  end

  def has_line_number(line_number)
    @program_lines.key?(line_number)
  end

  def find_next_line_number
    @program.find_next_line_number(@current_line_number)
  end

  def trace(tron_flag)
    @trace_out = (@trace_flag || tron_flag) ? @console_io : @null_out
  end

  def clear_variables
    @variables = {}
  end

  # returns an Array of values
  def evaluate(parsed_expressions, trace)
    old_trace_flag = @trace_flag
    @trace_flag = trace
    result_values = []
    parsed_expressions.each do |parsed_expression|
      stack = []
      exp = parsed_expression.empty? ? 0 : 1
      parsed_expression.each do |element|
        value = element.evaluate(self, stack, trace)
        stack.push value
      end
      act = stack.length
      raise(BASICException, 'Bad expression') if act != exp

      next if act.zero?

      # verify each item is of correct type
      item = stack[0]
      result_values << item
    end
    @trace_flag = old_trace_flag
    result_values
  end

  def dump_vars
    @variables.each do |key, value|
      @console_io.print_line("#{key}: #{value}")
    end
    puts
  end

  def dump_user_functions
    @user_functions.each do |name, expression|
      @console_io.print_line("#{name}: #{expression}")
    end
    puts
  end

  def dump_dims
    @dimensions.each do |key, value|
      dims = []
      value.each { |nc| dims << nc.to_v }
      @console_io.print_line("#{key.class}:#{key} (#{dims.join(', ')})")
    end
  end

  def stop
    stop_running
    @console_io.print_line("STOP in line #{@current_line_number}")
  end

  def stop_running
    @running = false
  end

  def rand(upper_bound)
    upper_bound = upper_bound.to_v
    upper_bound = upper_bound.truncate
    upper_bound = 1 if upper_bound <= 0
    upper_bound = 1 if @ignore_rnd_arg
    upper_bound = upper_bound.to_f
    NumericConstant.new(@randomizer.rand(upper_bound))
  end

  def find_closing_next(control_variable)
    # starting with @next_line_number
    line_numbers = @program_lines.keys.sort
    forward_line_numbers =
      line_numbers.select { |line_number| line_number > @current_line_number }
    # find a NEXT statement with matching control variable
    forward_line_numbers.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement
      return line_number if
        statement.class.to_s == 'NextStatement' &&
        statement.control == control_variable
    end
    raise(BASICException, 'FOR without NEXT') # if none found, error
  end

  def set_dimensions(variable, subscripts)
    name = variable.name
    int_subscripts = normalize_subscripts(subscripts)
    @dimensions[name] = int_subscripts
  end

  def normalize_subscripts(subscripts)
    raise(Exception, 'Invalid subscripts container') unless
      subscripts.class.to_s == 'Array'
    int_subscripts = []
    subscripts.each do |subscript|
      raise(Excaption, "Invalid subscript #{subscript}") unless
        subscript.numeric_constant?
      int_subscripts << subscript.truncate
    end
    int_subscripts
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
    int_subscripts = normalize_subscripts(subscripts)
    dimensions = make_dimensions(variable, int_subscripts.size)
    raise(BASICException, 'Incorrect number of subscripts') if
      int_subscripts.size != dimensions.size
    int_subscripts.zip(dimensions).each do |pair|
      raise(BASICException, "Subscript #{pair[0]} out of range #{pair[1]}") if
        pair[0] > pair[1]
    end
  end

  def get_value(variable, trace)
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
    seen = @get_value_seen.include?(variable)
    if @trace_flag && trace && !seen
      @trace_out.print_line(' ' + variable.to_s + ' = ' + value.to_s)
      @get_value_seen << variable
    end
    value
  end

  def set_value(variable, value)
    # check that value type matches variable type
    if value.class.to_s != variable.content_type
      raise(BASICException,
            "Type mismatch '#{value}' is not #{variable.content_type}")
    end
    v = variable.to_s
    @variables[v] = value
    @trace_out.print_line(' ' + variable.to_s + ' = ' + value.to_s)
  end

  def set_values(name, values)
    values.each do |coords, value|
      variable = Variable.new(name, coords)
      set_value(variable, value)
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

  def add_file_names(file_names)
    file_names.each do |name|
      raise(BASICException, 'Invalid file name') unless
        name.class.to_s == 'TextConstant'
      raise(BASICException, "File '#{name.value}' not found") unless
        File.file?(name.value)
      file_handle = FileHandle.new(@file_handlers.size + 1)
      @file_handlers[file_handle] = FileHandler.new(name.value)
    end
  end

  def get_file_handler(file_handle)
    return @console_io if file_handle.nil?

    raise(BASICException, 'Unknown file handle') unless
      @file_handlers.key?(file_handle)
    fh = @file_handlers[file_handle]
    fh.set_mode(:print)
    fh
  end

  def get_input(file_handle)
    raise(BASICException, 'Unknown file handle') unless
      @file_handlers.key?(file_handle)
    fh = @file_handlers[file_handle]
    fh.set_mode(:read)
    fh
  end

  def get_data_store(file_handle)
    return @data_store if file_handle.nil?
    raise(BASICException, 'Unknown file handle') unless
      @file_handlers.key?(file_handle)
    fh = @file_handlers[file_handle]
    fh.set_mode(:read)
    fh
  end

  def int_floor?
    @int_floor
  end
end

# program container
class Program
  def initialize(console_io, tokenizers)
    @console_io = console_io
    @program_lines = {}
    @statement_factory = StatementFactory.instance
    @statement_factory.tokenizers = tokenizers
  end

  def empty?
    @program_lines.empty?
  end

  def has_line_number(line_number)
    @program_lines.key?(line_number)
  end

  def lines
    @program_lines
  end

  def cmd_new
    @program_lines = {}
  end

  def list(linespec, list_tokens)
    linespec = linespec.strip
    if !@program_lines.empty?
      begin
        line_numbers = @program_lines.keys.sort
        line_number_range = LineListSpec.new(linespec, line_numbers)
        line_numbers = line_number_range.line_numbers
        list_lines_errors(line_numbers, list_tokens)
      rescue BASICException => e
        @console_io.print_line(e)
      end
    else
      @console_io.print_line('No program loaded')
    end
  end

  def pretty(linespec)
    linespec = linespec.strip
    if !@program_lines.empty?
      begin
        line_numbers = @program_lines.keys.sort
        line_number_range = LineListSpec.new(linespec, line_numbers)
        line_numbers = line_number_range.line_numbers
        pretty_lines_errors(line_numbers)
      rescue BASICException => e
        @console_io.print_line(e)
      end
    else
      @console_io.print_line('No program loaded')
    end
  end

  def profile(linespec)
    linespec = linespec.strip
    if !@program_lines.empty?
      begin
        line_numbers = @program_lines.keys.sort
        line_number_range = LineListSpec.new(linespec, line_numbers)
        line_numbers = line_number_range.line_numbers
        profile_lines_errors(line_numbers)
      rescue BASICException => e
        @console_io.print_line(e)
      end
    else
      @console_io.print_line('No program loaded')
    end
  end

  def load(filename)
    filename = filename.strip
    if !filename.empty?
      begin
        File.open(filename, 'r') do |file|
          @program_lines = {}
          file.each_line do |line|
            line = @console_io.ascii_printables(line)
            store_program_line(line, false)
          end
        end
        true
      rescue Errno::ENOENT
        @console_io.print_line("File '#{filename}' not found")
        false
      end
    else
      @console_io.print_line('Filename not specified')
      false
    end
  end

  def save(filename)
    if @program_lines.empty?
      @console_io.print_line('No program loaded')
    else
      filename = filename.strip
      if filename.empty?
        @console_io.print_line('Filename not specified')
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
      @console_io.print_line("File '#{filename}' not opened")
    end
  end

  def print_profile
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      number = line_number.to_s
      profile = line.profile
      text = number + profile
      puts text
    end
  end

  def delete(linespec)
    if @program_lines.empty?
      @console_io.print_line('No program loaded')
    else
      delete_lines(linespec.strip)
    end
  end

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
      @console_io.print_line('Type NEW to delete an entire program')
    end
  rescue BASICException => e
    @console_io.print_line(e)
  end

  def renumber
    # generate new line numbers
    renumber_map = {}
    new_number = 10
    @program_lines.keys.sort.each do |line_number|
      number_token = NumericConstantToken.new(new_number)
      new_line_number = LineNumber.new(number_token)
      renumber_map[line_number] = new_line_number
      new_number += 10
    end
    # assign new line numbers
    new_program_lines = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      new_line_number = renumber_map[line_number]
      new_program_lines[new_line_number] = line.renumber(renumber_map)
    end

    @program_lines = new_program_lines
  end

  def store_program_line(cmd, print_errors)
    line_num, line = parse_line(cmd)
    if !line_num.nil? && !line.nil?
      check_line_duplicate(line_num, print_errors)
      check_line_sequence(line_num, print_errors)
      @program_lines[line_num] = line
      statement = line.statement
      statement.errors.each { |error| puts error } if print_errors
      !statement.errors.empty?
    else
      true
    end
  end

  def parse_line(line)
    @statement_factory.parse(line)
  rescue BASICException => e
    @console_io.print_line("Syntax error: #{e.message}")
  end

  def check_line_duplicate(line_num, print_errors)
    # warn about duplicate lines when loading
    # but not when typing
    @console_io.print_line("Duplicate line number #{line_num}") if
      @program_lines.key?(line_num) && !print_errors
  end

  def check_line_sequence(line_num, print_errors)
    # warn about lines out of sequence
    # but not when typing
    @console_io.print_line("Line #{line_num} is out of sequence") if
      !@program_lines.empty? &&
      line_num < @program_lines.max[0] &&
      !print_errors
  end

  def list_lines_errors(line_numbers, list_tokens)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      @console_io.print_line(line_number.to_s + line.list)
      statement = line.statement
      statement.errors.each { |error| puts ' ' + error }
      tokens = line.tokens
      text_tokens = tokens.map(&:to_s)
      @console_io.print_line('TOKENS: ' + text_tokens.to_s) if list_tokens
    end
  end

  def pretty_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      number = line_number.to_s
      pretty = line.pretty
      @console_io.print_line(number + pretty)
      statement = line.statement
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def profile_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      number = line_number.to_s
      profile = line.profile
      @console_io.print_line(number + profile)
      statement = line.statement
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def list_lines(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      text = line.list
      @console_io.print_line(line_number.to_s + text)
    end
  end

  def delete_specific_lines(line_numbers)
    line_numbers.each { |line_number| @program_lines.delete(line_number) }
  end

  def list_and_delete_lines(line_numbers)
    list_lines(line_numbers)
    print 'DELETE THESE LINES? '
    answer = @console_io.read_line
    delete_specific_lines(line_numbers) if answer == 'YES'
  end

  def check
    result = true
    @program_lines.keys.sort.each do |line_number|
      r = @program_lines[line_number].check(self, @console_io, line_number)
      result &&= r
    end
    result
  end

  def find_next_line_number(line_number)
    line_numbers = @program_lines.keys.sort
    index = line_numbers.index(line_number)
    line_numbers[index + 1]
  end
end

# interactive shell
class Shell
  def initialize(console_io, interpreter, program)
    @console_io = console_io
    @interpreter = interpreter
    @program = program
  end

  def run
    need_prompt = true
    done = false
    until done
      @console_io.print_line('READY') if need_prompt
      cmd = @console_io.read_line
      if /\A\d/ =~ cmd
        # starts with a number, so maybe it is a program line
        need_prompt = @program.store_program_line(cmd, true)
      else
        # immediate command -- execute
        done = execute_command(cmd)
        need_prompt = true
      end
    end
  end

  private

  def execute_command(cmd)
    return false if cmd.empty?
    return true if cmd == 'EXIT'
    cmd4 = cmd[0..3]
    cmd6 = cmd[0..5]
    cmd7 = cmd[0..6]
    cmd8 = cmd[0..7]
    if simple_command?(cmd)
      execute_simple_command(cmd)
    elsif command_4?(cmd4)
      execute_4_command(cmd4, cmd[4..-1])
    elsif command_6?(cmd6)
      execute_6_command(cmd6, cmd[6..-1])
    elsif command_7?(cmd7)
      execute_7_command(cmd7, cmd[7..-1])
    elsif command_8?(cmd8)
      execute_8_command(cmd8, cmd[8..-1])
    else
      print "Unknown command #{cmd}\n"
    end
    false
  end

  def simple_command?(text)
    %w(NEW RUN TRACE .VARS .UDFS .DIMS).include?(text)
  end

  def execute_simple_command(text)
    case text
    when 'NEW'
      @program.cmd_new
      @interpreter.clear_variables
    when 'RUN'
      cmd_run(false, true)
    when 'TRACE'
      cmd_run(true, false)
    when '.VARS'
      dump_vars
    when '.UDFS'
      dump_user_functions
    when '.DIMS'
      dump_dims
    end
  end

  def command_4?(text)
    %w(LIST LOAD SAVE).include?(text)
  end

  def execute_4_command(cmd, rest)
    case cmd
    when 'LIST'
      @program.list(rest, false)
    when 'LOAD'
      @program.load(rest)
    when 'SAVE'
      @program.save(rest)
    end
  end

  def command_6?(text)
    %w(TOKENS PRETTY DELETE).include?(text)
  end

  def execute_6_command(cmd, rest)
    case cmd
    when 'TOKENS'
      @program.list(rest, true)
    when 'PRETTY'
      @program.pretty(rest)
    when 'DELETE'
      @program.delete(rest)
    end
  end

  def command_7?(text)
    %w(PROFILE).include?(text)
  end

  def execute_7_command(cmd, rest)
    case cmd
    when 'PROFILE'
      @program.profile(rest)
    end
  end

  def command_8?(text)
    %w(RENUMBER).include?(text)
  end

  def execute_8_command(cmd, rest)
    case cmd
    when 'RENUMBER'
      @program.renumber if @program.check
    end
  end

  def cmd_run(trace_flag, show_timing)
    unless @program.empty?
      @interpreter.run(@program, trace_flag, show_timing) if @program.check
    else
      @console_io.print_line('No program loaded')
    end
  end

  def dump_vars
    @interpreter.dump_vars
  end

  def dump_user_functions
    @interpreter.dump_user_functions
  end

  def dump_dims
    @interpreter.dump_dims
  end
end

def make_tokenizers
  tokenizers = []

  tokenizers << CommentTokenBuilder.new
  tokenizers << RemarkTokenBuilder.new

  statement_factory = StatementFactory.instance
  keywords = statement_factory.keywords_definitions

  tokenizers << ListTokenBuilder.new(keywords, KeywordToken)

  un_ops = UnaryOperator.operators
  bi_ops = BinaryOperator.operators
  operators = (un_ops + bi_ops).uniq
  tokenizers << ListTokenBuilder.new(operators, OperatorToken)

  tokenizers << BreakTokenBuilder.new

  tokenizers << ListTokenBuilder.new(['(', '['], GroupStartToken)
  tokenizers << ListTokenBuilder.new([')', ']'], GroupEndToken)
  tokenizers << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)

  tokenizers <<
    ListTokenBuilder.new(FunctionFactory.function_names, FunctionToken)

  function_names = ('FNA'..'FNZ').to_a
  tokenizers << ListTokenBuilder.new(function_names, UserFunctionToken)

  tokenizers << TextTokenBuilder.new
  tokenizers << NumberTokenBuilder.new
  tokenizers << VariableTokenBuilder.new
  tokenizers << ListTokenBuilder.new(%w(TRUE FALSE), BooleanConstantToken)
  tokenizers << WhitespaceTokenBuilder.new
end

options = {}
OptionParser.new do |opt|
  opt.on('-l', '--list SOURCE') { |o| options[:list_name] = o }
  opt.on('--tokens') { |o| options[:tokens] = o }
  opt.on('-p', '--pretty SOURCE') { |o| options[:pretty_name] = o }
  opt.on('-r', '--run SOURCE') { |o| options[:run_name] = o }
  opt.on('--profile') { |o| options[:profile] = o }
  opt.on('--no-heading') { |o| options[:no_heading] = o }
  opt.on('--echo-input') { |o| options[:echo_input] = o }
  opt.on('--trace') { |o| options[:trace] = o }
  opt.on('--no-timing') { |o| options[:no_timing] = o }
  opt.on('--tty') { |o| options[:tty] = o }
  opt.on('--tty-lf') { |o| options[:tty_lf] = o }
  opt.on('--print-width WIDTH') { |o| options[:print_width] = o }
  opt.on('--zone-width WIDTH') { |o| options[:zone_width] = o }
  opt.on('--int-floor') { |o| options[:int_floor] = o }
  opt.on('--ignore-rnd-arg') { |o| options[:ignore_rnd_arg] = o }
  opt.on('--implied-semicolon') { |o| options[:implied_semicolon] = o }
  opt.on('--qmark-after-prompt') { |o| options[:qmark_after_prompt] = o }
  opt.on('--randomize') { |o| options[:randomize] = o }
end.parse!

list_filename = options[:list_name]
list_tokens = options.key?(:tokens)
pretty_filename = options[:pretty_name]
run_filename = options[:run_name]
show_profile = options.key?(:profile)
show_heading = !options.key?(:no_heading)
echo_input = options.key?(:echo_input)
trace_flag = options.key?(:trace)
show_timing = !options.key?(:no_timing)
output_speed = 0
output_speed = 10 if options.key?(:tty)
newline_speed = 0
newline_speed = 10 if options.key?(:tty_lf)
print_width = 72
print_width = options[:print_width].to_i if options.key?(:print_width)
zone_width = 16
zone_width = options[:zone_width].to_i if options.key?(:zone_width)
int_floor = options.key?(:int_floor)
ignore_rnd_arg = options.key?(:ignore_rnd_arg)
implied_semicolon = options.key?(:implied_semicolon)
qmark_after_prompt = options.key?(:qmark_after_prompt)
randomize = options.key?(:randomize)

default_prompt = TextConstantToken.new('"? "')
console_io =
  ConsoleIo.new(print_width, zone_width, output_speed, newline_speed,
                implied_semicolon, default_prompt, qmark_after_prompt,
                echo_input)

tokenizers = make_tokenizers

if show_heading
  console_io.print_line('BASIC-1965 interpreter version -1')
  console_io.newline
end

if !run_filename.nil?
  program = Program.new(console_io, tokenizers)
  if program.load(run_filename) && program.check
    interpreter =
      Interpreter.new(console_io, int_floor, ignore_rnd_arg, randomize)
    interpreter.run(program, trace_flag, show_timing)
  end
elsif !list_filename.nil?
  program = Program.new(console_io, tokenizers)
  if program.load(list_filename)
    program.list('', list_tokens)
  end
elsif !pretty_filename.nil?
  program = Program.new(console_io, tokenizers)
  if program.load(pretty_filename)
    program.pretty('')
  end
else
  program = Program.new(console_io, tokenizers)
  interpreter =
    Interpreter.new(console_io, int_floor, ignore_rnd_arg, randomize)
  shell = Shell.new(console_io, interpreter, program)
  shell.run
end

if show_heading
  console_io.newline
  console_io.print_line('BASIC-1965 ended')
end
