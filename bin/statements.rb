# frozen_string_literal: true

# class for for-next marker
class ForNextMarker
  attr_reader :control_variable, :line_stmt

  def initialize(control_variable, line_stmt)
    @control_variable = control_variable
    @line_stmt = line_stmt
  end

  def hash
    @control_variable.hash ^ @line_stmt.hash
  end

  def eql?(other)
    @control_variable == other.control_variable && @line_stmt == other.line_stmt
  end

  def ==(other)
    @control_variable == other.control_variable && @line_stmt == other.line_stmt
  end

  def <=>(other)
    return @line_stmt <=> other.line_stmt if
      @control_variable == other.control_variable

    @control_variable <=> other.control_variable
  end

  def to_s
    "#{@control_variable}:#{@line_stmt}"
  end
  
end

# parent of all statement classes
class AbstractStatement
  attr_reader :errors, :warnings, :program_errors, :keywords, :tokens,
              :separators, :valid, :executable, :comment, :linenums,
              :autonext, :autonext_line_stmt, :transfers,
              :comprehension_effort, :mccabe, :part_of_sub, :part_of_onerror,
              :part_of_fornext
  attr_accessor :part_of_user_function, :program_warnings, :origins,
                :reachable, :visited

  def initialize(_, keywords, tokens_lists)
    @keywords = keywords
    @executable = :run
    @tokens = tokens_lists.flatten
    @separators = get_separators(@tokens)
    @errors = []
    @warnings = []
    @program_errors = []
    @program_warnings = []
    @valid = true
    @comment = false
    @modifiers = []
    @elements = {
      numerics: [],
      strings: [],
      booleans: [],
      variables: [],
      operators: [],
      functions: [],
      userfuncs: []
    }
    @linenums = []
    @autonext = true
    @comprehension_effort = 1
    @mccabe = 0
    @profile_count = 0
    @profile_time = 0
    @transfers = []
    @part_of_user_function = nil
    @part_of_sub = []
    @part_of_onerror = []
    @part_of_fornext = []
  end

  def set_autonext_line_stmt(line_stmt_mod)
    @autonext_line_stmt = line_stmt_mod
  end

  def set_autonext_line(line_stmt_mod)
    @autonext_line = line_stmt_mod
  end

  def reset
    @program_errors = []
    @program_warnings = []
    @transfers = []
    @origins = []
    @part_of_user_function = nil
    @part_of_sub = []
    @part_of_onerror = []
    @part_of_fornext = []
  end

  def set_destinations(_, _, _) end

  def assign_sub_markers(_) end

  def assign_sub_marker(marker, line_number, program)
    return if @visited == marker
    @visited = marker

    # mark as part of this sub
    @part_of_sub << marker

    # for each destination
    @transfers.each do |xfer|
      # don't follow function call and GOSUB
      next if [:function, :gosub].include?(xfer.type)

      statement = program.get_statement(xfer)

      next if statement.nil?

      if !statement.part_of_sub.include?(marker)
        # recurse for that statement's destinations
        dest_line = xfer.line_number
        statement.assign_sub_marker(marker, dest_line, program)
      end
    end
  end

  def assign_on_error_markers(_) end

  def assign_on_error_marker(marker, line_number, program)
    return if @visited == marker
    @visited = marker

    # mark as part of this on-error
    @part_of_onerror << marker

    # for each destination
    @transfers.each do |xfer|
      # don't follow function call, ON ERROR, and RESUME
      next if [:function, :onerror, :resume].include?(xfer.type)

      statement = program.get_statement(xfer)

      next if statement.nil?

      if !statement.part_of_onerror.include?(marker)
        # recurse for that statement's destinations
        dest_line = xfer.line_number
        statement.assign_on_error_marker(marker, dest_line, program)
      end
    end
  end

  def assign_fornext_markers(_, _) end

  def assign_fornext_marker(marker)
    @part_of_fornext << marker
  end

  def set_endfunc_lines(_, _) end

  def define_user_functions(_) end

  def load_data(_) end

  def load_file_names(_) end

  def renumber(_) end

  def set_transfers(_) end

  def set_transfers_auto(program, line_number, stmt)
    # convert auto-next to TransferRefLineStmt
    if @autonext &&
       @autonext_line_stmt &&
       [:run, :def_fn].include?(@executable)
      dest_line_number = @autonext_line_stmt.line_number
      dest_stmt = @autonext_line_stmt.statement

      @transfers <<
        TransferRefLineStmt.new(dest_line_number, dest_stmt, :auto)
    end
  end

  def transfers_to_origins(program, line_number, stmt)
    @transfers.each do |xfer|
      dest_line_number = xfer.line_number
      dest_stmt = xfer.statement
      dest_xfer = TransferRefLineStmt.new(line_number, stmt, xfer.type)
      program.add_statement_origin(dest_line_number, dest_stmt, dest_xfer)
    end
  end

  def uncache; end

  def reset_profile_metrics
    @profile_count = 0
    @profile_time = 0
  end

  def pretty
    AbstractToken.pretty_tokens(@keywords, @tokens)
  end

  def markers
    text = ''

    text += " #{@part_of_user_function}" unless @part_of_user_function.nil?

    text += " E(#{@part_of_onerror.map(&:to_s).join(',')})" unless
      @part_of_onerror.empty?

    text += " G(#{@part_of_sub.map(&:to_s).join(',')})" unless
      @part_of_sub.empty?

    text += " F(#{@part_of_fornext.map(&:to_s).join(',')})" unless
      @part_of_fornext.empty?

    text
  end

  def analyze(number)
    texts = []

    text = "#{number}#{markers}"

    text += " (#{@mccabe} #{@comprehension_effort}) #{pretty}"

    texts << text

    texts
  end

  def dump
    ['Unimplemented']
  end

  def numerics
    @elements[:numerics]
  end

  def strings
    @elements[:strings]
  end

  def booleans
    @elements[:booleans]
  end

  def variables
    @elements[:variables]
  end

  def operators
    @elements[:operators]
  end

  def functions
    @elements[:functions]
  end

  def userfuncs
    @elements[:userfuncs]
  end

  def modifier_numerics
    []
  end

  def modifier_strings
    []
  end

  def modifier_booleans
    []
  end

  def modifier_variables
    []
  end

  def modifier_operators
    []
  end

  def modifier_functions
    []
  end

  def modifier_userfuncs
    []
  end

  def stop?
    false
  end

  def end?
    false
  end

  def for?
    false
  end

  def next?
    false
  end

  def user_def?
    false
  end

  def end_user_def?
    false
  end

  def procedure?
    is_proc = false

    # a procedure start is any line with a :gosub origin
    @origins.each do |xfer|
      is_proc = true if !xfer.line_number.nil? && xfer.type == :gosub
    end

    is_proc
  end

  def print_errors(console_io)
    @errors.each { |error| console_io.print_line(" #{error}") }
  end

  def errors?
    !@errors.empty? || !@program_errors.empty?
  end

  def check_gosub_origins
    # check all origins are consistent for GOSUB
    any_gosub = false
    any_other = false

    @origins.each do |origin|
      any_gosub = true if origin.type == :gosub
      any_other = true if origin.type != :gosub
    end

    @program_warnings << 'Inconsistent GOSUB origins' if any_gosub && any_other
  end

  def check_gosub_single
    return if @part_of_sub.empty?

    # warn about multiple origins for a GOSUB block
    if @part_of_sub.size > 1
      @program_warnings << "Multiple GOSUB entry points"
    end
  end

  def check_gosub_early(line_number)
    return if @part_of_sub.empty?

    # warn about lines before first line of GOSUB block
    @transfers.each do |xfer|
      if [:goto, :ifthen].include?(xfer.type)
        dest_line_number = xfer.line_number
      
        if dest_line_number < @part_of_sub.min &&
           dest_line_number < line_number
          @program_warnings << "Branch to line before GOSUB start"
        end
      end
    end
  end

  def check_onerror_origins
    # check all origins are consistent for ON ERROR
    any_on_error = false
    any_other = false

    @origins.each do |origin|
      any_on_error = true if origin.type == :onerror
      any_other = true if origin.type != :onerror
    end

    @program_warnings << 'Inconsistent ON-ERROR origins' if any_on_error && any_other
  end

  def check_onerror_single
    return if @part_of_onerror.empty?

    # warn about multiple origins for an ON-ERROR block
    if @part_of_onerror.size > 1
      @program_warnings << "Multiple ON-ERROR entry points"
    end
  end

  def check_onerror_early(line_number)
    return if @part_of_onerror.empty?

    # warn about branches to lines before first line of ON-ERROR block
    @transfers.each do |xfer|
      if [:goto, :ifthen].include?(xfer.type)
        dest_line_number = xfer.line_number
      
        if dest_line_number < @part_of_onerror.min &&
           dest_line_number < line_number
          @program_warnings << "Branch to line before ON-ERROR start"
        end
      end
    end
  end

  def check_terminating_in_gosub
    return if @part_of_sub.empty?

    # warn about STOP, END, CHAIN in GOSUB block
    @transfers.each do |xfer|
      if [:stop, :chain].include?(xfer.type)
        @program_warnings << "Terminating statement in GOSUB"
      end
    end
  end

  def check_terminating_in_onerror
    return if @part_of_onerror.empty?

    # warn about STOP, END, CHAIN in ON-ERROR block
    @transfers.each do |xfer|
      if [:stop, :chain].include?(xfer.type)
        @program_warnings << "Terminating statement in ON-ERROR"
      end
    end
  end

  def check_terminating_in_fornext
    return if @part_of_fornext.empty?

    # warn about STOP, END, CHAIN in FORNEXT block
    @transfers.each do |xfer|
      if [:stop, :chain].include?(xfer.type)
        @program_warnings << "Terminating statement in FOR/NEXT"
      end
    end
  end

  def check_destinations_fornext(_, _)
  end

  def check_destination_fornext(program, line_stmt, dest_line_stmt)
    return if dest_line_stmt.nil?

    dest_statement = program.get_statement(dest_line_stmt)

    return if dest_statement.nil?

    dest_part_of_fornext = dest_statement.part_of_fornext_short(dest_line_stmt)
    dest_line_number = dest_line_stmt.line_number

    @program_warnings << "Transfer in/out of FOR/NEXT #{dest_line_number}" if
      dest_part_of_fornext != @part_of_fornext
  end

  def check_program(_, _)
  end

  def number_for_stmts
    0
  end

  def profile(show_timing)
    texts = []

    text = markers

    text += if show_timing
              " (#{@profile_time.round(4)}/#{@profile_count})"
            else
              " (#{@profile_count})"
            end

    text += " #{AbstractToken.pretty_tokens(@keywords, @tokens)}"

    texts << text

    texts
  end

  def trace_info(current_line_stmt_mod)
    texts = []

    text = "#{current_line_stmt_mod}#{markers}"

    text += " #{pretty}"

    texts << text

    texts
  end

  def execute_a_statement(interpreter, _current_line_stmt_mod)
    current_user_function = interpreter.current_user_function

    if @part_of_user_function != current_user_function
      raise(BASICSyntaxError, 'Invalid transfer in/out of function')
    end

    # TODO: check for consistent SUB

    execute(interpreter)
  end

  def start_index
    0 - @modifiers.size
  end

  def last_index
    @modifiers.size
  end

  def singledef?
    false
  end

  def multidef?
    false
  end

  def multiend?
    false
  end

  def part_of_fornext_short(_)
    @part_of_fornext
  end

  protected

  def check_template(tokens_lists, template)
    return false unless tokens_lists.size == template.size

    result = true
    pairs = template.zip(tokens_lists)

    pairs.each do |pair|
      control = pair[0]
      value = pair[1]

      if control.class.to_s == 'Array' &&
         value.class.to_s == 'Array'

        # control array and value array implies an expression
        result &= value.size == control[0] if control.size == 1

        result &= value.size >= control[0] if
          control.size == 2 && control[1] == '>='

      elsif control.class.to_s == 'Array' &&
            value.class.to_s == 'KeywordToken'

        # control array and single value (not array of one) implies
        # multiple possible keywords
        result &= control.include?(value.to_s)

      elsif control.class.to_s == 'String' &&
            value.class.to_s == 'KeywordToken'

        # single control and single value is a specific keyword
        result &= value.to_s == control

      else
        result = false
      end
    end

    result
  end

  def split_tokens(tokens, want_separators)
    lists = []
    list = []
    parens_level = 0

    tokens.each do |token|
      if token.operand? &&
         (!list.empty? && (list[-1].operand? || list[-1].group_end?))
        lists << list unless list.empty?
        list = [token]
      elsif token.separator? && parens_level.zero?
        lists << list unless list.empty?
        lists << token if want_separators
        list = []
      else
        list << token
      end

      parens_level += 1 if token.group_start?
      parens_level -= 1 if token.group_end? && !parens_level.zero?
    end

    lists << list unless list.empty?

    lists
  end

  def split_on_token(tokens, token_to_split)
    results = []
    list = []

    tokens.each do |token|
      if token.to_s == token_to_split
        results << list unless list.empty?
        list = []
        results << token
      else
        list << token
      end
    end

    results << list unless list.empty?

    results
  end

  def split_on_group_separators(tokens)
    tokens_lists = []
    statement_tokens = []

    # set to TRUE, so an empty list creates one empty token
    last_was_separator = true

    tokens.each do |token|
      if token.separator?
        tokens_lists << statement_tokens
        statement_tokens = []
        last_was_separator = true
      else
        statement_tokens << token
        last_was_separator = false
      end
    end

    tokens_lists << statement_tokens if
      !statement_tokens.empty? || last_was_separator
    tokens_lists
  end

  def make_references(items, exp1 = nil, exp2 = nil)
    numerics = []
    strings = []
    booleans = []
    variables = []
    operators = []
    functions = []
    userfuncs = []

    unless exp1.nil?
      numerics += exp1.numerics
      strings += exp1.strings
      booleans += exp1.booleans
      variables += exp1.variables
      operators += exp1.operators
      functions += exp1.functions
      userfuncs += exp1.userfuncs
    end

    unless exp2.nil?
      numerics += exp2.numerics
      strings += exp2.strings
      booleans += exp2.booleans
      variables += exp2.variables
      operators += exp2.operators
      functions += exp2.functions
      userfuncs += exp2.userfuncs
    end

    unless items.nil?
      items.each { |item| numerics += item.numerics }
      items.each { |item| strings += item.strings }
      items.each { |item| booleans += item.booleans }
      items.each { |item| variables += item.variables }
      items.each { |item| operators += item.operators }
      items.each { |item| functions += item.functions }
      items.each { |item| userfuncs += item.userfuncs }
    end

    {
      numerics: numerics,
      strings: strings,
      booleans: booleans,
      variables: variables,
      operators: operators,
      functions: functions,
      userfuncs: userfuncs
    }
  end

  private

  def execute(interpreter)
    timing = Benchmark.measure { execute_core(interpreter) }

    user_time = timing.utime + timing.cutime
    sys_time = timing.stime + timing.cstime
    time = user_time + sys_time

    @profile_time += time
    @profile_count += 1
  end

  def get_separators(tokens)
    wanted = ['(', ')', '[', ']', ',', ';']

    separators = []

    tokens.each do |token|
      separators << token if wanted.include?(token.to_s)
    end

    separators
  end
