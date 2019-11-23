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
      number = NumericConstantToken.new(m[0])
      line_number = LineNumber.new(number)
      line_text = m.post_match
      all_tokens = tokenize(line_text)
      all_tokens.delete_if(&:break?)
      all_tokens.delete_if(&:whitespace?)
      comment = nil

      comment = all_tokens.pop if
        !all_tokens.empty? && all_tokens[-1].comment?

      line = create(line_text, all_tokens, comment)
    end
    [line_number, line]
  end

  def create(text, all_tokens, comment)
    begin
      statement = create_statement(text, all_tokens)
    rescue BASICError => e
      statement = InvalidStatement.new(text, all_tokens, e)
    end

    Line.new(text, statement, all_tokens, comment)
  end

  def keywords_definitions
    keywords = []

    statement_classes.each do |cl|
      kwds = cl.lead_keywords.flatten
      kwds.each { |kwd| keywords << kwd.to_s }

      keywords += cl.extra_keywords
    end

    keywords.uniq
  end

  private

  def statement_classes
    [
      ArrPrintStatement,
      ArrReadStatement,
      ArrWriteStatement,
      ArrLetStatement,
      DataStatement,
      DefineFunctionStatement,
      DimStatement,
      EndStatement,
      FilesStatement,
      ForStatement,
      GosubStatement,
      GotoStatement,
      IfStatement,
      InputStatement,
      LetStatement,
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

  def create_statement(text, statement_tokens)
    statement = EmptyStatement.new

    unless statement_tokens.empty?
      statement = nil

      keywords, tokens = extract_keywords(statement_tokens)

      while statement.nil?
        if @statement_definitions.key?(keywords)
          tokens_lists = split_keywords(tokens)

          statement =
            @statement_definitions[keywords].new(keywords, tokens_lists)
        else
          if keywords.empty?
            statement = UnknownStatement.new(text) if statement.nil?
          else
            keyword = keywords.pop
            tokens.unshift(keyword)
          end
        end
      end
    end

    statement
  end

  def tokenize(text)
    invalid_tokenbuilder = InvalidTokenBuilder.new
    tokenizer = Tokenizer.new(@tokenbuilders, invalid_tokenbuilder)
    tokenizer.tokenize(text)
  end
end

# parent of all statement classes
class AbstractStatement
  attr_reader :errors
  attr_reader :keywords
  attr_reader :tokens
  attr_reader :valid
  attr_reader :executable
  attr_reader :comment
  attr_reader :numerics
  attr_reader :strings
  attr_reader :variables
  attr_reader :operators
  attr_reader :functions
  attr_reader :userfuncs
  attr_reader :linenums
  attr_reader :autonext
  attr_reader :mccabe

  def self.extra_keywords
    []
  end

  def initialize(keywords, tokens_lists)
    @keywords = keywords
    @executable = true
    @tokens = tokens_lists.flatten
    @errors = []
    @valid = true
    @comment = false
    @numerics = []
    @strings = []
    @variables = []
    @operators = []
    @functions = []
    @userfuncs = []
    @linenums = []
    @autonext = true
    @mccabe = 0
    @profile_count = 0
    @profile_time = 0
  end

  def pretty
    list = [AbstractToken.pretty_tokens(@keywords, @tokens)]
    list.join(' ')
  end

  def dump
    ['Unimplemented']
  end

  def gotos
    []
  end

  def print_errors(console_io)
    @errors.each { |error| console_io.print_line(' ' + error) }
  end

  def program_check(_, _, _)
    true
  end

  def preexecute_a_statement(line_number, interpreter, console_io)
    if errors.empty?
      pre_execute(interpreter)
    else
      interpreter.stop_running
      console_io.print_line("Errors in line #{line_number}:")
      print_errors(console_io)
    end
    errors.empty?
  end

  def print_trace_info(trace_out, current_line_number)
    trace_out.newline_when_needed
    trace_out.print_out current_line_number.to_s + ':' + pretty
    trace_out.newline
  end

  private

  def pre_execute(_) end

  public

  def reset_profile_metrics
    @profile_count = 0
    @profile_time = 0
  end

  def execute_a_statement(interpreter, _)
    timing = Benchmark.measure { execute(interpreter) }

    user_time = timing.utime + timing.cutime
    sys_time = timing.stime + timing.cstime
    time = user_time + sys_time

    @profile_time += time
    @profile_count += 1
  end

  def profile(show_timing)
    text = AbstractToken.pretty_tokens(@keywords, @tokens)
    if show_timing
      timing = @profile_time.round(4).to_s
      ' (' + timing + '/' + @profile_count.to_s + ')' + text
    else
      ' (' + @profile_count.to_s + ')' + text
    end
  end

  def renumber(_) end

  protected

  def check_template(tokens_lists, template)
    return false unless tokens_lists.size == template.size

    result = true
    zip = template.zip(tokens_lists)

    zip.each do |pair|
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
         (!list.empty? && (list[-1].operand? || list[-1].groupend?))
        lists << list unless list.empty?
        list = [token]
      elsif token.separator? && parens_level.zero?
        lists << list unless list.empty?
        lists << token if want_separators
        list = []
      else
        list << token
      end
      parens_level += 1 if token.groupstart?
      parens_level -= 1 if token.groupend? && !parens_level.zero?
    end

    lists << list unless list.empty?

    lists
  end

  def split_on_token(tokens, token_to_split)
    results = []
    list = []

    tokens.each do |token|
      if token.to_s != token_to_split
        list << token
      else
        results << list unless list.empty?
        list = []
        results << token
      end
    end

    results << list unless list.empty?

    results
  end

  def make_coord(c)
    [NumericConstant.new(c)]
  end

  def make_coords(r, c)
    [NumericConstant.new(r), NumericConstant.new(c)]
  end
end

# unparsed statement
class InvalidStatement < AbstractStatement
  def initialize(text, tokens_lists, error)
    super([], tokens_lists)

    @valid = false
    @executable = false
    @text = text
    @errors << 'Invalid statement: ' + error.message
  end

  def to_s
    @text
  end

  def execute(_)
    raise(BASICRuntimeError, @errors[0])
  end

  def pre_execute(_)
    raise(BASICRuntimeError, @errors[0])
  end
end

# unknown statement
class UnknownStatement < AbstractStatement
  def initialize(text)
    super([], [])

    @valid = false
    @executable = false
    @text = text
    @errors << "Unknown statement '#{@text.strip}'"
  end

  def to_s
    @text
  end

  def execute(_) end
end

# empty statement (line number only)
class EmptyStatement < AbstractStatement
  def initialize
    super([], [])

    @valid = false
    @executable = false
  end

  def dump
    []
  end

  def to_s
    ''
  end

  def execute(_) end
end

# REMARK
class RemarkStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('REMARK')],
      [KeywordToken.new('REM')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    @valid = false
    @comment = true
    @executable = false
    @rest = Remark.new(nil)
    @rest = Remark.new(tokens_lists[0]) unless tokens_lists.empty?
  end

  def dump
    [@rest.dump]
  end

  def execute(_) end
end

# common functions for IO statements
module FileFunctions
  def extract_file_handle(print_items)
    print_items = print_items.clone
    file_tokens = nil

    unless print_items.empty? ||
           print_items[0].carriage_control?

      candidate_file_tokens = print_items[0]

      if candidate_file_tokens.filehandle?
        file_tokens = print_items.shift

        print_items.shift if
          !print_items.empty? &&
          print_items[0].carriage_control?
      end
    end

    [file_tokens, print_items]
  end

  def get_file_handle(interpreter, file_tokens)
    return nil if file_tokens.nil?

    file_handles = file_tokens.evaluate(interpreter)
    file_handles[0]
  end

  def add_needed_value(print_items, shape)
    if print_items.empty? || !print_items[-1].printable?
      print_items << ValueExpression.new([], shape)
    end
  end

  def add_needed_carriage(print_items)
    if !print_items.empty? && print_items[-1].printable?
      print_items << CarriageControl.new('')
    end
  end

  def add_final_carriage(print_items, final)
    if !print_items.empty? && print_items[-1].printable?
      print_items << final
    end
  end

  def add_default_value_carriage(print_items, shape)
    if print_items.empty?
      add_needed_value(print_items, shape)
      add_final_carriage(print_items, CarriageControl.new('NL'))
    end
  end
end

# DATA
class DataStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('DATA')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    @executable = false

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @expressions = ValueExpression.new(tokens_lists[0], :scalar)
      @numerics = @expressions.numerics
      @strings = @expressions.strings
      @variables = @expressions.variables
      @operators = @expressions.operators
      @functions = @expressions.functions
      @userfuncs = @expressions.userfuncs
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    @expressions.dump
  end

  def pre_execute(interpreter)
    ds = interpreter.get_data_store(nil)
    data_list = @expressions.evaluate(interpreter)
    ds.store(data_list)
  end

  def execute(_) end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('DEF')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    @executable = false

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @definition = nil
      begin
        @definition = UserFunctionDefinition.new(tokens_lists[0])
        @numerics = @definition.numerics
        @strings = @definition.strings
        @variables = @definition.variables
        @operators = @definition.operators
        @functions = @definition.functions
        @userfuncs = @definition.userfuncs
      rescue BASICError => e
        puts e.message
        @errors << e.message
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    lines += @definition.dump unless @definition.nil?
    lines
  end

  def pre_execute(interpreter)
    name = @definition.name
    interpreter.set_user_function(name, @definition)
  end

  def execute(_) end
end

# DIM
class DimStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('DIM')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    @expression_list = []
    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], false)

      tokens_lists.each do |tokens_list|
        begin
          @expression_list << DeclarationExpression.new(tokens_list)
        rescue BASICExpressionError
          @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
        end
      end
    else
      @errors << 'Syntax error'
    end

    @expression_list.each { |expression| @numerics += expression.numerics }
    @expression_list.each { |expression| @strings += expression.strings }
    @expression_list.each { |expression| @variables += expression.variables }
    @expression_list.each { |expression| @operators += expression.operators }
    @expression_list.each { |expression| @functions += expression.functions }
    @expression_list.each { |expression| @userfuncs += expression.userfuncs }
  end

  def dump
    lines = []
    @expression_list.each { |expression| lines += expression.dump }
    lines
  end

  def execute(interpreter)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      subscripts = variable.subscripts

      if subscripts.empty?
        raise BASICRuntimeError, 'DIM statement requires subscript range'
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

  def initialize(keywords, tokens_lists)
    super

    @autonext = false
    @executable = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def dump
    ['']
  end

  def program_check(program, console_io, line_number)
    next_line = program.find_next_line_number(line_number)

    return true if next_line.nil?

    console_io.print_line("Statements after END in line #{line_number}")

    false
  end

  def execute(interpreter)
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

  def initialize(keywords, tokens_lists)
    super

    @executable = false

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @expressions = ValueExpression.new(tokens_lists[0], :scalar)
      @strings = @expressions.strings
      @variables = @expressions.variables
      @operators = @expressions.operators
      @functions = @expressions.functions
      @userfuncs = @expressions.userfuncs
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    @expressions.dump
  end

  def pre_execute(interpreter)
    file_names = @expressions.evaluate(interpreter)
    interpreter.add_file_names(file_names)
  end

  def execute(_) end
