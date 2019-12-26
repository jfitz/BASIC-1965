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
      ArrInputStatement,
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
      MatInputStatement,
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
  attr_reader :separators
  attr_reader :valid
  attr_reader :executable
  attr_reader :comment
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
    @separators = get_separators(@tokens)
    @errors = []
    @valid = true
    @comment = false
    @elements = {numerics: [], strings: [], variables: [], operators: [], functions: [], userfuncs: []}
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

  def numerics
    @elements[:numerics]
  end

  def strings
    @elements[:strings]
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

  def get_separators(tokens)
    wanted = ['(', ')', '[', ']', ',', ';']

    separators = []

    tokens.each do |token|
      separators << token if wanted.include?(token.to_s)
    end

    separators
  end

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

  def make_references(items, exp1 = nil, exp2 = nil)
    numerics = []
    strings = []
    variables = []
    operators = []
    functions = []
    userfuncs = []

    unless exp1.nil?
      numerics += exp1.numerics
      strings += exp1.strings
      variables += exp1.variables
      operators += exp1.operators
      functions += exp1.functions
      userfuncs += exp1.userfuncs
    end

    unless exp2.nil?
      numerics += exp2.numerics
      strings += exp2.strings
      variables += exp2.variables
      operators += exp2.operators
      functions += exp2.functions
      userfuncs += exp2.userfuncs
    end

    unless items.nil?
      items.each { |item| numerics += item.numerics }
      items.each { |item| strings += item.strings }
      items.each { |item| variables += item.variables }
      items.each { |item| operators += item.operators }
      items.each { |item| functions += item.functions }
      items.each { |item| userfuncs += item.userfuncs }
    end

    {numerics: numerics, strings: strings, variables: variables, operators: operators, functions: functions, userfuncs: userfuncs}
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
    if items.empty? || !items[-1].printable?
      items << ValueExpression.new([], shape)
    end
  end

  def add_needed_carriage(items)
    if !items.empty? && items[-1].printable?
      items << CarriageControl.new('')
    end
  end

  def add_final_carriage(items, final)
    if !items.empty? && items[-1].printable?
      items << final
    end
  end

  def add_default_value_carriage(items, shape)
    if items.empty?
      add_needed_value(items, shape)
      add_final_carriage(items, CarriageControl.new('NL'))
    end
  end

  def dump
    lines = []

    unless @file_tokens.nil?
      lines += @file_tokens.dump
    end

    @items.each { |item| lines += item.dump } unless @items.nil?
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

  def tokens_to_expressions(tokens_lists, shape)
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
      items << ValueExpression.new(tokens, :scalar)
    elsif tokens[0].text_constant?
      items << ValueExpression.new(tokens, :scalar)
    else
      items << TargetExpression.new(tokens, shape)
    end
  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
  end

  def zip(names, values)
    raise(BASICRuntimeError, 'Too few items') if values.size < names.size

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

  def add_expression(items, tokens, shape)
    if tokens[0].operator? && tokens[0].pound?
      items << ValueExpression.new(tokens, :scalar)
    else
      add_needed_carriage(items)
      items << ValueExpression.new(tokens, shape)
    end
  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join

    @errors <<
      'Syntax error: "' + line_text + '" is not a value or operator'
  end
end

