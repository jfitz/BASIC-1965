# Helper class for FOR/NEXT
class ForNextControl
  attr_reader :control
  attr_reader :loop_start_number
  attr_reader :end

  def initialize(control, start, endv, step, loop_start_number)
    @control = control
    @start = start
    @end = endv
    @step = step
    @loop_start_number = loop_start_number
  end

  def bump_control(interpreter)
    current_value = interpreter.get_value(@control)
    current_value += @step
    interpreter.unlock_variable(@control)
    interpreter.set_value(@control, current_value)
    interpreter.lock_variable(@control)
  end

  def front_terminated?
    zero = NumericConstant.new(0)

    if @step > zero
      @start > @end
    elsif @step < zero
      @start < @end
    else
      false
    end
  end

  def terminated?(interpreter)
    zero = NumericConstant.new(0)
    current_value = interpreter.get_value(@control)

    if @step > zero
      current_value + @step > @end
    elsif @step < zero
      current_value + @step < @end
    else
      false
    end
  end
end

# the interpreter
class Interpreter
  attr_writer :program
  attr_reader :current_line_number
  attr_accessor :next_line_number
  attr_reader :console_io
  attr_reader :trace_out

  def initialize(console_io)
    @randomizer = Random.new(1)
    randomize_option = $options['randomize']
    @randomizer = Random.new if randomize_option.value

    @tokenbuilders = make_debug_tokenbuilders
    @console_io = console_io

    @data_store = DataStore.new
    @file_handlers = {}
    @return_stack = []
    @fornexts = {}
    @dimensions = {}
    @default_args = {}
    @user_functions = {}
    @user_var_values = []
    @variables = {}
    @locked_variables = []
    @fornext_stack = []
    @get_value_seen = []
    @null_out = NullOut.new
    @line_breakpoints = {}
    @line_cond_breakpoints = {}
    @running = false
  end

  private

  def make_debug_tokenbuilders
    tokenbuilders = []

    keywords =
      %w[
        GO STOP STEP BREAK NOBREAK
        LIST PRETTY DELETE PROFILE
        DIM GOTO LET PRINT
      ]

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
    tokenbuilders << ListTokenBuilder.new(%w[TRUE FALSE], BooleanConstantToken)
    tokenbuilders << WhitespaceTokenBuilder.new
  end

  def verify_next_line_number
    raise BASICSyntaxError, 'Program terminated without END' if
      @next_line_number.nil?

    return if @program.line_number?(@next_line_number)

    raise(BASICSyntaxError, "Line number #{@next_line_number} not found")
  end

  public

  def program_new
    @program.clear
  end

  def program_okay?
    @program.okay?
  end

  def program_parse(args)
    @program.parse(args)
  end
  
  def program_list(args, list_tokens)
    @program.list(args, list_tokens)
  end
  
  def program_pretty(args)
    @program.pretty(args)
  end
  
  def program_delete(args)
    @program.delete(args)
  end
  
  def program_profile(args, show_timing)
    @program.profile(args, show_timing)
  end
  
  def program_crossref
    @program.crossref
  end
  
  def program_analyze
    @program.analyze
  end

  def program_renumber(args)
    renumber_map = @program.renumber(args)
    renumber_breakpoints(renumber_map)
  end

  def program_store_line(line, print_errors)
    @program.store_line(line, print_errors)
  end

  def program_clear
    @program.clear
  end

  def program_check
    errors = @program.check
    errors.empty?
  end

  def print_program_errors
    errors = @program.errors

    errors.each { |error| @console_io.print_line(error) }
  end

  def program_save
    @program.save
  end
  
  def run
    raise(BASICCommandError, 'No program loaded') if @program.empty?

    unless @program.errors.empty?
      text = @program.errors.join('\n')
      raise(BASICCommandError, text)
    end
    
    # if breakpoint error, raise error
    errors = check_breakpoints(@program.lines)

    unless errors.empty?
      text = errors.join('\n')
      raise(BASICCommandError, text)
    end

    @program.reset_profile_metrics

    @step_mode = false
    trace = $options['trace'].value
    @trace_out = trace ? @console_io : @null_out

    @variables = {}

    clear_previous_lines
    run_program
  end

  def run_program
    run_statements if @program.preexecute_loop(self)
  end

  def run_statements
    # run each statement
    # start with the first line number
    @current_line_number = @program.first_line_number
    @running = true

    begin
      program_loop while @running
    rescue Interrupt
      stop_running
    end

    @file_handlers.each { |_, fh| fh.close }
  end

  def print_errors(line_number, statement)
    @console_io.print_line("Errors in line #{line_number}:")
    statement.print_errors(@console_io)
  end

  def execute_a_statement
    detect = $options['detect_infinite_loop'].value

    raise(BASICSyntaxError, 'Infinite loop detected') if
      detect && @previous_line_numbers.include?(@current_line_number)

    @previous_line_numbers << @current_line_number

    line = @program.lines[@current_line_number]
    statement = line.statement

    statement.print_trace_info(@trace_out, @current_line_number)
    statement.execute_a_statement(self, @current_line_number)
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
    when 'NOBREAK'
      clear_breakpoints(args)
    when 'LIST'
      @program.list(args, false)
    when 'PRETTY'
      @program.pretty(args)
    when 'DELETE'
      @program.enblank(args)
    when 'PROFILE'
      @program.profile(args)
    when 'GOTO'
      statement = GotoStatement.new([keyword], [args])
      if statement.errors.empty?
        statement.execute(self)
      else
        statement.errors.each { |error| @console_io.print_line(error) }
      end
    when 'LET'
      statement = LetStatement.new([keyword], [args])
      if statement.errors.empty?
        statement.execute(self)
      else
        statement.errors.each { |error| @console_io.print_line(error) }
      end
    when 'PRINT'
      statement = PrintStatement.new([keyword], [args])
      if statement.errors.empty?
        statement.execute(self)
      else
        statement.errors.each { |error| @console_io.print_line(error) }
      end
    else
      print "Unknown command #{cmd}\n"
    end
  rescue BASICCommandError => e
    @console_io.print_line(e.to_s)
  end

  def debug_shell
    line = @program.lines[@current_line_number]
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

    # breakpoint may have already been set by another test
    breakpoint = false

    # look for line breakpoint
    if @line_breakpoints.key?(@current_line_number)
      breakpoint = true
    end

    if !breakpoint
      if @line_cond_breakpoints.key?(@current_line_number)
        expressions = @line_cond_breakpoints[@current_line_number]

        expressions.each do |expression|
          results = expression.evaluate(self)
          result = results[0]
          if result.value
            breakpoint = true
          end
        end
      end
    end

    # check step mode
    if @step_mode
      breakpoint = true
    end

    # debug shell may change @next_line_number
    debug_shell if breakpoint

    # if next line number has changed, debug_shell executed a GOTO
    if @next_line_number != next_line_number
      @current_line_number = @next_line_number
      @next_line_number = @program.find_next_line_number(@current_line_number)
    end

    begin
      execute_a_statement
      @get_value_seen = []

      # set the next line number
      @current_line_number = nil

      if @running
        verify_next_line_number
        @current_line_number = @next_line_number
      end
    rescue BASICTrappableError => e
      @console_io.newline_when_needed

      if @current_line_number.nil?
        @console_io.print_line(e.message)
      else
        @console_io.print_line("Error #{e.code} #{e.message} in line #{@current_line_number}")
      end

      stop_running
    rescue BASICSyntaxError => e
      @console_io.newline_when_needed

      if @current_line_number.nil?
        @console_io.print_line(e.message)
      else
        @console_io.print_line("#{e.message} in line #{@current_line_number}")
      end

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
      @line_breakpoints.keys.sort.each do |line|
        @console_io.print_line(line.to_s)
      end
      @line_cond_breakpoints.keys.sort.each do |line|
        expressions = @line_cond_breakpoints[line]
        expressions.each do |expression|
          @console_io.print_line("#{line} IF #{expression}")
        end
      end
    else
      # kinds of breakpoints
      #  line - break before execution of line
      #  line condition - break before line if condition is true
      #  condition - break on any line if condition is true
      #  variable - break when contents change
      tokens_lists = split_breakpoint_tokens(tokens)
      tokens_lists.each do |tokens_list|
        if tokens_list.size == 1 &&
          begin
            line_number = LineNumber.new(tokens_list[0])
            @line_breakpoints[line_number] = ''
          rescue BASICSyntaxError => e
            tkns = tokens_list.map(&:to_s).join
            @console_io.print_line('INVALID BREAKPOINT ' + tkns)
          end
        else # tokens_list.size > 1
          begin
            line_number = LineNumber.new(tokens_list[0])

            raise(BASICSyntaxError, 'Invalid expression') unless
              tokens_list[1].keyword? && tokens_list[1].to_s == 'IF'

            raise(BASICExpressionError, 'Empty expression') unless
              tokens_list.size > 2
            
            expr_tokens = tokens_list[2..-1]
            expression = ValueExpression.new(expr_tokens, :scalar)
            if @line_cond_breakpoints.key?(line_number)
              @line_cond_breakpoints[line_number] << expression
            else
              @line_cond_breakpoints[line_number] = [expression]
            end
          rescue BASICSyntaxError, BASICExpressionError => e
            tkns = tokens_list.map(&:to_s).join
            @console_io.print_line('INVALID BREAKPOINT ' + tkns)
          end
        end
      end
    end
  end

  def clear_breakpoints(tokens)
    if tokens.empty?
      # print breakpoints
      @line_breakpoints.keys.sort.each do |line|
        condition = @line_breakpoints[line]
        @console_io.print_line(line.to_s + ': ' + condition)
      end
    else
      tokens_lists = split_breakpoint_tokens(tokens)
      tokens_lists.each do |tokens_list|
        if tokens_list.size == 1
          begin
            line_number = LineNumber.new(tokens_list[0])
            @line_breakpoints.delete(line_number)
            @line_cond_breakpoints.delete(line_number)
          rescue BASICSyntaxError => e
            tkns = tokens_list.map(&:to_s).join
            @console_io.print_line('INVALID BREAKPOINT ' + tkns)
          end
        else
          # TODO: remove a conditional breakpoint
          tkns = tokens_list.map(&:to_s).join
          @console_io.print_line('INVALID BREAKPOINT ' + tkns)
        end
      end
    end
  end

  def clear_all_breakpoints
    @line_breakpoints = {}
    @line_cond_breakpoints = {}
  end

  def check_breakpoints(lines)
    errors = []

    @line_breakpoints.keys.each do |bp_line|
      errors << 'Breakpoint for non-existent line ' + bp_line.to_s unless
        lines.key?(bp_line)
    end

    @line_cond_breakpoints.keys.each do |bp_line|
      errors << 'Breakpoint for non-existent line ' + bp_line.to_s unless
        lines.key?(bp_line)
    end

    errors
  end

  def renumber_breakpoints(renumber_map)
    new_breakpoints = {}

    @line_breakpoints.each do |line_number, _|
      condition = @line_breakpoints[line_number]
      new_line_number = renumber_map[line_number]
      new_breakpoints[new_line_number] = condition
    end

    @line_breakpoints = new_breakpoints
  end

  def line_number?(line_number)
    @program.line_number?(line_number)
  end

  def set_action(name, value)
    $options[name].set(value)
    if name == 'trace'
      @trace_out = value ? @console_io : @null_out
    end
  end

  def clear_variables
    @variables = {}
  end

  # get default arguments
  def default_args(name)
    @default_args[name]
  end

  def set_default_args(name, args)
    @default_args[name] = args
  end

  # returns an Array of values
  def evaluate(parsed_expressions)
    result_values = []

    parsed_expressions.each do |parsed_expression|
      stack = []
      exp = parsed_expression.empty? ? 0 : 1

      parsed_expression.each do |element|
        value = element.evaluate(self, stack)
        stack.push value
      end

      act = stack.length

      raise(BASICExpressionError, 'Bad expression') if act != exp

      next if act.zero?

      # verify each item is of correct type
      item = stack[0]
      result_values << item
    end

    result_values
  end

  def dump_vars
    @variables.each do |name, dict|
      value = dict['value']
      @console_io.print_line("#{name}: #{value}")
    end

    @console_io.newline
  end

  def dump_user_functions
    @user_functions.each do |name, expression|
      @console_io.print_line("#{name}: #{expression}")
    end

    @console_io.newline
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
    upper_bound = 1 if $options['ignore_rnd_arg'].value
    upper_bound = upper_bound.to_f

    clear_previous_lines

    NumericConstant.new(@randomizer.rand(upper_bound))
  end

  def find_closing_next(control)
    @program.find_closing_next(control, @current_line_number)
  end

  def set_dimensions(variable, subscripts)
    name = variable.name
    int_subscripts = normalize_subscripts(subscripts)
    @dimensions[name] = int_subscripts
  end

  def normalize_subscripts(subscripts)
    raise(BASICSyntaxError, 'Invalid subscripts container') unless
      subscripts.class.to_s == 'Array'

    int_subscripts = []

    subscripts.each do |subscript|
      raise(BASICExpressionError, "Invalid subscript #{subscript}") unless
        subscript.numeric_constant?

      int_subscripts << subscript.truncate
    end

    int_subscripts
  end

  def get_dimensions(variable)
    @dimensions[variable]
  end

  def set_user_function(name, signature, definition)
    sig = signature.join(',')
    tag = name.to_s + '(' + sig + ')'

    raise BASICRuntimeError.new(:te_func_alr, tag) if
      @user_functions.key?(tag)

    @user_functions[tag] = definition
  end

  def get_user_function(name, signature)
    sig = signature.join(',')
    tag = name.to_s + '(' + sig + ')'

    raise BASICRuntimeError.new(:te_func_no, tag) unless
      @user_functions.key?(tag)

    @user_functions[tag]
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

    raise(BASICSyntaxError, 'Incorrect number of subscripts') if
      int_subscripts.size != dimensions.size

    # lower bound
    lower_value = $options['base'].value
    lower = NumericConstant.new(lower_value)

    # check subscript value against lower and upper bounds
    int_subscripts.zip(dimensions).each do |pair|
      if pair[0] < lower
        raise BASICRuntimeError.new(:te_subscript_out, pair[0].to_s)
      end

      if pair[0] > pair[1]
        raise BASICRuntimeError.new(:te_subscript_out, pair[0].to_s)
      end
    end
  end

  def get_value(variable)
    legals = [
      'Variable'
    ]

    raise(BASICSyntaxError,
          "#{variable.class}:#{variable} is not a variable") unless
      legals.include?(variable.class.to_s)

    value = nil
    # first look in user function values stack
    length = @user_var_values.length

    if length > 0
      names_and_values = @user_var_values[-1]
      value = names_and_values[variable.name]
    end

    # then look in general table
    if value.nil?
      v = variable.to_s
      unless @variables.key?(v)
        if $options['require_initialized'].value
          raise BASICRuntimeError.new(:te_var_uninin, v.to_s)
        end

        # define a value for this variable
        @variables[v] =
          {
            'provenance' => @current_line_number,
            'value' => NumericConstant.new(0)
          }
      end

      dict = @variables[v]
      value = dict['value']
      provenance = dict['provenance']

      seen = @get_value_seen.include?(variable)
    end

    trace = $options['trace'].value

    if trace && !seen
      provenance_option = $options['provenance'].value

      if provenance_option && !provenance.nil?
        text = ' ' + variable.to_s + ': (' + provenance.to_s + ') ' + value.to_s
      else
        text = ' ' + variable.to_s + ': ' + value.to_s
      end

      @trace_out.newline_when_needed
      @trace_out.print_line(text)
      @get_value_seen << variable
    end

    value
  end

  def set_value(variable, value)
    legals = [
      'Variable'
    ]

    raise(BASICSyntaxError,
          "#{variable.class}:#{variable} is not a variable name") unless
      legals.include?(variable.class.to_s)

    raise(BASICSyntaxError,
          "#{variable.class}:#{variable} is not a scalar variable name") if
      variable.class.to_s == 'VariableName' && !variable.scalar?

    if $options['lock_fornext'].value &&
       @locked_variables.include?(variable)
      raise BASICRuntimeError.new(:te_var_locked, variable.to_s)
    end

    # check that value type matches variable type
    unless variable.compatible?(value)
      raise(BASICSyntaxError,
            "Type mismatch '#{value}' is not #{variable.content_type}")
    end

    v = variable.to_s

    if @variables.key?(v)
      dict = @variables[v]
      old_value = dict['value']
      old_provenance = dict['provenance']
      # a different value resets 'infinite loop' check
      if value != old_value || @current_line_number != old_provenance
        @previous_line_numbers = []
      end
    else
      # no prior value is a new value
      clear_previous_lines
    end

    dict = { 'provenance' => @current_line_number, 'value' => value }
    @variables[v] = dict

    @trace_out.newline_when_needed
    @trace_out.print_line(' ' + variable.to_s + ' = ' + value.to_s)
  end

  def set_values(name, values)
    values.each do |coords, value|
      shape = :scalar
      shape = :array if coords.size == 1
      shape = :matrix if coords.size == 2
      variable = Variable.new(name, shape, coords)
      set_value(variable, value)
    end
  end

  def clear_previous_lines
    @previous_line_numbers = []
  end

  def lock_variable(variable)
    return unless $options['lock_fornext'].value

    if @locked_variables.include?(variable)
      raise BASICRuntimeError.new(:te_var_locked2, variable.to_s)
    end

    @locked_variables << variable
  end

  def unlock_variable(variable)
    return unless $options['lock_fornext'].value

    unless @locked_variables.include?(variable)
      raise BASICRuntimeError.new(:te_var_no_lock, variable.to_s)
    end

    @locked_variables.delete(variable)
  end

  def push_return(destination)
    @return_stack.push(destination)
  end

  def pop_return
    raise BASICRuntimeError.new(:te_ret_no_gos) if @return_stack.empty?

    # remove all lines from the subroutine in the 'visited' list
    while !@previous_line_numbers.empty? &&
          @previous_line_numbers[-1] != @return_stack[-1]
      @previous_line_numbers.pop
    end

    @return_stack.pop
  end

  def assign_fornext(control, from, to, step)
    fornext_control =
      ForNextControl.new(control, from, to, step, @next_line_number)

    @fornexts[control] = fornext_control
    set_value(control, from)

    fornext_control
  end

  def retrieve_fornext(control)
    fornext = @fornexts[control]

    raise BASICRuntimeError.new(:te_next_no_for) if fornext.nil?

    fornext
  end

  def enter_fornext(variable)
    @fornext_stack.push(variable)
  end

  def exit_fornext
    @fornext_stack.pop
  end

  def top_fornext
    raise BASICRuntimeError.new(:te_inext_no_for) if
      @fornext_stack.empty?

    @fornext_stack[-1]
  end

  def add_file_names(file_names)
    file_names.each do |name|
      raise BASICRuntimeError.new(:te_fname_inv, name.to_s) unless
        name.text_constant?

      raise BASICRuntimeError.new(:te_file_no_fnd, name.value.to_s) unless
        File.file?(name.value)

      file_handle = FileHandle.new(@file_handlers.size + 1)
      @file_handlers[file_handle] = FileHandler.new(name.value)
    end
  end

  def get_file_handler(file_handle, mode)
    return @console_io if file_handle.nil?

    raise BASICRuntimeError.new(:te_fh_unk) unless
      @file_handlers.key?(file_handle)

    fh = @file_handlers[file_handle]
    fh.set_mode(mode)
    fh
  end

  def get_data_store(file_handle)
    return @data_store if file_handle.nil?

    raise BASICRuntimeError.new(:te_fh_unk) unless
      @file_handlers.key?(file_handle)

    fh = @file_handlers[file_handle]
    fh.set_mode(:read)
    fh
  end

  def int_floor?
    $options['int_floor'].value
  end

  def match_fornext?
    $options['match_fornext'].value
  end

  def base
    $options['base'].value
  end
end