end

# FOR statement
class ForStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('FOR')]
    ]
  end

  def self.extra_keywords
    %w(TO STEP)
  end

  def initialize(keywords, tokens_lists)
    super

    template1 = [[1, '>='], 'TO', [1, '>=']]
    template2 = [[1, '>='], 'TO', [1, '>='], 'STEP', [1, '>=']]

    if check_template(tokens_lists, template1)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        variable_name = VariableName.new(tokens1[0])
        @control = Variable.new(variable_name, :scalar, [])
        @start = ValueExpression.new(tokens2, :scalar)
        @end = ValueExpression.new(tokens_lists[2], :scalar)
        @step = nil
        @numerics = @start.numerics + @end.numerics
        @strings = @start.strings + @end.strings
        control = XrefEntry.new(@control.to_s, nil, true)
        @variables = [control] + @start.variables + @end.variables
        @operators = @start.operators + @end.operators
        @functions = @start.functions + @end.functions
        @userfuncs = @start.userfuncs + @end.userfuncs
        @mccabe = 1
      rescue BASICExpressionError => e
        @errors << e.message
      end
    elsif check_template(tokens_lists, template2)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        variable_name = VariableName.new(tokens1[0])
        @control = Variable.new(variable_name, :scalar, [])
        @start = ValueExpression.new(tokens2, :scalar)
        @end = ValueExpression.new(tokens_lists[2], :scalar)
        @step = ValueExpression.new(tokens_lists[4], :scalar)
        @numerics = @start.numerics + @end.numerics + @step.numerics
        @strings = @start.strings + @end.strings + @step.strings
        control = XrefEntry.new(@control.to_s, nil, true)

        @variables =
          [control] + @start.variables + @end.variables + @step.variables

        @operators = @start.operators + @end.operators + @step.operators
        @functions = @start.functions + @end.functions + @step.functions
        @userfuncs = @start.userfuncs + @end.userfuncs + @step.userfuncs
        @mccabe = 1
      rescue BASICExpressionError => e
        @errors << e.message
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    lines << 'control: ' + @control.dump
    lines << 'start:   ' + @start.dump.to_s
    lines << 'end:     ' + @end.dump.to_s
    lines << 'step:    ' + @step.dump.to_s unless @step.nil?
    lines
  end

  def execute(interpreter)
    from = @start.evaluate(interpreter)[0]
    to = @end.evaluate(interpreter)[0]
    step = NumericConstant.new(1)
    step = @step.evaluate(interpreter)[0] unless @step.nil?

    fornext_control = interpreter.assign_fornext(@control.name, from, to, step)
    interpreter.lock_variable(@control.name)
    interpreter.enter_fornext(@control.name)
    terminated = fornext_control.front_terminated?

    if terminated
      interpreter.next_line_number =
        interpreter.find_closing_next(@control.name)

      interpreter.unlock_variable(@control.name)
      interpreter.exit_fornext
    end

    io = interpreter.trace_out
    print_more_trace_info(io, from, to, step, terminated)
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

  def print_more_trace_info(io, from, to, step, terminated)
    io.trace_output(" #{@start} = #{from}") unless @start.numeric_constant?
    io.trace_output(" #{@end} = #{to}") unless @end.numeric_constant?
    io.trace_output(" #{@step} = #{step}") unless
      @step.nil? || @step.numeric_constant?
    io.trace_output(" terminated:#{terminated}")
  end