# common functions for READ statements
module ReadFunctions
  def tokens_to_expressions(tokens_lists, shape)
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
      items << ValueExpression.new(tokens, :scalar)
    else
      items << TargetExpression.new(tokens, shape)
    end
  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
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
      items << ValueExpression.new(tokens, :scalar)
    else
      add_needed_carriage(items)
      items << ValueExpression.new(tokens, shape)
    end
  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join

    @errors <<
      'Syntax error: "' + line_text + '" is not a value or operator'
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
      @elements = make_references(nil, @expressions)
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
        @elements = make_references(nil, @definition)
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

    @expressions = []
    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], false)

      tokens_lists.each do |tokens_list|
        begin
          @expressions << DeclarationExpression.new(tokens_list)
        rescue BASICExpressionError
          @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
        end
      end
    else
      @errors << 'Syntax error'
    end

    @elements = make_references(@expressions)
  end

  def dump
    lines = []
    @expressions.each { |expression| lines += expression.dump }
    lines
  end

  def execute(interpreter)
    @expressions.each do |expression|
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
      @elements = make_references(nil, @expressions)
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
    %w[TO STEP]
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
        @elements[:numerics] = @start.numerics + @end.numerics
        @elements[:strings] = @start.strings + @end.strings
        control = XrefEntry.new(@control.to_s, nil, true)
        @elements[:variables] = [control] + @start.variables + @end.variables
        @elements[:operators] = @start.operators + @end.operators
        @elements[:functions] = @start.functions + @end.functions
        @elements[:userfuncs] = @start.userfuncs + @end.userfuncs
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
        @elements[:numerics] = @start.numerics + @end.numerics + @step.numerics
        @elements[:strings] = @start.strings + @end.strings + @step.strings
        control = XrefEntry.new(@control.to_s, nil, true)

        @elements[:variables] =
          [control] + @start.variables + @end.variables + @step.variables

        @elements[:operators] = @start.operators + @end.operators + @step.operators
        @elements[:functions] = @start.functions + @end.functions + @step.functions
        @elements[:userfuncs] = @start.userfuncs + @end.userfuncs + @step.userfuncs
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

    fornext_control = interpreter.assign_fornext(@control, from, to, step)
    interpreter.lock_variable(@control)
    interpreter.enter_fornext(@control)
    terminated = fornext_control.front_terminated?

    if terminated
      interpreter.next_line_number = interpreter.find_closing_next(@control)
      interpreter.unlock_variable(@control)
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
        @elements = make_references(nil, @expression)
      rescue BASICExpressionError => e
        @errors << e.message
      end

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

  include FileFunctions
  include InputFunctions

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :scalar)
      @file_tokens = extract_file_handle(@items)
      @prompt = extract_prompt(@items)
      @elements = make_references(@items, @file_tokens, @prompt)
      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
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

    raise(BASICRuntimeError, 'Not enough values') if
      values.size < item_names.size

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

        @elements = make_references(nil, @assignment)
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

    # allow multiple left-hand side values
    # but only one right-hand side value
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
        @elements[:variables] = [controlx]
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
    fornext_control = interpreter.retrieve_fornext(@control)

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
      interpreter.unlock_variable(@control)
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
      @elements = make_references(nil, @expression)
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

# PRINT
class PrintStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('PRINT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(keywords, tokens_lists)
    super

    template1 = []
    template2 = [[1, '>=']]

    if check_template(tokens_lists, template1)
      @items = tokens_to_expressions([], :scalar)
    elsif check_template(tokens_lists, template2)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :scalar)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @items[i + 1] if
          i < @items.size &&
          !@items[i + 1].printable?
        item.print(fhr, interpreter)
        carriage.print(fhr, interpreter)
      end

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

  def initialize(keywords, tokens_lists)
    super
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :scalar)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
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

# WRITE
class WriteStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('WRITE')]
    ]
  end

  include FileFunctions
  include WriteFunctions

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :scalar)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @items[i + 1] if
          i < @items.size &&
          !@items[i + 1].printable?
        item.write(fhr, interpreter)
        carriage.write(fhr, interpreter)
      end

      i += 1
    end
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

  def initialize(keywords, tokens_lists)
    super
    
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array)
      @file_tokens = extract_file_handle(@items)
      @prompt = extract_prompt(@items)
      @elements = make_references(@items, @file_tokens, @prompt)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
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
        
        # make sure dimension is one
        dims = interpreter.get_dimensions(name)
        raise(BASICExpressionError, 'Not an array') unless dims.size == 1

        # build names
        base = interpreter.base
        (base..dims[0].to_i).each do |col|
          coord = make_coord(col)
          variable = Variable.new(name, :array, coord)
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

    raise(BASICRuntimeError, 'Not enough values') if
      values.size < item_names.size

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