end

# unparsed statement
class InvalidStatement < AbstractStatement
  def initialize(line_number, text, tokens_lists, error)
    super(line_number, [], tokens_lists)

    @valid = false
    @executable = :none
    @text = text
    @errors << ("Invalid statement: #{error.message}")
  end

  def to_s
    @text
  end

  def execute_core(_)
    raise(BASICSyntaxError, @errors[0])
  end
end

# unknown statement
class UnknownStatement < AbstractStatement
  def initialize(line_number, text)
    super(line_number, [], [])

    @valid = false
    @executable = :none
    @text = text
    @errors << "Unknown statement '#{text.strip}'"
  end

  def to_s
    @text
  end

  def execute_core(_) end
end

# empty statement (line number only)
class EmptyStatement < AbstractStatement
  def initialize(line_number)
    super(line_number, [], [])

    @valid = false
    @executable = :none

    @comprehension_effort = 0
  end

  def dump
    []
  end

  def to_s
    ''
  end

  def execute_core(_) end
end

# REMARK
class RemarkStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('REMARK')],
      [KeywordToken.new('REM')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @valid = false
    @comment = true
    @executable = :none
    @rest = Remark.new(nil)
    @rest = Remark.new(tokens_lists[0]) unless tokens_lists.empty?
  end

  def dump
    [@rest.dump]
  end

  def execute_core(_) end
end

# common functions for IO statements
module FileFunctions
  def extract_file_handle(items)
    file_tokens = nil

    unless items.empty? ||
           items[0].carriage_control?

      candidate_file_tokens = items[0]

      if candidate_file_tokens.filehandle?
        file_tokens = items.shift

        items.shift if
          !items.empty? &&
          items[0].carriage_control?
      end
    end

    file_tokens
  end

  def get_file_handle(interpreter, file_tokens)
    return nil if file_tokens.nil?

    file_handles = file_tokens.evaluate(interpreter)
    file_handles[0]
  end

  def add_needed_value(items, shape)
    items << ValueExpressionSet.new([], shape) if
      items.empty? || items[-1].carriage_control?
  end

  def add_needed_carriage(items)
    items << CarriageControl.new('') if
      !items.empty? && !items[-1].carriage_control?
  end

  def add_final_carriage(items, final)
    items << final if
      !items.empty? && !items[-1].carriage_control?
  end

  def add_default_value_carriage(items, shape)
    return unless items.empty?

    add_needed_value(items, shape)
    add_final_carriage(items, CarriageControl.new('NL'))
  end

  def dump
    lines = []

    lines += @file_tokens.dump unless @file_tokens.nil?
    @items&.each { |item| lines += item.dump }

    lines
  end
end

# common functions for INPUT statements
module InputFunctions
  def extract_prompt(items)
    prompt = nil

    unless items.empty? ||
           items[0].carriage_control?

      candidate_prompt_tokens = items[0]

      if candidate_prompt_tokens.text_constant?
        prompt = items.shift

        items.shift if
          !items.empty? &&
          items[0].carriage_control?
      end
    end

    prompt
  end

  def tokens_to_expressions(tokens_lists, shape, set_dims)
    items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(items, tokens_list, shape, set_dims)
      end
    end

    items
  end

  def add_expression(items, tokens, shape, set_dims)
    items << if tokens[0].operator? && tokens[0].pound?
               ValueExpressionSet.new(tokens, :scalar)
             elsif tokens[0].text_constant?
               ValueExpressionSet.new(tokens, :scalar)
             else
               TargetExpressionSet.new(tokens, shape, set_dims)
             end
  rescue BASICExpressionError => e
    line_text = tokens.map(&:to_s).join
    @errors << ("Syntax error: \"#{line_text}\" #{e}")
  end

  def zip(names, values)
    raise BASICRuntimeError, :te_too_few if values.size < names.size

    results = []
    (0...names.size).each do |i|
      results << { 'name' => names[i], 'value' => values[i] }
    end

    results
  end

  def input_values(fhr, interpreter, prompt, count)
    values = []

    while values.size < count
      remaining = count - values.size
      fhr.prompt(prompt, remaining)
      values += fhr.input(interpreter)

      prompt = nil
    end

    values
  end

  def file_values(fhr, interpreter)
    values = []

    values += fhr.input(interpreter)

    values
  end

  def uncache
    @items.each(&:uncache)
  end
end

# common functions for PRINT statements
module PrintFunctions
  def tokens_to_expressions(tokens_lists, shape)
    items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(items, tokens_list, shape)
      elsif tokens_list.separator?
        add_needed_value(items, shape)
        items << CarriageControl.new(tokens_list.to_s)
      end
    end

    add_final_carriage(items, CarriageControl.new('NL'))
    add_default_value_carriage(items, shape)
    items
  end

  def tokens_to_expressions_2(tokens_lists, shape)
    items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(items, tokens_list, shape)
      end
    end

    items
  end

  def add_expression(items, tokens, shape)
    if tokens[0].operator? && tokens[0].pound?
      items << ValueExpressionSet.new(tokens, :scalar)
    else
      add_needed_carriage(items)
      items << ValueExpressionSet.new(tokens, shape)
    end
  rescue BASICExpressionError => e
    line_text = tokens.map(&:to_s).join
    @errors << ("Syntax error: \"#{line_text}\" #{e}")
  end

  def uncache
    @items.each(&:uncache)
  end
end

# common functions for READ statements
module ReadFunctions
  def tokens_to_expressions(tokens_lists, shape, set_dims)
    items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(items, tokens_list, shape, set_dims)
      end
    end

    items
  end

  def add_expression(items, tokens, shape, set_dims)
    items << if tokens[0].operator? && tokens[0].pound?
               ValueExpressionSet.new(tokens, :scalar)
             else
               TargetExpressionSet.new(tokens, shape, set_dims)
             end
  rescue BASICExpressionError => e
    line_text = tokens.map(&:to_s).join
    @errors << ("Syntax error: \"#{line_text}\" #{e}")
  end

  def uncache
    @items.each(&:uncache)
  end
end

# common functions for WRITE statements
module WriteFunctions
  def tokens_to_expressions(tokens_lists, shape)
    items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(items, tokens_list, shape)
      elsif tokens_list.separator?
        add_needed_value(items, shape)
        items << CarriageControl.new(tokens_list.to_s)
      end
    end

    add_final_carriage(items, CarriageControl.new('NL'))
    add_default_value_carriage(items, shape)
    items
  end

  def add_expression(items, tokens, shape)
    if tokens[0].operator? && tokens[0].pound?
      items << ValueExpressionSet.new(tokens, :scalar)
    else
      add_needed_carriage(items)
      items << ValueExpressionSet.new(tokens, shape)
    end
  rescue BASICExpressionError => e
    line_text = tokens.map(&:to_s).join
    @errors << ("Syntax error: \"#{line_text}\" #{e}")
  end

  def uncache
    @items.each(&:uncache)
  end
end

# BREAK
class BreakStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('BREAK')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def set_destinations(_, line_stmt, program)
    begin
      @nextstmt_line_stmt =
        program.find_continue_next_line_stmt(line_stmt)
    rescue BASICSyntaxError => e
      @program_errors << e.message
    end
  end

  def set_transfers(_)
    unless @nextstmt_line_stmt.nil?
      line_number = @nextstmt_line_stmt.line_number
      stmt = @nextstmt_line_stmt.statement
      @transfers << TransferRefLineStmt.new(line_number, stmt, :fornext)
    end
  end

  def dump
    ['']
  end

  def execute_core(interpreter)
    interpreter.break_loop

    raise(BASICSyntaxError, 'Line number not found') if
      @nextstmt_line_stmt.nil?

    interpreter.next_line_stmt_mod = @nextstmt_line_stmt
  end
end

# CONTINUE
class ContinueStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('CONTINUE')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def set_destinations(_, line_stmt, program)
    begin
      @nextstmt_line_stmt =
        program.find_continue_next_line_stmt(line_stmt)
    rescue BASICSyntaxError => e
      @program_errors << e.message
    end
  end

  def set_transfers(_)
    unless @nextstmt_line_stmt.nil?
      line_number = @nextstmt_line_stmt.line_number
      stmt = @nextstmt_line_stmt.statement
      @transfers << TransferRefLineStmt.new(line_number, stmt, :fornext)
    end
  end

  def dump
    ['']
  end

  def execute_core(interpreter)
    raise(BASICSyntaxError, 'Line number not found') if
      @nextstmt_line_stmt.nil?

    interpreter.next_line_stmt_mod = @nextstmt_line_stmt
  end
end

# DATA
class DataStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('DATA')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @executable = :load_data

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @expressions = ValueExpressionSet.new(tokens_lists[0], :scalar)
      @elements = make_references(nil, @expressions)

      @comprehension_effort += @expressions.comprehension_effort
    else
      @errors << 'Syntax error'
    end
  end

  def uncache
    @expressions.uncache
  end

  def dump
    lines = []

    lines += @expressions.dump unless @expressions.nil?

    lines
  end

  def load_data(interpreter)
    ds = interpreter.get_data_store(nil)
    data_list = @expressions.evaluate(interpreter)
    ds.store(data_list)
  rescue BASICRuntimeError => e
    @errors << e.message
  end

  def execute_core(_) end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('DEF')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @executable = :def_fn
    @autonext = false

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      begin
        @definition = UserFunctionDefinition.new(tokens_lists[0])
        @autonext = @definition.multidef?

        @elements = make_references(nil, @definition)

        @comprehension_effort += @definition.comprehension_effort
      rescue BASICExpressionError => e
        @errors << e.message
      end
    else
      @errors << 'Syntax error'
    end
  end

  def set_endfunc_lines(line_stmt, program)
    return unless multidef?

    name = @definition.name

    begin
      # call to detect missing ENDFUNCTION statements
      program.find_closing_endfunc_line_stmt(name, line_stmt)
    rescue BASICSyntaxError => e
      @program_errors << e.message
    end
  end

  def define_user_functions(interpreter)
    unless @definition.nil?
      begin
        interpreter.set_user_function(@definition)
      rescue BASICRuntimeError => e
        @program_errors << e.message
      end
    end
  end

  def user_def?
    true
  end

  def singledef?
    return false if @definition.nil?

    @definition.singledef?
  end

  def multidef?
    return false if @definition.nil?

    @definition.multidef?
  end

  def function_name
    @definition.name
  end

  def function_signature
    @definition.signature
  end

  def dump
    lines = []
    lines += @definition.dump unless @definition.nil?
    lines
  end

  def execute_core(_) end
end

# DIM
class DimStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('DIM')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    @declarations = []
    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], false)

      tokens_lists.each do |tokens_list|
        @declarations << DeclarationExpressionSet.new(tokens_list)
      rescue BASICExpressionError => e
        @errors << ("Invalid #{tokens_list.map(&:to_s).join} #{e}")
      end

      @elements = make_references(@declarations)

      @declarations.each do |expression|
        @comprehension_effort += expression.comprehension_effort
      end
    else
      @errors << 'Syntax error'
    end
  end

  def uncache
    @declarations.each(&:uncache)
  end

  def dump
    lines = []

    @declarations.each do |expression|
      lines += expression.dump
    end

    lines
  end

  def execute_core(interpreter)
    @declarations.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      subscripts = variable.subscripts

      if subscripts.empty?
        raise BASICSyntaxError, 'DIM statement requires subscript range'
      end

      interpreter.set_dimensions(variable, subscripts)
    end
  end
