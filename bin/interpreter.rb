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
    return if line_numbers.include?(@next_line_number)

    raise(BASICException, "Line number #{@next_line_number} not found")
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
    print_timing(timing) if show_timing
  end

  def run_and_time
    # run the program
    @variables = {}
    @trace_out = @trace_flag ? @console_io : @null_out
    @running = true
    run_phase_1
    run_phase_2 if @running
  end

  def print_timing(timing)
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
      @current_line_number =
        @program.find_next_line_number(@current_line_number)
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

  def line_number?(line_number)
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