# ARR PRINT
class ArrPrintStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('PRINT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(keywords, tokens_lists)
    super
    
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @items[i + 1] if
          i < @items.size &&
          !@items[i + 1].printable?
        item.compound_print(fhr, interpreter)
        carriage.print(fhr, interpreter)
      end

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

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :array)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @items.each do |item|
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
class ArrWriteStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR'), KeywordToken.new('WRITE')]
    ]
  end

  include FileFunctions
  include WriteFunctions

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @items[i + 1] if
          i < @items.size &&
          !@items[i + 1].printable?
        item.compound_write(fhr, interpreter)
        carriage.write(fhr, interpreter)
      end

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

        @elements = make_references(nil, @assignment)
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
    
    interpreter.set_default_args('CON1', l_dims)
    interpreter.set_default_args('ZER1', l_dims)

    r_value = first_value(interpreter)

    interpreter.set_default_args('CON1', nil)
    interpreter.set_default_args('ZER1', nil)

    r_dims = r_value.dimensions

    values = r_value.values(interpreter)

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

    raise(BASICRuntimeError, 'Expected Array') if
      r_value.class.to_s != 'BASICArray'

    r_value
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

  def initialize(keywords, tokens_lists)
    super
    
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :array)
      @file_tokens = extract_file_handle(@items)
      @prompt = extract_prompt(@items)
      @elements = make_references(@items, @file_tokens, @prompt)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
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
        
        # make sure dimension is one or two
        dims = interpreter.get_dimensions(name)
        raise(BASICExpressionError, 'Not an array') unless
          dims.size == 1 || dims.size == 2

        # build names
        if dims.size == 1
          base = interpreter.base
          (base..dims[0].to_i).each do |col|
            coord = make_coord(col)
            variable = Variable.new(name, :matrix, coord)
            item_names << variable
          end
        end
        
        if dims.size == 2
          base = interpreter.base
          (base..dims[0].to_i).each do |row|
            (base..dims[1].to_i).each do |col|
              coords = make_coords(row, col)
              variable = Variable.new(name, :matrix, coords)
              item_names << variable
            end
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

    raise(BASICRuntimeError, 'Not enough values') if
      values.size < item_names.size

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

# MAT PRINT
class MatPrintStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('PRINT')]
    ]
  end

  include FileFunctions
  include PrintFunctions

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :matrix)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0

    @items.each do |item|
      if item.printable?
        item.compound_print(fhr, interpreter)
        carriage = CarriageControl.new('')
        carriage.print(fhr, interpreter)
      end

      i += 1
    end
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

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      items = split_tokens(tokens_lists[0], false)
      @items = tokens_to_expressions(items, :matrix)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
      @mccabe = @items.size
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @items.each do |item|
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
class MatWriteStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT'), KeywordToken.new('WRITE')]
    ]
  end

  include FileFunctions
  include WriteFunctions

  def initialize(keywords, tokens_lists)
    super

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      @items = tokens_to_expressions(tokens_lists, :matrix)
      @file_tokens = extract_file_handle(@items)
      @elements = make_references(@items, @file_tokens)
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    i = 0
    @items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @items[i + 1] if
          i < @items.size &&
          !@items[i + 1].printable?
        item.compound_write(fhr, interpreter)
        carriage.write(fhr, interpreter)
      end

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

        @elements = make_references(nil, @assignment)
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

    interpreter.set_default_args('CON2', l_dims)
    interpreter.set_default_args('CON', l_dims)
    interpreter.set_default_args('IDN', l_dims)
    interpreter.set_default_args('ZER2', l_dims)
    interpreter.set_default_args('ZER', l_dims)

    # evaluate, use default args if needed
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]

    raise(BASICRuntimeError, 'Expected Matrix') if
      r_value.class.to_s != 'Matrix'

    interpreter.set_default_args('CON2', nil)
    interpreter.set_default_args('CON', nil)
    interpreter.set_default_args('IDN', nil)
    interpreter.set_default_args('ZER2', nil)
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