end

# END
class EndStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('END')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def set_transfers(_)
    empty_line_number = LineNumber.new(nil)
    @transfers << TransferRefLineStmt.new(empty_line_number, 0, :stop)
  end

  def check_program(program, line_number_stmt)
    next_line_stmt = program.find_next_line_stmt(line_number_stmt)

    @program_errors << 'Statements after END' unless next_line_stmt.nil?
  end

  def end?
    true
  end

  def dump
    ['']
  end

  def execute_core(interpreter)
    io = interpreter.console_io
    io.newline_when_needed
    interpreter.stop
  end
end

# FILES
class FilesStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('FILES')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @executable = :files

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @expressions = ValueExpressionSet.new(tokens_lists[0], :scalar)
      @elements = make_references(nil, @expressions)

      @comprehension_effort += @expressions.comprehension_effort
    else
      @errors << 'Syntax error'
    end
  end

  def uncache
    @expressions.uncache
  end

  def dump
    @expressions.dump
  end

  def load_file_names(interpreter)
    file_names = @expressions.evaluate(interpreter)
    interpreter.add_file_names(file_names)
  rescue BASICRuntimeError => e
    @errors << e.message
  end

  def execute_core(_) end
end

# FOR statement
class ForStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('FOR')]
    ]
  end

  def self.stmt_keywords
    %w[TO STEP]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @autonext = false

    template_to = [[1, '>='], 'TO', [1, '>=']]
    template_to_step = [[1, '>='], 'TO', [1, '>='], 'STEP', [1, '>=']]
    template_step_to = [[1, '>='], 'STEP', [1, '>='], 'TO', [1, '>=']]

    if check_template(tokens_lists, template_to)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        variable_name = VariableName.new(tokens1[0])
        @control_variable = Variable.new(variable_name, :scalar, [], [])
        @start = ValueExpressionSet.new(tokens2, :scalar)
        @end = ValueExpressionSet.new(tokens_lists[2], :scalar)
        @step = nil
      rescue BASICExpressionError => e
        @errors << e.message
      end
    elsif check_template(tokens_lists, template_to_step)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        variable_name = VariableName.new(tokens1[0])
        @control_variable = Variable.new(variable_name, :scalar, [], [])
        @start = ValueExpressionSet.new(tokens2, :scalar)
        @end = ValueExpressionSet.new(tokens_lists[2], :scalar)
        @step = ValueExpressionSet.new(tokens_lists[4], :scalar)
      rescue BASICExpressionError => e
        @errors << e.message
      end
    elsif check_template(tokens_lists, template_step_to)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        variable_name = VariableName.new(tokens1[0])
        @control_variable = Variable.new(variable_name, :scalar, [], [])
        @start = ValueExpressionSet.new(tokens2, :scalar)
        @step = ValueExpressionSet.new(tokens_lists[2], :scalar)
        @end = ValueExpressionSet.new(tokens_lists[4], :scalar)
      rescue BASICExpressionError => e
        @errors << e.message
      end
    else
      @errors << 'Syntax error'
    end

    @mccabe = 1

    xref = XrefEntry.new(@control_variable.to_s, nil, true)

    @elements[:numerics] = []
    @elements[:strings] = []
    @elements[:booleans] = []
    @elements[:variables] = []
    @elements[:operators] = []
    @elements[:functions] = []
    @elements[:userfuncs] = []

    unless @start.nil?
      @elements[:numerics] += @start.numerics
      @elements[:strings] += @start.strings
      @elements[:booleans] += @start.booleans
      @elements[:variables] += [xref] + @start.variables
      @elements[:operators] += @start.operators
      @elements[:functions] += @start.functions
      @elements[:userfuncs] += @start.userfuncs
    end

    unless @end.nil?
      @elements[:numerics] += @end.numerics
      @elements[:strings] += @end.strings
      @elements[:booleans] += @end.booleans
      @elements[:variables] += @end.variables
      @elements[:operators] += @end.operators
      @elements[:functions] += @end.functions
      @elements[:userfuncs] += @end.userfuncs
    end

    unless @step.nil?
      @elements[:numerics] += @step.numerics
      @elements[:strings] += @step.strings
      @elements[:booleans] += @step.booleans
      @elements[:variables] += @step.variables
      @elements[:operators] += @step.operators
      @elements[:functions] += @step.functions
      @elements[:userfuncs] += @step.userfuncs
    end

    @comprehension_effort += @start.comprehension_effort unless @start.nil?
    @comprehension_effort += @end.comprehension_effort unless @end.nil?
    @comprehension_effort += @step.comprehension_effort unless @step.nil?
  end

  def set_destinations(_, line_stmt, program)
    @loopstart_line_stmt_mod = program.find_next_line_stmt_mod(line_stmt)

    begin
      unless @control_variable.nil?
        @nextstmt_line_stmt =
          program.find_closing_next_line_stmt(@control_variable, line_stmt)
      end
    rescue BASICSyntaxError => e
      @program_errors << e.message
    end
  end

  def set_transfers(_)
    unless @loopstart_line_stmt_mod.nil?
      line_number = @loopstart_line_stmt_mod.line_number
      stmt = @loopstart_line_stmt_mod.statement
      @transfers << TransferRefLineStmt.new(line_number, stmt, :fornext)
    end

    unless @nextstmt_line_stmt.nil?
      line_number = @nextstmt_line_stmt.line_number
      stmt = @nextstmt_line_stmt.statement
      @transfers << TransferRefLineStmt.new(line_number, stmt, :fornext)
    end
  end

  def assign_fornext_markers(program, current_line_stmt)
    return if @nextstmt_line_stmt.nil?

    marker = ForNextMarker.new(@control_variable, current_line_stmt)
    
    walk_line_stmt = current_line_stmt

    until walk_line_stmt == @nextstmt_line_stmt
      statement = program.get_statement(walk_line_stmt)
      
      # mark statement's destinations
      statement.assign_fornext_marker(marker)

      walk_line_stmt = program.find_next_line_stmt(walk_line_stmt)
    end

    # assign marker to closing NEXT
    statement = program.get_statement(walk_line_stmt)
      
    # mark statement's destinations
    statement.assign_fornext_marker(marker)
  end

  def uncache
    @start&.uncache
    @step&.uncache
    @end&.uncache
  end

  def for?
    true
  end

  def dump
    lines = []
    lines << ("control: #{@control_variable.dump}") unless @control_variable.nil?
    lines << ("start:   #{@start.dump}") unless @start.nil?
    lines << ("end:     #{@end.dump}") unless @end.nil?
    lines << ("step:    #{@step.dump}") unless @step.nil?
    lines
  end

  def number_for_stmts
    1
  end

  def execute_core(interpreter)
    raise BASICSyntaxError, 'uninitialized FOR' if
      @loopstart_line_stmt_mod.nil?

    raise BASICSyntaxError, 'uninitialized FOR' if
      @nextstmt_line_stmt.nil?

    from = @start.evaluate(interpreter)[0]
    step = NumericValue.new(1)
    step = @step.evaluate(interpreter)[0] unless @step.nil?

    unless @end.nil?
      to = @end.evaluate(interpreter)[0]

      fornext_control =
        ForToControl.new(@control_variable, from, step, to, @loopstart_line_stmt_mod)
    end

    interpreter.assign_fornext(fornext_control)

    interpreter.enter_loop(fornext_control)
    terminated = fornext_control.front_terminated?(interpreter)

    interpreter.next_line_stmt_mod = @loopstart_line_stmt_mod
    interpreter.next_line_stmt_mod = @nextstmt_line_stmt if terminated

    untilv = nil
    whilev = nil
    io = interpreter.trace_out
    print_more_trace_info(io, from, to, step, untilv, whilev, terminated)
  end

  def part_of_fornext_short(this_line_stmt)
    marker = ForNextMarker.new(@control_variable, this_line_stmt)

    @part_of_fornext - [marker]
  end

  private

  def control_and_start(tokens)
    parts = split_on_token(tokens, '=')
    raise(BASICSyntaxError, 'Incorrect initialization') if
      parts.size != 3
    raise(BASICSyntaxError, 'Missing "=" sign') if
      parts[1].to_s != '='

    @errors << 'Control variable must be a variable' unless
      parts[0][0].variable?

    [parts[0], parts[2]]
  end

  def print_more_trace_info(io, from, to, step, untilv, whilev, terminated)
    io.trace_output(" #{@start} = #{from}") unless @start.numeric_constant?
    io.trace_output(" #{@end} = #{to}") unless
      @end.nil? || @end.numeric_constant?
    io.trace_output(" #{@step} = #{step}") unless
      @step.nil? || @step.numeric_constant?
    io.trace_output(" #{@until} = #{untilv}") unless @until.nil?
    io.trace_output(" #{@while} = #{whilev}") unless @while.nil?
    io.trace_output(" terminated:#{terminated}")
  end