end

# GOSUB
class GosubStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('GOSUB')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    template = [[1]]

    if check_template(tokens_lists, template)
      if tokens_lists[0][0].numeric_constant?
        @destination = LineNumber.new(tokens_lists[0][0])
        @linenums = [@destination]
      else
        @errors << "Invalid line number #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    [@destination.dump]
  end

  def gotos
    [@destination]
  end

  def program_check(program, console_io, line_number)
    return true if program.line_number?(@destination)

    console_io.print_line(
      "Line number #{@destination} not found in line #{line_number}"
    )

    false
  end

  def execute(interpreter)
    interpreter.push_return(interpreter.next_line_number)
    interpreter.next_line_number = @destination
  end

  def renumber(renumber_map)
    @destination = renumber_map[@destination]
    @linenums = [@destination]
    @tokens[-1] = NumericConstantToken.new(@destination.line_number)
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('GOTO')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    @autonext = false

    template = [[1]]

    if check_template(tokens_lists, template)
      if tokens_lists[0][0].numeric_constant?
        @destination = LineNumber.new(tokens_lists[0][0])
        @linenums = [@destination]
      else
        @errors << "Invalid line number #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    [@destination.dump]
  end

  def gotos
    [@destination]
  end

  def program_check(program, console_io, line_number)
    return true if program.line_number?(@destination)

    console_io.print_line(
      "Line number #{@destination} not found in line #{line_number}"
    )

    false
  end

  def execute(interpreter)
    interpreter.next_line_number = @destination
  end

  def renumber(renumber_map)
    @destination = renumber_map[@destination]
    @linenums = [@destination]
    @tokens[-1] = NumericConstantToken.new(@destination.line_number)
  end
