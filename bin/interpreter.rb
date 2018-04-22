# the interpreter
class Interpreter
  attr_reader :current_line_number
  attr_accessor :next_line_number
  attr_reader :console_io
  attr_reader :trace_out

  def initialize(console_io, int_floor, ignore_rnd_arg, randomize,
                 lock_fornext)
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
    @user_var_values = []
    @program_lines = {}
    @variables = {}
    @lock_fornext = lock_fornext
    @locked_variables = []
    @get_value_seen = []
    @null_out = NullOut.new
    @tokenbuilders = make_debug_tokenbuilders
    @breakpoints = {}
  end

  private

  def make_debug_tokenbuilders
    tokenbuilders = []

    keywords = %w(GO STOP STEP BREAK LIST PRETTY DELETE PROFILE DIM GOTO LET PRINT)
    tokenbuilders << ListTokenBuilder.new(keywords, KeywordToken)

    un_ops = UnaryOperator.operators
    bi_ops = BinaryOperator.operators
    operators = (un_ops + bi_ops).uniq
    tokenbuilders << ListTokenBuilder.new(operators, OperatorToken)

    tokenbuilders << BreakTokenBuilder.new

    tokenbuilders << ListTokenBuilder.new(['(', '['], GroupStartToken)
    tokenbuilders << ListTokenBuilder.new([')', ']'], GroupEndToken)
    tokenbuilders << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)

    tokenbuilders <<
      ListTokenBuilder.new(FunctionFactory.function_names, FunctionToken)

    function_names = ('FNA'..'FNZ').to_a
    tokenbuilders << ListTokenBuilder.new(function_names, UserFunctionToken)

    tokenbuilders << TextTokenBuilder.new
    tokenbuilders << NumberTokenBuilder.new
    tokenbuilders << VariableTokenBuilder.new
    tokenbuilders << ListTokenBuilder.new(%w(TRUE FALSE), BooleanConstantToken)
    tokenbuilders << WhitespaceTokenBuilder.new
  end

  def verify_next_line_number
    raise BASICRuntimeError, 'Program terminated without END' if
      @next_line_number.nil?
    line_numbers = @program_lines.keys
    return if line_numbers.include?(@next_line_number)

    raise(BASICRuntimeError, "Line number #{@next_line_number} not found")
  end

  public

  def run(program, trace_flag, show_timing, show_profile)
    if program.empty?
      @console_io.print_line('No program loaded')
      return
    end

    @program = program
    @program_lines = program.lines
    @trace_flag = trace_flag
    @step_mode = false

    # reset profile metrics
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement
      statement.profile_count = 0
      statement.profile_time = 0
    end

    timing = Benchmark.measure { run_and_time }
    print_timing(timing) if show_timing
    if show_profile
      line_list_spec = program.line_list_spec('')
      @program.profile(line_list_spec)
    end
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
  rescue BASICRuntimeError => e
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

  def execute_debug_command(keyword, args, cmd)
    case keyword.to_s
    when 'GO'
      raise(BASICCommandError, 'Too many arguments') unless args.empty?
      @debug_done = true
    when 'STOP'
      raise(BASICCommandError, 'Too many arguments') unless args.empty?
      @debug_done = true
      stop_running
    when 'STEP'
      raise(BASICCommandError, 'Too many arguments') unless args.empty?
      @step_mode = true
      @debug_done = true
    when 'BREAK'
      set_breakpoints(args)
    when 'LIST'
      line_number_range = @program.line_list_spec(args)
      @program.list(line_number_range, false)
    when 'PRETTY'
      line_number_range = @program.line_list_spec(args)
      @program.pretty(line_number_range)
    when 'DELETE'
      line_number_range = @program.line_list_spec(args)
      @program.enblank(line_number_range)
    when 'PROFILE'
      line_number_range = @program.line_list_spec(args)
      @program.profile(line_number_range)
    when 'GOTO'
      statement = GotoStatement.new([keyword], [args])
      if statement.errors.empty?
        statement.execute(self)
      else
        statement.errors.each { |error| puts error }
      end
    when 'LET'
      statement = LetStatement.new([keyword], [args])
      if statement.errors.empty?
        statement.execute(self)
      else
        statement.errors.each { |error| puts error }
      end
    when 'PRINT'
      statement = PrintStatement.new([keyword], [args])
      if statement.errors.empty?
        statement.execute(self)
      else
        statement.errors.each { |error| puts error }
      end
    else
      print "Unknown command #{cmd}\n"
    end
  rescue BASICCommandError => e
    @console_io.print_line(e.to_s)
  end

  def debug_shell
    line = @program_lines[@current_line_number]
    @console_io.newline_when_needed
    @console_io.print_line(@current_line_number.to_s + ': ' + line.pretty)
    @step_mode = false
    @debug_done = false
    until @debug_done
      @console_io.print_line('DEBUG')
      cmd = @console_io.read_line

      # tokenize
      invalid_tokenbuilder = InvalidTokenBuilder.new
      tokenizer = Tokenizer.new(@tokenbuilders, invalid_tokenbuilder)
      tokens = tokenizer.tokenize(cmd)
      tokens.delete_if(&:whitespace?)

      next if tokens.empty?

      keyword = tokens[0]

      if keyword.keyword?
        args = tokens[1..-1]
        execute_debug_command(keyword, args, cmd)
      else
        print "Unknown command #{cmd}\n"
      end
    end
  end

  def program_loop
    # pick the next line number
    @next_line_number = @program.find_next_line_number(@current_line_number)
    next_line_number = nil
    next_line_number = @next_line_number.clone unless @next_line_number.nil?

    # debug shell may change @next_line_number
    debug_shell if @step_mode || @breakpoints.key?(@current_line_number)

    # if next line number has changed, debug_shell executed a GOTO
    if @next_line_number != next_line_number
      @current_line_number = @next_line_number
      @next_line_number = @program.find_next_line_number(@current_line_number)
    end

    begin
      execute_a_statement
      # set the next line number
      @current_line_number = nil
      if @running
        verify_next_line_number
        @current_line_number = @next_line_number
      end
    rescue BASICExpressionError, BASICRuntimeError => e
      if @current_line_number.nil?
        message = e.message
      else
        message = "#{e.message} in line #{@current_line_number}"
      end
      @console_io.print_line(message)
      stop_running
    end
  end

  def split_breakpoint_tokens(tokens)
    tokens_lists = []

    tokens_list = []
    tokens.each do |token|
      if token.separator?
        tokens_lists << tokens_list unless tokens.empty?
        tokens_list = []
      else
        tokens_list << token
      end
    end

    tokens_lists << tokens_list unless tokens.empty?

    tokens_lists
  end

  def set_breakpoints(tokens)
    if tokens.empty?
      # print breakpoints
      bps = @breakpoints.keys.sort.map(&:to_s).join(', ')
      @console_io.print_line('BREAKPOINTS: ' + bps)
    else
      tokens_lists = split_breakpoint_tokens(tokens)
      tokens_lists.each do |tokens_list|
        if tokens_list.size == 1 &&
           tokens_list[0].numeric_constant?
          line_number = LineNumber.new(tokens_list[0])
          condition = ''
          @breakpoints[line_number] = condition
        end
        if tokens_list.size == 2 &&
           tokens_list[0].text == '-' &&
           tokens_list[1].numeric_constant?
          line_number = LineNumber.new(tokens_list[1])
          @breakpoints.delete(line_number)
        end
      end
    end
  end

  def clear_breakpoints
    @breakpoints = {}
  end

  def renumber_breakpoints(renumber_map)
    new_breakpoints = {}

    @breakpoints.each do |line_number, _|
      condition = @breakpoints[line_number]
      new_line_number = renumber_map[line_number]
      new_breakpoints[new_line_number] = condition
    end

    @breakpoints = new_breakpoints
  end

  def line_number?(line_number)
    @program_lines.key?(line_number)
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
      raise(BASICRuntimeError, 'Bad expression') if act != exp

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
    raise(BASICRuntimeError, 'FOR without NEXT') # if none found, error
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
      raise(Exception, "Invalid subscript #{subscript}") unless
        subscript.numeric_constant?
      int_subscripts << subscript.truncate
    end
    int_subscripts
  end

  def get_dimensions(variable)
    @dimensions[variable]
  end

  def set_user_function(name, definition)
    @user_functions[name] = definition
  end

  def get_user_function(name)
    @user_functions[name]
  end

  def define_user_var_values(names_and_values)
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
    raise(BASICRuntimeError, 'Incorrect number of subscripts') if
      int_subscripts.size != dimensions.size
    int_subscripts.zip(dimensions).each do |pair|
      if pair[0] > pair[1]
        raise(BASICRuntimeError, "Subscript #{pair[0]} out of range #{pair[1]}")
      end
    end
  end

  def get_value(variable, trace)
    legals = [
      'VariableName',
      'Value',
      'ScalarValue'
    ]

    raise(Exception, "#{variable.class}:#{variable} is not a variable") unless
      legals.include?(variable.class.to_s)

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
      @trace_out.newline_when_needed
      # TODO: value changes to dict of value and provenence
      @trace_out.print_line(' ' + variable.to_s + ':' + value.to_s)
      @get_value_seen << variable
    end

    value
  end

  def set_value(variable, value)
    legals = [
      'Value',
      'Variable',
      'VariableName',
      'ScalarReference'
    ]
    
    raise(Exception, "#{variable.class}:#{variable} is not a variable name") unless
      legals.include?(variable.class.to_s)

    raise(BASICRuntimeError, "Cannot change locked variable #{variable}") if
      @lock_fornext && @locked_variables.include?(variable)

    # check that value type matches variable type
    if value.class.to_s != variable.content_type
      raise(BASICRuntimeError,
            "Type mismatch '#{value}' is not #{variable.content_type}")
    end

    v = variable.to_s
    @variables[v] = value
    @trace_out.newline_when_needed
    @trace_out.print_line(' ' + variable.to_s + ' = ' + value.to_s)
  end

  def set_values(name, values)
    values.each do |coords, value|
      variable = Variable.new(name, coords)
      set_value(variable, value)
    end
  end

  def lock_variable(variable)
    return unless @lock_fornext
    if @locked_variables.include?(variable)
      raise(BASICExeption,
            "Attempt to lock an already locked variable #{variable}")
    end
    @locked_variables << variable
  end

  def unlock_variable(variable)
    return unless @lock_fornext
    unless @locked_variables.include?(variable)
      raise(BASICRuntimeError,
            "Attempt to unlock a variable #{variable} not locked")
    end
    @locked_variables.delete(variable)
  end

  def push_return(destination)
    @return_stack.push(destination)
  end

  def pop_return
    raise(BASICRuntimeError, 'RETURN without GOSUB') if @return_stack.empty?
    @return_stack.pop
  end

  def assign_fornext(fornext_control)
    control_variable = fornext_control.control
    @fornexts[control_variable] = fornext_control
  end

  def retrieve_fornext(control_variable)
    fornext = @fornexts[control_variable]
    raise(BASICRuntimeError, 'NEXT without FOR') if fornext.nil?
    fornext
  end

  def add_file_names(file_names)
    file_names.each do |name|
      raise(BASICRuntimeError, 'Invalid file name') unless
        name.class.to_s == 'TextConstant'
      raise(BASICRuntimeError, "File '#{name.value}' not found") unless
        File.file?(name.value)
      file_handle = FileHandle.new(@file_handlers.size + 1)
      @file_handlers[file_handle] = FileHandler.new(name.value)
    end
  end

  def get_file_handler(file_handle, mode)
    return @console_io if file_handle.nil?

    raise(BASICRuntimeError, 'Unknown file handle') unless
      @file_handlers.key?(file_handle)
    fh = @file_handlers[file_handle]
    fh.set_mode(mode)
    fh
  end

  def get_data_store(file_handle)
    return @data_store if file_handle.nil?

    raise(BASICRuntimeError, 'Unknown file handle') unless
      @file_handlers.key?(file_handle)
    fh = @file_handlers[file_handle]
    fh.set_mode(:read)
    fh
  end

  def int_floor?
    @int_floor
  end
end