end

# FORGET
class ForgetStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('FORGET')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      # parse variable(s)
      @variables = []

      tokens_list = split_on_group_separators(tokens_lists[0])
      tokens_list.each do |tokens|
        if tokens[0].variable?
          variable_name = VariableName.new(tokens[0])
          # FIX: parse subscripts
          variable = Variable.new(variable_name, :scalar, [], [])
          @variables << variable
          variablex = XrefEntry.new(variable.to_s, nil, false)
          @elements[:variables] += [variablex]
        else
          @errors << "Invalid variable #{tokens[0]}"
        end
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []

    @variables.each { |variable| lines << variable.dump }

    lines
  end

  def execute_core(interpreter)
    @variables.each { |variable| interpreter.forget_value(variable) }
  end
end

# GOSUB
class GosubStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('GOSUB')]
    ]
  end

  def initialize(line_number, keywords, tokens_lists)
    super

    template = [[1]]

    if check_template(tokens_lists, template)
      if tokens_lists[0][0].numeric_constant?
        number = IntegerValue.new(tokens_lists[0][0])
        @dest_line = LineNumber.new(number)
        @linenums = [@dest_line]

        @comprehension_effort += 1
        @comprehension_effort += 1 if @dest_line <= line_number
      else
        @errors << "Invalid line number #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def renumber(renumber_map)
    # change destination
    @dest_line = renumber_map[@dest_line]

    # change linenums
    @linenums = [@dest_line]

    # change token
    @tokens[-1] = @dest_line.to_token
  end

  def set_destinations(interpreter, _, program)
    mod = interpreter.statement_start_index(@dest_line)

    unless mod.nil?
      dest = LineStmtMod.new(@dest_line, 0, mod)
      @dest_line_stmt_mod = program.find_exec_line_stmt_mod(dest)
    end
  end

  def set_transfers(_)
    if @dest_line_stmt_mod.nil?
      @transfers << TransferRefLineStmt.new(@dest_line, 0, :gosub) unless
        @dest_line.nil?
    else
      xref = TransferRefLineStmt.new(@dest_line_stmt_mod.line_number, 0, :gosub)
      @transfers << xref
    end
  end

  def assign_sub_markers(program)
    return if @dest_line_stmt_mod.nil?

    statement = program.get_statement(@dest_line_stmt_mod)

    unless statement.nil?
      dest_line = @dest_line_stmt_mod.line_number

      unless statement.part_of_sub.include?(dest_line)
        # mark statement's destinations
        statement.assign_sub_marker(dest_line, dest_line, program)
      end
    end
  end

  def check_program(program, _)
    @program_errors << "Line number #{@dest_line} not found" unless
      program.line_number?(@dest_line)
  end

  def dump
    [@dest_line.dump]
  end

  def execute_core(interpreter)
    interpreter.push_return(interpreter.next_line_stmt_mod)

    raise(BASICSyntaxError, 'Line number not found') if
      @dest_line_stmt_mod.nil?

    interpreter.next_line_stmt_mod = @dest_line_stmt_mod
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('GOTO')]
    ]
  end

  def initialize(line_number, keywords, tokens_lists)
    super

    @autonext = false

    template = [[1]]

    if check_template(tokens_lists, template)
      if tokens_lists[0][0].numeric_constant?
        number = IntegerValue.new(tokens_lists[0][0])
        @dest_line = LineNumber.new(number)
        @linenums = [@dest_line]

        @comprehension_effort += 1
        @comprehension_effort += 1 if @dest_line <= line_number
      else
        @errors << "Invalid line number #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def set_destinations(interpreter, _, program)
    mod = interpreter.statement_start_index(@dest_line)

    unless mod.nil?
      dest = LineStmtMod.new(@dest_line, 0, mod)
      @dest_line_stmt_mod = program.find_exec_line_stmt_mod(dest)
    end
  end

  def renumber(renumber_map)
    # change destination
    @dest_line = renumber_map[@dest_line]

    # change linenums
    @linenums = [@dest_line]

    # change token
    @tokens[-1] = @dest_line.to_token
  end

  def set_transfers(_)
    if @dest_line_stmt_mod.nil?
      @transfers << TransferRefLineStmt.new(@dest_line, 0, :goto) unless
        @dest_line.nil?
    else
      xref = TransferRefLineStmt.new(@dest_line_stmt_mod.line_number, 0, :goto)
      @transfers << xref
    end
  end

  def check_destinations_fornext(program, line_stmt)
    check_destination_fornext(program, line_stmt, @dest_line_stmt_mod)
  end

  def check_program(program, _)
    @program_errors << "Line number #{@dest_line} not found" unless
       program.line_number?(@dest_line)
  end

  def dump
    [@dest_line.dump]
  end

  def execute_core(interpreter)
    raise(BASICSyntaxError, 'Line number not found') if
      @dest_line_stmt_mod.nil?

    interpreter.next_line_stmt_mod = @dest_line_stmt_mod
  end