end

# common functions for IF statements
class AbstractIfStatement < AbstractStatement
  def initialize(_, _)
    super
  end

  def execute(interpreter)
    values = @expression.evaluate(interpreter)

    raise(BASICRuntimeError, 'Expression error') unless
      values.size == 1

    result = values[0]

    raise(BASICRuntimeError, 'Expression error') unless
      result.class.to_s == 'BooleanConstant'

    interpreter.next_line_number = @destination if result.value

    s = ' ' + @expression.to_s + ': ' + result.to_s
    io = interpreter.trace_out
    io.trace_output(s)
  end

  def renumber(renumber_map)
    @destination = renumber_map[@destination]
    @linenums = [@destination]
    @tokens[-1] = NumericConstantToken.new(@destination.line_number)
  end

  def dump
    lines = []
    lines += @expression.dump unless @expression.nil?
    lines
  end

  def gotos
    [@destination]
  end

  def program_check(program, console_io, line_number)
    return true if program.line_number?(@destination)

    if @destination.nil?
      console_io.print_line(
        "Invalid or missing line number in line #{line_number}"
      )
    else
      console_io.print_line(
        "Line number #{@destination} not found in line #{line_number}"
      )
    end

    false
  end
end

# IF/THEN
class IfStatement < AbstractIfStatement
  def self.lead_keywords
    [
      [KeywordToken.new('IF')]
    ]
  end

  def self.extra_keywords
    ['THEN']
  end

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>='], 'THEN', [1]]

    if check_template(tokens_lists, template)
      begin
        @destination = LineNumber.new(tokens_lists[2][0])
      rescue BASICSyntaxError => e
        @errors << e.message
      end

      begin
        @expression = ValueExpression.new(tokens_lists[0], :scalar)
      rescue BASICExpressionError => e
        @errors << e.message
      end

      @numerics = @expression.numerics unless @expression.nil?
      @strings = @expression.strings unless @expression.nil?
      @variables = @expression.variables unless @expression.nil?
      @operators = @expression.operators unless @expression.nil?
      @functions = @expression.functions unless @expression.nil?
      @userfuncs = @expression.userfuncs unless @expression.nil?
      @linenums = [@destination]
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

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      input_items = split_tokens(tokens_lists[0], false)
      input_items = tokens_to_expressions(input_items)
      @file_tokens, input_items = extract_file_handle(input_items)
      @prompt, @input_items = extract_prompt(input_items)

      if !@input_items.empty? && @input_items[0].text_constant?
        @prompt = input_items[0]
        @input_items = @input_items[1..-1]
      end

      make_references
      @mccabe = @input_items.size
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    @input_items.each { |item| lines += item.dump } unless @input_items.nil?
    lines
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :read)

    prompt = nil

    unless @prompt.nil?
      prompts = @prompt.evaluate(interpreter)
      prompt = prompts[0]
    end

    if fh.nil?
      values = input_values(fhr, interpreter, prompt, @input_items.size)
      fhr.implied_newline
    else
      values = file_values(fhr, interpreter)
    end

    raise(BASICRuntimeError, 'Not enough values') if
      values.size < @input_items.size

    name_value_pairs =
      zip(@input_items, values[0..@input_items.length])

    name_value_pairs.each do |hash|
      l_values = hash['name'].evaluate(interpreter)
      l_value = l_values[0]
      value = hash['value']
      interpreter.set_value(l_value, value)
    end

    interpreter.clear_previous_lines
  end

  private

  include FileFunctions

  def make_references
    @numerics = @file_tokens.numerics unless @file_tokens.nil?
    @input_items.each { |item| @numerics += item.numerics }

    @strings = @prompt.strings unless @prompt.nil?
    @strings += @file_tokens.strings unless @file_tokens.nil?
    @input_items.each { |item| @strings += item.strings }

    @variables = @file_tokens.variables unless @file_tokens.nil?
    @input_items.each { |item| @variables += item.variables }

    @operators = @file_tokens.operators unless @file_tokens.nil?
    @input_items.each { |item| @operators += item.operators }

    @functions = @file_tokens.functions unless @file_tokens.nil?
    @input_items.each { |item| @functions += item.functions }

    @userfuncs = @file_tokens.userfuncs unless @file_tokens.nil?
    @input_items.each { |item| @userfuncs += item.userfuncs }
  end

  def first_token(input_items)
    input_items[0][0]
  end

  def first_value(input_items, interpreter)
    first_list = input_items[0]
    expr = ValueExpression.new(first_list, :scalar)
    values = expr.evaluate(interpreter)
    values[0]
  end

  def extract_prompt(print_items)
    print_items = print_items.clone
    prompt = nil

    unless print_items.empty? ||
           print_items[0].carriage_control?

      candidate_prompt_tokens = print_items[0]

      if candidate_prompt_tokens.text_constant?
        prompt = print_items.shift

        print_items.shift if
          !print_items.empty? &&
          print_items[0].carriage_control?
      end
    end

    [prompt, print_items]
  end

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end

    print_items
  end

  def add_expression(print_items, tokens)
    if tokens[0].operator? && tokens[0].pound?
      print_items << ValueExpression.new(tokens, :scalar)
    elsif tokens[0].text_constant?
      print_items << ValueExpression.new(tokens, :scalar)
    else
      print_items << TargetExpression.new(tokens, :scalar)
    end

  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
  end

  def zip(names, values)
    raise(BASICRuntimeError, 'Too few values') if values.size < names.size

    results = []
    (0...names.size).each do |i|
      raise(BASICRuntimeError, names[i].to_s + ' is not assignable') unless
        names[i].target?

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
end