end

# common functions for IF statements
class AbstractIfStatement < AbstractStatement
  def set_destinations(interpreter, _, program)
    mod = interpreter.statement_start_index(@dest_line)

    unless mod.nil?
      dest = LineStmtMod.new(@dest_line, 0, mod)
      @dest_line_stmt_mod = program.find_exec_line_stmt_mod(dest)
    end
  end

  def renumber(renumber_map)
    # change destination
    @dest_line = renumber_map[@dest_line]

    # change linenums
    @linenums = [@dest_line]

    # change token
    @tokens[-1] = @dest_line.to_token
  end

  def set_transfers(_)
    if @dest_line_stmt_mod.nil?
      @transfers << TransferRefLineStmt.new(@dest_line, 0, :ifthen) unless
        @dest_line.nil?
    else
      xref = TransferRefLineStmt.new(@dest_line_stmt_mod.line_number, 0, :ifthen)
      @transfers << xref
    end
  end

  def check_destinations_fornext(program, line_stmt)
    check_destination_fornext(program, line_stmt, @dest_line_stmt_mod)
  end

  def check_program(program, _)
    unless !@dest_line.nil? && program.line_number?(@dest_line)
      @program_errors << "Line number #{@dest_line} not found"
    end
  end

  def uncache
    @expression.uncache
  end

  def dump
    lines = []

    lines += @expression.dump unless @expression.nil?
    lines << @dest_line.dump unless @dest_line.nil?

    lines
  end

  def execute_core(interpreter)
    values = @expression.evaluate(interpreter)

    raise(BASICExpressionError, 'Expression error') unless
      values.size == 1

    result = values[0]

    raise(BASICExpressionError, 'Expression error') unless
      result.class.to_s == 'BooleanValue'

    if result.value
      raise(BASICSyntaxError, 'Line number not found') if
        @dest_line_stmt_mod.nil?

      interpreter.next_line_stmt_mod = @dest_line_stmt_mod
    end

    s = " #{@expression}: #{result}"
    io = interpreter.trace_out
    io.trace_output(s)
  end
end

# IF/THEN
class IfStatement < AbstractIfStatement
  def self.lead_keywords
    [
      [KeywordToken.new('IF')]
    ]
  end

  def initialize(line_number, keywords, tokens_lists)
    super

    template = [[1, '>='], 'THEN', [1]]

    if check_template(tokens_lists, template)
      begin
        number = IntegerValue.new(tokens_lists[2][0])
        @dest_line = LineNumber.new(number)
        @linenums = [@dest_line]

        @comprehension_effort += 1
        @comprehension_effort += 1 if @dest_line <= line_number
      rescue BASICSyntaxError => e
        @errors << e.message
      end

      begin
        @expression = ValueExpressionSet.new(tokens_lists[0], :scalar)
        @warnings << 'Constant expression' if @expression.constant?
        @elements = make_references(nil, @expression)

        @comprehension_effort += @expression.comprehension_effort
      rescue BASICExpressionError => e
        @errors << e.message
      end

      @mccabe = 1
    else
      @errors << 'Syntax error'
    end
  end
end

# INPUT
class InputStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('INPUT')]
    ]
  end

  include FileFunctions
  include InputFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :scalar, false)
      @file_tokens = extract_file_handle(@items)
      @prompt = extract_prompt(@items)
      @elements = make_references(@items, @file_tokens, @prompt)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }

      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :read)

    prompt = nil

    unless @prompt.nil?
      prompts = @prompt.evaluate(interpreter)
      prompt = prompts[0]
    end

    # create list of variables with subscripts
    item_names = []

    @items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        item_names << target
      end
    end

    # get all of the needed values
    if fh.nil?
      # from console
      values = input_values(fhr, interpreter, prompt, item_names.size)
      fhr.implied_newline
    else
      # from file
      values = file_values(fhr, interpreter)
    end

    raise BASICRuntimeError, :te_too_few if values.size < item_names.size

    name_value_pairs =
      zip(item_names, values[0..item_names.length])

    name_value_pairs.each do |hash|
      variable = hash['name']
      value = hash['value']
      interpreter.set_value(variable, value)
    end

    interpreter.clear_previous_lines
  end
end

# common functions for LET and LET-less statements
class AbstractLetStatement < AbstractStatement
  def set_transfers(user_function_start_lines)
    unless @assignment.nil?
      @transfers += @assignment.destinations(user_function_start_lines)
    end
  end

  def uncache
    @assignment.uncache
  end

  def dump
    lines = []
    lines += @assignment.dump unless @assignment.nil?
    lines
  end
end

# common functions for scalar LET and LET-less statement
class AbstractScalarLetStatement < AbstractLetStatement
  def initialize(_, _, tokens_lists)
    super

    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = Assignment.new(tokens_lists[0], :scalar)

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value.zero?
          @errors << 'Assignment must have right-hand value(s)'
        end

        @warnings << 'Extra values ignored' if
          @assignment.count_value > @assignment.count_target

        @elements = make_references(nil, @assignment)

        @comprehension_effort += @assignment.comprehension_effort
      rescue BASICExpressionError => e
        @errors << e.message
      end
    else
      @errors << 'Syntax error'
    end
  end
end

# LET
class LetStatement < AbstractScalarLetStatement
  def self.lead_keywords
    [
      [KeywordToken.new('LET')]
    ]
  end

  def execute_core(interpreter)
    l_values = @assignment.eval_target(interpreter)

    r_values = @assignment.eval_value(interpreter)

    # more left-hand values -> repeat last rhs
    # more rhs -> drop extra values
    l_values.each_with_index do |l_value, index|
      j = [index, r_values.count - 1].min
      r_value = r_values[j]

      # if l_value is a function name
      # replace with current function signature
      l_value = interpreter.current_user_function if
        l_value.class.to_s == 'UserFunction'

      interpreter.set_value(l_value, r_value)
    end
  end
end

# NEXT
class NextStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('NEXT')]
    ]
  end

  attr_reader :control_variable

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1]]

    if check_template(tokens_lists, template)
      # parse control variable
      @control_variable = nil
      if tokens_lists[0][0].variable?
        variable_name = VariableName.new(tokens_lists[0][0])
        @control_variable = Variable.new(variable_name, :scalar, [], [])
        xref = XrefEntry.new(@control_variable.to_s, nil, false)
        @elements[:variables] = [xref]
      else
        @errors << "Invalid control variable #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def next?
    true
  end

  def dump
    [@control_variable.dump]
  end

  def execute_core(interpreter)
    fornext_control = interpreter.retrieve_fornext(@control_variable)

    if $options['match_fornext'].value
      # check control variable matches current loop
      top_fornext_control = interpreter.top_fornext
      expected = top_fornext_control.control_variable
      actual = fornext_control.control_variable

      if actual != expected
        raise(BASICSyntaxError,
              "Found NEXT #{actual} when expecting #{expected}")
      end
    end

    bump_early = fornext_control.bump_early?

    # change control variable value for FOR-WHILE and FOR-UNTIL
    fornext_control.bump_control(interpreter) if bump_early

    terminated = fornext_control.terminated?(interpreter)

    io = interpreter.trace_out
    io.trace_output(" terminated:#{terminated}")

    if terminated
      interpreter.exit_loop(fornext_control)
      fornext_control.broken = false
    else
      # set next line from top item
      interpreter.next_line_stmt_mod = fornext_control.start_line_stmt_mod
      # change control variable value for FOR-TO
      fornext_control.bump_control(interpreter) unless bump_early
    end
  end
end

# OPTION
class OptionStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('OPTION')]
    ]
  end

  def self.stmt_keywords
    # build list from all defined options
    $options.keys.map(&:upcase)
  end

  def self.cmd_keywords
    %w[
      BASE
      CACHE_CONST_EXPR
      DEFAULT_PROMPT DEGREES DETECT_INFINITE_LOOP
      FIELD_SEP FORGET_FORNEXT
      HEADING
      IGNORE_RND_ARG IMPLIED_SEMICOLON INT_FLOOR
      LOCK_FORNEXT
      MATCH_FORNEXT
      MAX_DIM MAX_LINE_NUM MIN_LINE_NUM
      NEWLINE_SPEED
      PRECISION PRINT_SPEED PRINT_WIDTH
      PROMPT PROMPTD PROMPT_COUNT
      PROVENANCE
      QMARK_AFTER_PROMPT
      RADIANS
      REQUIRE_INITIALIZED
      SEMICOLON_ZONE_WIDTH
      TIMING TRACE TRIG_REQUIRE_UNITS
      WARN_FORNEXT_LENGTH WARN_FORNEXT_LEVEL
      WARN_GOSUB_LENGTH
      WARN_LIST_WIDTH WARN_PRETTY_WIDTH
      WRAP
      ZONE_WIDTH
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    extras = $options.keys.map(&:upcase)
    template = [extras, [1, '>=']]

    if check_template(tokens_lists, template)
      kwd = tokens_lists[0].to_s.upcase
      @key = kwd.downcase

      if $options[@key].types.include?(:runtime)
        expression_tokens = split_tokens(tokens_lists[1], true)
        @expression = ValueExpressionSet.new(expression_tokens[0], :scalar)
        @elements = make_references(nil, @expression)

        @comprehension_effort += @expression.comprehension_effort
      else
        @errors << ("Cannot set option #{kwd}")
      end
    elsif tokens_lists.size == 1 &&
          extras.include?(tokens_lists[0].to_s)
      kwd = tokens_lists[0].to_s.upcase
      @key = kwd.downcase

      @errors << ("Cannot set option #{kwd}") unless
        $options[@key].types.include?(:runtime)
    else
      @errors << 'Syntax error'
    end
  end

  def uncache
    @expression&.uncache
  end

  def dump
    lines = []
    lines += @expression.dump unless @expression.nil?
    lines
  end

  def execute_core(interpreter)
    if @expression.nil?
      interpreter.pop_option(@key)
    else
      values = @expression.evaluate(interpreter)
      value0 = values[0]

      interpreter.push_option(@key, value0.to_v)
    end
  end
end

# PRINT
class PrintStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('PRINT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template1 = []
    template2 = [[1, '>=']]

    if check_template(tokens_lists, template1)
      @items = tokens_to_expressions([], :scalar)
      @elements = make_references(@items, nil)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    elsif check_template(tokens_lists, template2)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :scalar)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    last_was_carriage = true

    while i < @items.size
      item = @items[i]

      # insert an implicit carriage control
      fhr.implied unless item.carriage_control? || last_was_carriage

      if item.carriage_control?
        item.print(fhr)
      else
        item.print(fhr, interpreter)
      end

      last_was_carriage = item.carriage_control?

      i += 1
    end
  end
end

# READ
class ReadStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('READ')]
    ]
  end

  include FileFunctions
  include ReadFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :scalar, false)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }

      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        value = ds.read
        interpreter.set_value(target, value)
      end
    end

    interpreter.clear_previous_lines
  end
end

# RESTORE
class RestoreStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('RESTORE')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def dump
    ['']
  end

  def execute_core(interpreter)
    ds = interpreter.get_data_store(nil)
    ds.reset
  end
end

# RETURN
class ReturnStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('RETURN')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def dump
    ['']
  end

  def execute_core(interpreter)
    interpreter.next_line_stmt_mod = interpreter.pop_return
  end
end

# STOP
class StopStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('STOP')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def set_transfers(_)
    empty_line_number = LineNumber.new(nil)
    @transfers << TransferRefLineStmt.new(empty_line_number, 0, :stop)
  end

  def stop?
    true
  end

  def dump
    ['']
  end

  def execute_core(interpreter)
    io = interpreter.console_io
    io.newline_when_needed
    interpreter.stop
  end
end

# WRITE
class WriteStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('WRITE')]
    ]
  end

  include FileFunctions
  include WriteFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :scalar)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    last_was_carriage = true

    while i < @items.size
      item = @items[i]

      # insert an implicit carriage control
      fhr.print_item(',') unless item.carriage_control? || last_was_carriage

      if item.carriage_control?
        item.write(fhr)
      else
        item.write(fhr, interpreter)
      end

      last_was_carriage = item.carriage_control?

      i += 1
    end
  end
end

# ARR FORGET
class ArrForgetStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('FORGET')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      # parse variable
      @variables = []

      tokens_list = split_on_group_separators(tokens_lists[0])
      tokens_list.each do |tokens|
        if tokens[0].variable?
          variable_name = VariableName.new(tokens[0])
          variable = Variable.new(variable_name, :array, [], [])
          @variables << variable
          variablex = XrefEntry.new(variable.to_s, nil, false)
          @elements[:variables] += [variablex]
        else
          @errors << "Invalid variable #{tokens[0]}"
        end
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []

    @variables.each { |variable| lines << variable.dump }

    lines
  end

  def execute_core(interpreter)
    @variables.each { |variable| interpreter.forget_compound_values(variable) }
  end
end