# common functions for LET and LET-less statements
class AbstractLetStatement < AbstractStatement
  def initialize(_, _)
    super
  end

  def dump
    lines = []
    lines += @assignment.dump unless @assignment.nil?
    lines
  end
end

# common functions for scalar LET and LET-less statement
class AbstractScalarLetStatement < AbstractLetStatement
  def initialize(_, tokens_lists)
    super

    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = Assignment.new(tokens_lists[0], :scalar)

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value != 1
          @errors << 'Assignment must have only one right-hand value'
        end

        @numerics = @assignment.numerics
        @strings = @assignment.strings
        @variables = @assignment.variables
        @operators = @assignment.operators
        @functions = @assignment.functions
        @userfuncs = @assignment.userfuncs
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

  def initialize(_, _)
    super
  end

  def execute(interpreter)
    l_values = @assignment.eval_target(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]

    l_values.each do |l_value|
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

  attr_reader :control

  def initialize(keywords, tokens_lists)
    super

    template = [[1]]

    if check_template(tokens_lists, template)
      # parse control variable
      @control = nil
      if tokens_lists[0][0].variable?
        variable_name = VariableName.new(tokens_lists[0][0])
        @control = Variable.new(variable_name, :scalar, [])
        controlx = XrefEntry.new(@control.to_s, nil, false)
        @variables = [controlx]
      else
        @errors << "Invalid control variable #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    [@control.dump]
  end

  def execute(interpreter)
    fornext_control = interpreter.retrieve_fornext(@control.name)

    if interpreter.match_fornext?
      # check control variable matches current loop
      expected = interpreter.top_fornext
      actual = fornext_control.control
      if actual != expected
        raise(BASICRuntimeError,
              "Found NEXT #{actual} when expecting #{expected}")
      end
    end

    # check control variable value
    # if matches end value, stop here
    terminated = fornext_control.terminated?(interpreter)
    io = interpreter.trace_out
    s = ' terminated:' + terminated.to_s
    io.trace_output(s)

    if terminated
      interpreter.unlock_variable(@control.name)
      interpreter.exit_fornext
    else
      # set next line from top item
      interpreter.next_line_number = fornext_control.loop_start_number
      # change control variable value
      fornext_control.bump_control(interpreter)
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

  def self.extra_keywords
    %w(
      BASE DEFAULT_PROMPT DETECT_INFINITE_LOOP
      ECHO FIELD_SEP
      IGNORE_RND_ARG IMPLIED_SEMICOLON
      INT_FLOOR LOCK_FORNEXT MATCH_FORNEXT NEWLINE_SPEED
      PRECISION PRINT_SPEED PRINT_WIDTH PROMPT_COUNT PROVENANCE
      QMARK_AFTER_PROMPT REQUIRE_INITIALIZED SEMICOLON_ZONE_WIDTH
      TRACE ZONE_WIDTH
    )
  end

  def initialize(keywords, tokens_lists)
    super

    template = [OptionStatement.extra_keywords, [1, '>=']]

    if check_template(tokens_lists, template)
      @key = tokens_lists[0].to_s.downcase
      expression_tokens = split_tokens(tokens_lists[1], true)
      @expression = ValueExpression.new(expression_tokens[0], :scalar)
      @numerics = @expression.numerics
      @strings = @expression.strings
      @variables = @expression.variables
      @operators = @expression.operators
      @functions = @expression.functions
      @userfuncs = @expression.userfuncs
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    lines += @expression.dump unless @expression.nil?
    lines
  end

  def execute(interpreter)
    values = @expression.evaluate(interpreter)
    value0 = values[0]

    interpreter.set_action(@key, value0.to_v)
  end