# ARR INPUT
class ArrInputStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('INPUT')]
    ]
  end

  include FileFunctions
  include InputFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array, true)
      @file_tokens = extract_file_handle(@items)
      @prompt = extract_prompt(@items)
      @elements = make_references(@items, @file_tokens, @prompt)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :read)

    prompt = nil

    unless @prompt.nil?
      prompts = @prompt.evaluate(interpreter)
      prompt = prompts[0]
    end

    # compute size based on variable dimensions
    # create list of variables with subscripts
    item_names = []

    @items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        name = target.name

        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?

        raise BASICRuntimeError, :te_arr_no_dim unless
          interpreter.dimensions?(target.name)

        # make sure dimension is one
        dims = interpreter.get_dimensions(name)
        raise(BASICExpressionError, 'Not an array') unless dims.size == 1

        # build names
        base = $options['base'].value
        (base..dims[0].to_i).each do |col|
          coord = AbstractElement.make_coord(col)
          wcoord = interpreter.wrap_subscripts(name, coord)
          variable = Variable.new(name, :array, coord, wcoord)
          item_names << variable
        end
      end
    end

    # get all of the needed values
    if fh.nil?
      # from console
      values = input_values(fhr, interpreter, prompt, item_names.size)
      fhr.implied_newline
    else
      # from file
      values = file_values(fhr, interpreter)
    end

    raise BASICRuntimeError, :te_too_few if values.size < item_names.size

    # use names based on variable dimensions
    name_value_pairs =
      zip(item_names, values[0..item_names.length])

    name_value_pairs.each do |hash|
      variable = hash['name']
      value = hash['value']
      interpreter.set_value(variable, value)
    end

    interpreter.clear_previous_lines
  end
end

# ARR PLOT
class ArrPlotStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('PLOT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template2 = [[1, '>=']]

    if check_template(tokens_lists, template2)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions_2(items, :array)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }

      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    @items.each do |item|
      if item.carriage_control?
        item.plot(fhr)
      else
        item.plot(fhr, interpreter)
      end
    end
  end
end

# ARR PRINT
class ArrPrintStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('PRINT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    last_was_carriage = true

    while i < @items.size
      item = @items[i]

      # insert an implicit carriage control
      fhr.implied unless item.carriage_control? || last_was_carriage

      if item.carriage_control?
        item.print(fhr)
      else
        item.print(fhr, interpreter)
      end

      last_was_carriage = item.carriage_control?

      i += 1
    end
  end
end

# ARR READ
class ArrReadStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('READ')]
    ]
  end

  include FileFunctions
  include ReadFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :array, true)

      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }

      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?

        raise BASICRuntimeError, :te_arr_no_dim unless
          interpreter.dimensions?(target.name)

        read_values(target.name, interpreter, ds)
      end
    end

    interpreter.clear_previous_lines
  end

  private

  def read_values(name, interpreter, ds)
    dims = interpreter.get_dimensions(name)

    case dims.size
    when 1
      read_array(name, dims, interpreter, ds)
    else
      raise(BASICSyntaxError, 'Dimensions for ARR READ must be 1')
    end
  end

  def read_array(name, dims, interpreter, ds)
    values = {}

    base = $options['base'].value
    (base..dims[0].to_i).each do |col|
      coord = AbstractElement.make_coord(col)
      values[coord] = ds.read
    end

    interpreter.set_values(name, values)
  end
end

# ARR WRITE
class ArrWriteStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('WRITE')]
    ]
  end

  include FileFunctions
  include WriteFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    last_was_carriage = true

    while i < @items.size
      item = @items[i]

      # insert an implicit carriage control
      fhr.print_item(',') unless item.carriage_control? || last_was_carriage

      if item.carriage_control?
        item.write(fhr)
      else
        item.write(fhr, interpreter)
      end

      last_was_carriage = item.carriage_control?

      i += 1
    end
  end
end

# ARR assignment
class ArrLetStatement < AbstractLetStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR')],
      [KeywordToken.new('ARR'), KeywordToken.new('LET')]
    ]
  end

  def initialize(_, _, tokens_lists)
    super

    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = Assignment.new(tokens_lists[0], :array)

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value.zero?
          @errors << 'Assignment must have right-hand value(s)'
        end

        @elements = make_references(nil, @assignment)

        @comprehension_effort += @assignment.comprehension_effort
      rescue BASICError => e
        @errors << e.message
        @assignment = @rest
      end
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    l_values = @assignment.eval_target(interpreter)
    l_value0 = l_values[0]
    l_dims = interpreter.get_dimensions(l_value0.name)

    interpreter.set_default_args('CON1', l_dims)
    interpreter.set_default_args('RND1', l_dims)
    interpreter.set_default_args('ZER1', l_dims)

    r_value = first_value(interpreter)

    interpreter.set_default_args('CON1', nil)
    interpreter.set_default_args('RND1', nil)
    interpreter.set_default_args('ZER1', nil)

    r_dims = r_value.dimensions

    values = r_value.values_1

    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, r_dims)
      interpreter.set_values(l_value.name, values)
    end
  end

  private

  def first_target(interpreter)
    l_values = @assignment.eval_target(interpreter)

    l_values[0]
  end

  def first_value(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]

    raise(BASICSyntaxError, 'Expected Array') if
      r_value.class.to_s != 'BASICArray'

    r_value
  end
end

# MAT FORGET
class MatForgetStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('FORGET')]
    ]
  end

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      # parse variable
      @variables = []

      tokens_list = split_on_group_separators(tokens_lists[0])
      tokens_list.each do |tokens|
        if tokens[0].variable?
          variable_name = VariableName.new(tokens[0])
          variable = Variable.new(variable_name, :matrix, [], [])
          @variables << variable
          variablex = XrefEntry.new(variable.to_s, nil, false)
          @elements[:variables] += [variablex]
        else
          @errors << "Invalid variable #{tokens[0]}"
        end
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []

    @variables.each { |variable| lines << variable.dump }

    lines
  end

  def execute_core(interpreter)
    @variables.each { |variable| interpreter.forget_compound_values(variable) }
  end
end

# MAT INPUT
class MatInputStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('INPUT')]
    ]
  end

  include FileFunctions
  include InputFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array, true)
      @file_tokens = extract_file_handle(@items)
      @prompt = extract_prompt(@items)
      @elements = make_references(@items, @file_tokens, @prompt)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :read)

    prompt = nil

    unless @prompt.nil?
      prompts = @prompt.evaluate(interpreter)
      prompt = prompts[0]
    end

    # compute size based on variable dimensions
    # create list of variables with subscripts
    item_names = []

    @items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        name = target.name

        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?

        raise BASICRuntimeError, :te_mat_no_dim unless
          interpreter.dimensions?(target.name)

        # make sure dimension is one or two
        dims = interpreter.get_dimensions(name)
        raise(BASICExpressionError, 'Not an array') unless
          dims.size == 1 || dims.size == 2

        # build names
        if dims.size == 1
          base = $options['base'].value
          (base..dims[0].to_i).each do |col|
            coord = AbstractElement.make_coord(col)
            wcoord = interpreter.wrap_subscripts(name, coord)
            variable = Variable.new(name, :matrix, coord, wcoord)
            item_names << variable
          end
        end

        next unless dims.size == 2

        base = $options['base'].value
        (base..dims[0].to_i).each do |row|
          (base..dims[1].to_i).each do |col|
            coords = AbstractElement.make_coords(row, col)
            wcoords = interpreter.wrap_subscripts(name, coords)
            variable = Variable.new(name, :matrix, coords, wcoords)
            item_names << variable
          end
        end
      end
    end

    # get all of the needed values
    if fh.nil?
      # from console
      values = input_values(fhr, interpreter, prompt, item_names.size)
      fhr.implied_newline
    else
      # from file
      values = file_values(fhr, interpreter)
    end

    raise BASICRuntimeError, :te_too_few if values.size < item_names.size

    # use names based on variable dimensions
    name_value_pairs =
      zip(item_names, values[0..item_names.length])

    name_value_pairs.each do |hash|
      variable = hash['name']
      value = hash['value']
      interpreter.set_value(variable, value)
    end

    interpreter.clear_previous_lines
  end
end

# MAT PLOT
class MatPlotStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('PLOT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template2 = [[1, '>=']]

    if check_template(tokens_lists, template2)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions_2(items, :matrix)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }

      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    @items.each do |item|
      if item.carriage_control?
        item.plot(fhr)
      else
        item.plot(fhr, interpreter)
      end
    end
  end
end

# MAT PRINT
class MatPrintStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('PRINT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :matrix)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    last_was_carriage = true

    while i < @items.size
      item = @items[i]

      # insert an implicit carriage control
      fhr.implied unless item.carriage_control? || last_was_carriage

      if item.carriage_control?
        # MAT PRINT has different operations for carriage controls
        carriage = map_carriage(item)
        carriage.print(fhr)
      else
        item.print(fhr, interpreter)
      end

      last_was_carriage = item.carriage_control?

      i += 1
    end
  end

  def map_carriage(it)
    carriage = CarriageControl.new('')

    case it.to_s
    when ', '
      # a comma prints a newline
      carriage = CarriageControl.new('NL')
    when '; '
      # a semi does nothing, even after numerics
      carriage = CarriageControl.new('')
    when ''
      # a newline prints a newline (which is normal)
      carriage = it
    when ' '
      # an implied carriage control does nothing
      carriage = CarriageControl.new('')
    end

    carriage
  end
end

# MAT READ
class MatReadStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('READ')]
    ]
  end

  include FileFunctions
  include ReadFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :matrix, true)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }

      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?

        raise BASICRuntimeError, :te_mat_no_dim unless
          interpreter.dimensions?(target.name)

        read_values(target.name, interpreter, ds)
      end
    end

    interpreter.clear_previous_lines
  end

  private

  def read_values(name, interpreter, ds)
    dims = interpreter.get_dimensions(name)

    case dims.size
    when 1
      read_vector(name, dims, interpreter, ds)
    when 2
      read_matrix(name, dims, interpreter, ds)
    else
      raise(BASICSyntaxError, 'Dimensions for MAT READ must be 1 or 2')
    end
  end

  def read_vector(name, dims, interpreter, ds)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |col|
      coord = AbstractElement.make_coord(col)
      values[coord] = ds.read
    end

    interpreter.set_values(name, values)
  end

  def read_matrix(name, dims, interpreter, ds)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |row|
      (base..dims[1].to_i).each do |col|
        coords = AbstractElement.make_coords(row, col)
        values[coords] = ds.read
      end
    end

    interpreter.set_values(name, values)
  end
end

# MAT WRITE
class MatWriteStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('WRITE')]
    ]
  end

  include FileFunctions
  include WriteFunctions

  def initialize(_, keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :matrix)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)

      @items.each { |item| @comprehension_effort += item.comprehension_effort }
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    last_was_carriage = true

    while i < @items.size
      item = @items[i]

      # insert an implicit carriage control
      fhr.print_item(',') unless item.carriage_control? || last_was_carriage

      if item.carriage_control?
        item.write(fhr)
      else
        item.write(fhr, interpreter)
      end

      last_was_carriage = item.carriage_control?

      i += 1
    end
  end
end

# MAT assignment
class MatLetStatement < AbstractLetStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT')],
      [KeywordToken.new('MAT'), KeywordToken.new('LET')]
    ]
  end

  def initialize(_, _, tokens_lists)
    super

    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = Assignment.new(tokens_lists[0], :matrix)

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value.zero?
          @errors << 'Assignment must have right-hand value(s)'
        end

        @elements = make_references(nil, @assignment)

        @comprehension_effort += @assignment.comprehension_effort
      rescue BASICError => e
        @errors << e.message
        @assignment = @rest
      end
    else
      @errors << 'Syntax error'
    end
  end

  def execute_core(interpreter)
    l_values = @assignment.eval_target(interpreter)
    l_value0 = l_values[0]
    l_dims = interpreter.get_dimensions(l_value0.name)
    set_default_args(interpreter, l_dims)

    r_value = first_value(interpreter)

    clear_default_args(interpreter)

    set_dimensions(interpreter, r_value, l_values)
  end

  def set_default_args(interpreter, l_dims)
    interpreter.set_default_args('CON2', l_dims)
    interpreter.set_default_args('CON', l_dims)
    interpreter.set_default_args('IDN', l_dims)
    interpreter.set_default_args('RND2', l_dims)
    interpreter.set_default_args('ZER2', l_dims)
    interpreter.set_default_args('ZER', l_dims)
  end

  def first_value(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]

    raise(BASICSyntaxError, 'Expected Matrix') if
      r_value.class.to_s != 'Matrix'

    r_value
  end

  def clear_default_args(interpreter)
    interpreter.set_default_args('CON2', nil)
    interpreter.set_default_args('CON', nil)
    interpreter.set_default_args('IDN', nil)
    interpreter.set_default_args('RND2', nil)
    interpreter.set_default_args('ZER2', nil)
    interpreter.set_default_args('ZER', nil)
  end

  def set_dimensions(interpreter, r_value, l_values)
    r_dims = r_value.dimensions

    values = r_value.values_1 if r_dims.size == 1
    values = r_value.values_2 if r_dims.size == 2

    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, r_dims)
      interpreter.set_values(l_value.name, values)
    end
  end
end

# Statement factory class
class StatementFactory
  include Singleton

  attr_writer :tokenbuilders

  def initialize
    @statement_definitions = statement_definitions
    @tokenbuilders = []
  end

  def parse(text)
    line_number = nil
    line = nil
    m = /\A\d+/.match(text)

    unless m.nil?
      token = NumericLiteralToken.new(m[0])
      number = IntegerValue.new(token)
      line_number = LineNumber.new(number)
      line_text = m.post_match
      all_tokens = tokenize_line(line_text)
      all_tokens.delete_if(&:break?)
      all_tokens.delete_if(&:whitespace?)
      comment = nil

      comment = all_tokens.pop if
        !all_tokens.empty? && all_tokens[-1].comment?

      line = create(line_number, line_text, all_tokens, comment)
    end

    [line_number, line]
  end

  def create(line_number, text, all_tokens, comment)
    statements = []
    statements_tokens = split_on_statement_separators(all_tokens)

    if statements_tokens.empty?
      statement = EmptyStatement.new(line_number)
      statements << statement
    else
      statements_tokens.each do |statement_tokens|
        statement = UnknownStatement.new(line_number, text)

        begin
          statement = create_statement(line_number, text, statement_tokens)
        rescue BASICExpressionError, BASICRuntimeError => e
          statement = InvalidStatement.new(line_number, text, all_tokens, e)
        end

        statements << statement
      end
    end

    Line.new(text, statements, all_tokens, comment)
  end

  def create_statement(line_number, text, statement_tokens)
    statement = EmptyStatement.new(line_number)

    unless statement_tokens.empty?
      statement = nil

      keywords, tokens = extract_keywords(statement_tokens)

      while statement.nil?
        if @statement_definitions.key?(keywords)
          tokens_lists = split_keywords(tokens)

          statement_definition = @statement_definitions[keywords]

          statement =
            statement_definition.new(line_number, keywords, tokens_lists)
        elsif keywords.empty?
          if statement.nil?
            statement = UnknownStatement.new(line_number, text)
          end
        else
          keyword = keywords.pop
          tokens.unshift(keyword)
        end
      end
    end

    statement
  end

  # lead keywords let us identify the statement
  def lead_keywords
    keywords = []

    statement_classes.each do |cl|
      kwds = cl.lead_keywords.flatten
      keywords += kwds.map(&:to_s)
    end

    keywords.uniq
  end

  private

  def statement_classes
    [
      ArrForgetStatement,
      ArrInputStatement,
      ArrPlotStatement,
      ArrPrintStatement,
      ArrReadStatement,
      ArrWriteStatement,
      ArrLetStatement,
      BreakStatement,
      ContinueStatement,
      DataStatement,
      DefineFunctionStatement,
      DimStatement,
      EndStatement,
      FilesStatement,
      ForStatement,
      ForgetStatement,
      GosubStatement,
      GotoStatement,
      IfStatement,
      InputStatement,
      LetStatement,
      MatForgetStatement,
      MatInputStatement,
      MatPlotStatement,
      MatPrintStatement,
      MatReadStatement,
      MatWriteStatement,
      MatLetStatement,
      NextStatement,
      OptionStatement,
      PrintStatement,
      ReadStatement,
      RemarkStatement,
      RestoreStatement,
      ReturnStatement,
      StopStatement,
      WriteStatement
    ]
  end

  def statement_definitions
    lead_keywords = {}

    statement_classes.each do |class_name|
      keyword_sets = class_name.lead_keywords

      keyword_sets.each do |set|
        lead_keywords[set] = class_name
      end
    end

    lead_keywords
  end

  def split_on_statement_separators(tokens)
    tokens_lists = []
    statement_tokens = []

    tokens.each do |token|
      if token.statement_separator?
        tokens_lists << statement_tokens
        statement_tokens = []
      else
        statement_tokens << token
      end
    end

    tokens_lists << statement_tokens unless statement_tokens.empty?
    tokens_lists
  end

  def extract_keywords(all_tokens)
    keywords = []
    tokens = []
    saw_non_keyword = false

    all_tokens.each do |token|
      saw_non_keyword = true unless token.keyword?
      keywords << token unless saw_non_keyword
      tokens << token if saw_non_keyword
    end

    [keywords, tokens]
  end

  def split_keywords(tokens)
    results = []
    nonkeywords = []

    tokens.each do |token|
      if token.keyword?
        results << nonkeywords unless nonkeywords.empty?
        nonkeywords = []
        results << token
      else
        nonkeywords << token
      end
    end
    results << nonkeywords unless nonkeywords.empty?

    results
  end

  def tokenize_line(text)
    invalid_tokenbuilder = InvalidTokenBuilder.new(true, [])
    tokenizer = Tokenizer.new(@tokenbuilders, invalid_tokenbuilder)
    tokenizer.tokenize_line(text)
  end
end