end

# common for PRINT, ARR PRINT, MAT PRINT
class AbstractPrintStatement < AbstractStatement
  def initialize(keywords, tokens_lists, final_carriage)
    super(keywords, tokens_lists)

    @final = final_carriage
  end

  def dump
    lines = []

    unless @file_tokens.nil?
      lines += @file_tokens.dump
    end

    @print_items.each { |item| lines += item.dump } unless @print_items.nil?
    lines
  end

  def make_references
    @numerics = @file_tokens.numerics unless @file_tokens.nil?
    @print_items.each { |item| @numerics += item.numerics }

    @strings = @file_tokens.strings unless @file_tokens.nil?
    @print_items.each { |item| @strings += item.strings }

    @variables = @file_tokens.variables unless @file_tokens.nil?
    @print_items.each { |item| @variables += item.variables }

    @operators = @file_tokens.operators unless @file_tokens.nil?
    @print_items.each { |item| @operators += item.operators }

    @functions = @file_tokens.functions unless @file_tokens.nil?
    @print_items.each { |item| @functions += item.functions }

    @userfuncs = @file_tokens.userfuncs unless @file_fokens.nil?
    @print_items.each { |item| @userfuncs += item.userfuncs }
  end

  include FileFunctions
end

# PRINT
class PrintStatement < AbstractPrintStatement
  def self.lead_keywords
    [
      [KeywordToken.new('PRINT')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super(keywords, tokens_lists, CarriageControl.new('NL'))

    template1 = []
    template2 = [[1, '>=']]

    if check_template(tokens_lists, template1)
      @print_items = tokens_to_expressions([])
    elsif check_template(tokens_lists, template2)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
      make_references
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.print(fhr, interpreter)
        carriage.print(fhr, interpreter)
      end

      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        begin
          add_needed_carriage(print_items)
          print_items << ValueExpression.new(tokens_list, :scalar)
        rescue BASICExpressionError
          line_text = tokens_list.map(&:to_s).join

          @errors <<
            'Syntax error: "' + line_text + '" is not a value or operator'
        end
      elsif tokens_list.separator?
        add_needed_value(print_items, :scalar)
        print_items << CarriageControl.new(tokens_list.to_s)
      end
    end

    add_final_carriage(print_items, @final)
    add_default_value_carriage(print_items, :scalar)
    print_items
  end
end

# common for READ, ARR READ, MAT READ
class AbstractReadStatement < AbstractStatement
  def initialize(keywords, tokens_lists)
    super
  end

  def dump
    lines = []
    @read_items.each { |item| lines += item.dump } unless @read_items.nil?
    lines
  end

  def make_references
    @numerics = @file_tokens.numerics unless @file_tokens.nil?
    @read_items.each { |item| @numerics += item.numerics }

    @strings = @file_tokens.strings unless @file_tokens.nil?
    @read_items.each { |item| @strings += item.strings }

    @variables = @file_tokens.variables unless @file_tokens.nil?
    @read_items.each { |item| @variables += item.variables }

    @operators = @file_tokens.operators unless @file_tokens.nil?
    @read_items.each { |item| @operators += item.operators }

    @functions = @file_tokens.functions unless @file_tokens.nil?
    @read_items.each { |item| @functions += item.functions }

    @userfuncs = @file_tokens.userfuncs unless @file_tokens.nil?
    @read_items.each { |item| @userfuncs += item.userfuncs }
  end

  include FileFunctions
end

# READ
class ReadStatement < AbstractReadStatement
  def self.lead_keywords
    [
      [KeywordToken.new('READ')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      read_items = split_tokens(tokens_lists[0], false)
      read_items = tokens_to_expressions(read_items)
      @file_tokens, @read_items = extract_file_handle(read_items)
      make_references
      @mccabe = @read_items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @read_items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        value = ds.read
        interpreter.set_value(target, value)
      end
    end

    interpreter.clear_previous_lines
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end

    print_items
  end

  def add_expression(print_items, tokens)
    if tokens[0].operator? && tokens[0].pound?
      print_items << ValueExpression.new(tokens, :scalar)
    else
      print_items << TargetExpression.new(tokens, :scalar)
    end

  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
  end
end

# RESTORE
class RestoreStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('RESTORE')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def dump
    ['']
  end

  def execute(interpreter)
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

  def initialize(keywords, tokens_lists)
    super
    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def dump
    ['']
  end

  def execute(interpreter)
    interpreter.next_line_number = interpreter.pop_return
  end
end

# STOP
class StopStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('STOP')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    @autonext = false

    template = []

    @errors << 'Syntax error' unless check_template(tokens_lists, template)
  end

  def dump
    ['']
  end

  def execute(interpreter)
    io = interpreter.console_io
    io.newline_when_needed
    interpreter.stop
  end
end

# common for WRITE, ARR WRITE, MAT WRITE
class AbstractWriteStatement < AbstractStatement
  def initialize(keywords, tokens_lists, final_carriage)
    super(keywords, tokens_lists)
    @final = final_carriage
  end

  def dump
    lines = []
    @print_items.each { |item| lines += item.dump } unless @print_items.nil?
    lines
  end

  def make_references
    @numerics = @file_tokens.numerics unless @file_tokens.nil?
    @print_items.each { |item| @numerics += item.numerics }

    @strings = @file_tokens.strings unless @file_tokens.nil?
    @print_items.each { |item| @strings += item.strings }

    @variables = @file_tokens.variables unless @file_tokens.nil?
    @print_items.each { |item| @variables += item.variables }

    @operators = @file_tokens.operators unless @file_tokens.nil?
    @print_items.each { |item| @operators += item.operators }

    @functions = @file_tokens.functions unless @file_tokens.nil?
    @print_items.each { |item| @functions += item.functions }

    @userfuncs = @file_tokens.userfuncs unless @file_tokens.nil?
    @print_items.each { |item| @userfuncs += item.userfuncs }
  end

  include FileFunctions
end

# WRITE
class WriteStatement < AbstractWriteStatement
  def self.lead_keywords
    [
      [KeywordToken.new('WRITE')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super(keywords, tokens_lists, CarriageControl.new('NL'))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
      make_references
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.write(fhr, interpreter)
        carriage.write(fhr, interpreter)
      end

      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        begin
          add_needed_carriage(print_items)
          print_items << ValueExpression.new(tokens_list, :scalar)
        rescue BASICExpressionError
          line_text = tokens_list.map(&:to_s).join

          @errors <<
            'Syntax error: "' + line_text + '" is not a value or operator'
        end
      elsif tokens_list.separator?
        add_needed_value(print_items, :scalar)
        print_items << CarriageControl.new(tokens_list.to_s)
      end
    end

    add_final_carriage(print_items, @final)
    add_default_value_carriage(print_items, :scalar)
    print_items
  end
end

# ARR PRINT
class ArrPrintStatement < AbstractPrintStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('PRINT')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super(keywords, tokens_lists, CarriageControl.new('NL'))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
      make_references
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.compound_print(fhr, interpreter)
        carriage.print(fhr, interpreter)
      end

      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        print_items << ValueExpression.new(tokens_list, :array)
      elsif tokens_list.separator?
        print_items << CarriageControl.new(tokens_list)
      end
    end

    add_final_carriage(print_items, @final)
    add_default_value_carriage(print_items, :array)
    print_items
  end
end

# ARR READ
class ArrReadStatement < AbstractReadStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('READ')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      read_items = split_tokens(tokens_lists[0], false)
      read_items = tokens_to_expressions(read_items)
      @file_tokens, @read_items = extract_file_handle(read_items)
      make_references
      @mccabe = @read_items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @read_items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?
        read_values(target.name, interpreter, ds)
      end
    end

    interpreter.clear_previous_lines
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end

    print_items
  end

  def add_expression(print_items, tokens)
    if tokens[0].operator? && tokens[0].pound?
      print_items << ValueExpression.new(tokens, :scalar)
    else
      print_items << TargetExpression.new(tokens, :array)
    end

  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
  end

  def read_values(name, interpreter, ds)
    dims = interpreter.get_dimensions(name)

    case dims.size
    when 1
      read_array(name, dims, interpreter, ds)
    else
      raise(BASICRuntimeError, 'Dimensions for ARR READ must be 1')
    end
  end

  def read_array(name, dims, interpreter, ds)
    values = {}

    base = interpreter.base
    (base..dims[0].to_i).each do |col|
      coord = make_coord(col)
      values[coord] = ds.read
    end

    interpreter.set_values(name, values)
  end
end

# ARR WRITE
class ArrWriteStatement < AbstractWriteStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('WRITE')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super(keywords, tokens_lists, CarriageControl.new('NL'))

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
      make_references
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.compound_write(fhr, interpreter)
        carriage.write(fhr, interpreter)
      end

      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        print_items << ValueExpression.new(tokens_list, :array)
      elsif tokens_list.separator?
        print_items << CarriageControl.new(tokens_list)
      end
    end

    add_final_carriage(print_items, @final)
    add_default_value_carriage(print_items, :array)
    print_items
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

  def initialize(_, tokens_lists)
    super
    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = Assignment.new(tokens_lists[0], :array)

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value != 1
          @errors << 'Assignment must have only one right-hand value'
        end

        @numerics = @assignment.numerics
        @strings = @assignment.strings
        @variables = @assignment.variables
        @operators = @assignment.operators
        @functions = @assignment.functions
      rescue BASICError => e
        @errors << e.message
        @assignment = @rest
      end
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    r_value = first_value(interpreter)
    dims = r_value.dimensions
    values = r_value.values(interpreter)

    l_values = @assignment.eval_target(interpreter)
    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, dims)
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

    raise(BASICRuntimeError, 'Expected Array') if
      r_value.class.to_s != 'BASICArray'

    r_value
  end
end

# MAT PRINT
class MatPrintStatement < AbstractPrintStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('PRINT')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super(keywords, tokens_lists, CarriageControl.new('NL'))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
      make_references
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    @print_items.each do |item|
      if item.printable? &&
         i < @print_items.size &&
         !@print_items[i + 1].printable?
        item.compound_print(fhr, interpreter)
        # always print newline between items,
        # regardless of carriage separators in program
        @final.print(fhr, interpreter)
      end

      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        print_items << ValueExpression.new(tokens_list, :matrix)
      elsif tokens_list.separator?
        print_items << CarriageControl.new(tokens_list)
      end
    end

    add_final_carriage(print_items, @final)
    add_default_value_carriage(print_items, :matrix)
    print_items
  end
end

# MAT READ
class MatReadStatement < AbstractReadStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('READ')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      read_items = split_tokens(tokens_lists[0], false)
      read_items = tokens_to_expressions(read_items)
      @file_tokens, @read_items = extract_file_handle(read_items)
      make_references
      @mccabe = @read_items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @read_items.each do |item|
      targets = item.evaluate(interpreter)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?
        read_values(target.name, interpreter, ds)
      end
    end

    interpreter.clear_previous_lines
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end

    print_items
  end

  def add_expression(print_items, tokens)
    if tokens[0].operator? && tokens[0].pound?
      print_items << ValueExpression.new(tokens, :scalar)
    else
      print_items << TargetExpression.new(tokens, :matrix)
    end

  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
  end

  def read_values(name, interpreter, ds)
    dims = interpreter.get_dimensions(name)

    case dims.size
    when 1
      read_vector(name, dims, interpreter, ds)
    when 2
      read_matrix(name, dims, interpreter, ds)
    else
      raise(BASICRuntimeError, 'Dimensions for MAT READ must be 1 or 2')
    end
  end

  def read_vector(name, dims, interpreter, ds)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |col|
      coord = make_coord(col)
      values[coord] = ds.read
    end

    interpreter.set_values(name, values)
  end

  def read_matrix(name, dims, interpreter, ds)
    values = {}

    base = $options['base'].value

    (base..dims[0].to_i).each do |row|
      (base..dims[1].to_i).each do |col|
        coords = make_coords(row, col)
        values[coords] = ds.read
      end
    end

    interpreter.set_values(name, values)
  end
end

# MAT WRITE
class MatWriteStatement < AbstractWriteStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('WRITE')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super(keywords, tokens_lists, CarriageControl.new('NL'))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
      make_references
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.compound_write(fhr, interpreter)
        carriage.write(fhr, interpreter)
      end

      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        print_items << ValueExpression.new(tokens_list, :matrix)
      elsif tokens_list.separator?
        print_items << CarriageControl.new(tokens_list)
      end
    end

    add_final_carriage(print_items, @final)
    add_default_value_carriage(print_items, :matrix)
    print_items
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

  def initialize(_, tokens_lists)
    super
    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = Assignment.new(tokens_lists[0], :matrix)

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value != 1
          @errors << 'Assignment must have only one right-hand value'
        end

        @numerics = @assignment.numerics
        @strings = @assignment.strings
        @variables = @assignment.variables
        @operators = @assignment.operators
        @functions = @assignment.functions
      rescue BASICError => e
        @errors << e.message
        @assignment = @rest
      end
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    l_values = @assignment.eval_target(interpreter)
    l_value = l_values[0]
    l_dims = interpreter.get_dimensions(l_value.name)

    interpreter.set_default_args('CON', l_dims)
    interpreter.set_default_args('IDN', l_dims)
    interpreter.set_default_args('ZER', l_dims)

    # evaluate, use default args if needed
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]

    raise(BASICRuntimeError, 'Expected Matrix') if
      r_value.class.to_s != 'Matrix'

    interpreter.set_default_args('CON', nil)
    interpreter.set_default_args('IDN', nil)
    interpreter.set_default_args('ZER', nil)

    r_dims = r_value.dimensions
    values = r_value.values_1 if r_dims.size == 1
    values = r_value.values_2 if r_dims.size == 2

    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, r_dims)
      interpreter.set_values(l_value.name, values)
    end
  end
end
