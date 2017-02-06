# split a line into arguments
class ArgSplitter
  attr_reader :args
  @args = []
  @current_arg = ''
  @parens_level = 0

  def self.split_tokens(tokens, want_separators)
    lists = []
    list = []
    parens_level = 0
    tokens.each do |token|
      if token.operand? && (!list.empty? && list[-1].operand?)
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
      parens_level -= 1 if token.groupend? && parens_level > 0
    end
    lists << list unless list.empty?
    lists
  end

  def self.in_string(c)
    @current_arg += c
    return unless c == '"'
    @args << @current_arg
    @current_arg = ''
  end

  def self.not_in_string(c)
    if [',', ';'].include?(c) && @parens_level.zero?
      separator(c)
    elsif c == '('
      open_parens
    elsif c == ')'
      close_parens
    else
      @current_arg += c
    end
  end

  def self.separator(c)
    @args << @current_arg unless @current_arg.empty?
    @current_arg = ''
    @args << c
  end

  def self.open_parens
    @current_arg += '('
    @parens_level += 1
  end

  def self.close_parens
    @current_arg += ')'
    @parens_level -= 1 unless @parens_level.zero?
  end
end

# Statement factory class
class StatementFactory
  def initialize
    @statement_definitions = statement_definitions
  end

  def parse(text)
    line_number = nil
    statement = nil
    m = /\A\d+/.match(text)
    unless m.nil?
      number = NumericConstantToken.new(m[0])
      line_number = LineNumber.new(number)
      statement = create(m.post_match)
    end
    [line_number, statement]
  end

  private

  def squeeze_out_spaces(text)
    squeezed_text = ''
    in_quotes = false
    text.each_char do |c|
      in_remark = squeezed_text.start_with?('REM')
      in_quotes = !in_quotes if c == '"'
      squeezed_text += c if c != ' ' || in_quotes || in_remark
    end
    squeezed_text
  end

  def create(text)
    squeezed = squeeze_out_spaces(text)
    return Line.new(text, EmptyStatement.new, []) if squeezed == ''
    return Line.new(text, RemarkStatement.new(text), []) if
      squeezed[0..2] == 'REM'

    tokens = tokenize(squeezed)
    keyword = ''
    keyword << tokens.shift.to_s while !tokens.empty? && tokens[0].keyword?
    begin
      statement = create_regular_statement(keyword, text, tokens)
    rescue BASICException
      statement = InvalidStatement.new(text)
    end
    Line.new(text, statement, tokens)
  end

  def create_regular_statement(keyword, text, tokens)
    statement = UnknownStatement.new(text)
    statement =
      @statement_definitions[keyword].new(text, tokens) unless
        keyword.empty?
    statement
  end

  def tokenize(text)
    tokenizers = make_tokenizers
    invalid_tokenizer = InvalidTokenBuilder.new
    tokenizer = Tokenizer.new(tokenizers, invalid_tokenizer)
    tokenizer.tokenize(text)
  end

  def statement_definitions
    {
      'ARRPRINT' => ArrPrintStatement,
      'ARRREAD' => ArrReadStatement,
      'ARR' => ArrLetStatement,
      'DATA' => DataStatement,
      'DEF' => DefineFunctionStatement,
      'DIM' => DimStatement,
      'END' => EndStatement,
      'FILES' => FilesStatement,
      'FOR' => ForStatement,
      'GOSUB' => GosubStatement,
      'GOTO' => GotoStatement,
      'IF' => IfStatement,
      'INPUT' => InputStatement,
      'LET' => LetStatement,
      'MATPRINT' => MatPrintStatement,
      'MATREAD' => MatReadStatement,
      'MAT' => MatLetStatement,
      'NEXT' => NextStatement,
      'PRINT' => PrintStatement,
      'READ' => ReadStatement,
      'RESTORE' => RestoreStatement,
      'RETURN' => ReturnStatement,
      'STOP' => StopStatement,
      'TRACE' => TraceStatement
    }
  end

  def make_tokenizers
    tokenizers = []

    keywords = statement_definitions.keys + %w(THEN TO STEP)
    tokenizers << ListTokenBuilder.new(keywords, KeywordToken)

    operators = [
      '+', '-', '*', '/', '^', '#',
      '<', '<=', '=', '>', '>=', '<>'
    ]
    tokenizers << ListTokenBuilder.new(operators, OperatorToken)

    tokenizers << BreakTokenBuilder.new

    tokenizers << ListTokenBuilder.new(['(', '['], GroupStartToken)
    tokenizers << ListTokenBuilder.new([')', ']'], GroupEndToken)
    tokenizers << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)

    tokenizers <<
      ListTokenBuilder.new(FunctionFactory.function_names, FunctionToken)
    tokenizers << ListTokenBuilder.new(('FNA'..'FNZ').to_a, UserFunctionToken)

    tokenizers << TextTokenBuilder.new
    tokenizers << NumberTokenBuilder.new
    tokenizers << VariableTokenBuilder.new
    tokenizers << ListTokenBuilder.new(%w(ON OFF), BooleanConstantToken)
  end
end

# parent of all statement classes
class AbstractStatement
  attr_reader :errors

  def initialize(keyword, text)
    @keyword = keyword
    @text = text
    @errors = []
  end

  def pre_execute(_)
    0
  end

  def list
    @text
  end

  def pretty
    if @errors.empty?
      ' ' + to_s
    else
      @text
    end
  end

  protected

  def remove_break_tokens(tokens)
    new_list = []

    tokens.each do |token|
      new_list << token unless token.class.to_s == 'BreakToken'
    end

    new_list
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
  def initialize(line)
    super('', line)
    @errors << "Invalid statement"
  end

  def to_s
    @text
  end

  def execute(interpreter, _)
    raise(BASICException, @errors[0])
  end

  def pre_execute(interpreter)
    raise(BASICException, @errors[0])
  end
end

# unknown statement
class UnknownStatement < AbstractStatement
  def initialize(line)
    super('', line)
    @errors << "Unknown statement '#{@text.strip}'"
  end

  def to_s
    @text
  end

  def execute(_, _)
    0
  end
end

# empty statement (line number only)
class EmptyStatement < AbstractStatement
  def initialize
    super('', '')
  end

  def to_s
    ''
  end

  def execute(_, _)
    0
  end
end

# REMARK
class RemarkStatement < AbstractStatement
  def initialize(line)
    # override the method to squeeze spaces from line
    squeezed = line.strip
    super('REM', line)
    @rest = squeezed[3..-1]
  end

  def to_s
    @keyword + @rest
  end

  def execute(_, _)
    0
  end
end

# DIM
class DimStatement < AbstractStatement
  def initialize(line, tokens)
    super('DIM', line)
    tokens = remove_break_tokens(tokens)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)

    @errors << 'No variables specified' if tokens_lists.empty?

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        @expression_list <<
          TargetExpression.new(tokens_list, VariableDimension)
      rescue BASICException
        @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
      end
    end
  end

  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end

  def execute(interpreter, _)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      subscripts = variable.subscripts
      if subscripts.empty?
        raise BASICException, 'DIM statement requires subscript range'
      end
      interpreter.set_dimensions(variable, subscripts)
    end
  end
end

# FILES
class FilesStatement < AbstractStatement
  def initialize(line, tokens)
    super('FILES', line)
    tokens = remove_break_tokens(tokens)
    @expressions = ValueScalarExpression.new(tokens)
  end

  def to_s
    @keyword + ' ' + @expressions.to_s
  end

  def pre_execute(interpreter)
    file_names = @expressions.evaluate(interpreter)
    interpreter.add_file_names(file_names)
  end

  def execute(_, _)
    0
  end
end

# LET
class LetStatement < AbstractStatement
  def initialize(line, tokens)
    super('LET', line)
    tokens = remove_break_tokens(tokens)
    begin
      @assignment = ScalarAssignment.new(tokens)
      if @assignment.count_target.zero?
        @errors << 'Assignment must have left-hand value(s)'
      end
      if @assignment.count_value != 1
        @errors << 'Assignment must have only one right-hand value'
      end
    rescue BASICException => e
      @errors << e.message
    end
  end

  def to_s
    @keyword + ' ' + @assignment.to_s
  end

  def execute(interpreter, trace)
    l_values = @assignment.eval_target(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    l_values.each do |l_value|
      interpreter.set_value(l_value, r_value, trace)
    end
  end
end

# INPUT
class InputStatement < AbstractStatement
  def initialize(line, tokens)
    super('INPUT', line)
    tokens = remove_break_tokens(tokens)
    @tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # [prompt string] variable [variable]...

    @default_prompt = TextConstantToken.new('"? "')
  end

  def to_s
    list = []
    @tokens_lists.each do |tokens_list|
      s = ''
      tokens_list.each { |token| s += token.to_s }
      list << s
    end
    @keyword + ' ' + list.join(', ')
  end

  def execute(interpreter, trace)
    tokens_lists = @tokens_lists.clone
    prompt = @default_prompt
    unless tokens_lists.size.zero?
      begin
        value = first_value(tokens_lists, interpreter)
        fh = nil
        if value.class.to_s == 'FileHandle'
          fh = value
          tokens_lists.shift
          value = first_value(tokens_lists, interpreter)
        end
        token = first_token(tokens_lists)
        if token.text_constant?
          prompt = value
          tokens_lists.shift
        end
      rescue BASICException
      end
    end
    expression_list = []
    tokens_lists.each do |items_list|
      begin
        expression_list << TargetExpression.new(items_list, ScalarReference)
      rescue BASICException
        raise(BASICException, 'Invalid variable ' + items_list.map(&:to_s).join)
      end
    end
    if fh.nil?
      io = interpreter.console_io
      values =
        input_values(interpreter, prompt, @default_prompt, expression_list.size)
      io.implied_newline
    else
      values =
        file_values(interpreter, fh)
    end
    begin
      name_value_pairs =
        zip(expression_list, values[0, expression_list.length])
    rescue BASICException
      raise(BASICException, 'End of file') unless fh.nil?
      raise(BASICException, 'Unequal lists')
    end
    name_value_pairs.each do |hash|
      l_values = hash['name'].evaluate(interpreter)
      l_value = l_values[0]
      value = hash['value']
      interpreter.set_value(l_value, value, trace)
    end
  end

  private

  def first_token(tokens_lists)
    first_list = tokens_lists[0]
    first_list[0]
  end

  def first_value(tokens_lists, interpreter)
    first_list = tokens_lists[0]
    expr = ValueScalarExpression.new(first_list)
    values = expr.evaluate(interpreter)
    values[0]
  end

  def zip(names, values)
    raise(BASICException, 'Unequal lists') if names.size != values.size
    results = []
    (0...names.size).each do |i|
      results << { 'name' => names[i], 'value' => values[i] }
    end
    results
  end

  def input_values(interpreter, prompt, default_prompt, count)
    values = []
    io = interpreter.console_io
    while values.size < count
      io.prompt(prompt)
      values += io.input(interpreter)

      prompt = default_prompt
    end
    values
  end

  def file_values(interpreter, fh)
    values = []
    io = interpreter.get_input(fh)
    values += io.input(interpreter)
    values
  end
end

# IF/THEN
class IfStatement < AbstractStatement
  def initialize(line, tokens)
    super('IF', line)
    tokens = remove_break_tokens(tokens)
    parts = split_keywords(tokens)
    if parts.size == 3
      parse_line(parts[0], parts[1], parts[2][0])
    else
      @errors << 'Syntax error'
    end
  end

  def to_s
    @keyword + ' ' + @expression.to_s + ' THEN ' + @destination.to_s
  end

  def execute(interpreter, trace)
    io = interpreter.console_io
    s = ' ' + @expression.to_s
    io.trace_output(s) if trace
    values = @expression.evaluate(interpreter)
    raise(BASICException, 'Expression error') unless
      values.size == 1
    result = values[0]
    raise(BASICException, 'Expression error') unless
      result.class.to_s == 'BooleanConstant'
    interpreter.next_line_number = @destination if result.value
    return unless trace
    s = ' ' + result.to_s
    io.trace_output(s)
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

  private

  def parse_line(expression, keyword, destination)
    if destination.numeric_constant?
      @destination = LineNumber.new(destination)
    else
      @errors << "Invalid line number #{destination}"
    end
    @errors << 'Missing THEN' unless keyword.to_s == 'THEN'
    begin
      @expression = ValueScalarExpression.new(expression)
    rescue BASICException => e
      @errors << e.message
    end
  end
end

# common for PRINT, ARR PRINT, MAT PRINT
class AbstractPrintStatement < AbstractStatement
  def initialize(keyword, line)
    super
  end
  
  def to_s
    s = ''
    @tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'Array'
        s << ' '
        s << tokens_list.map(&:to_s).join
      else
        s << tokens_list.to_s
      end
    end

    if @tokens_lists.size.zero?
      @keyword
    else
      @keyword + s
    end
  end

  def extract_file_handle(print_items, interpreter)
    print_items = print_items.clone
    if print_items.size > 1
      item_0 = print_items[0]
      value_0 = item_0.evaluate(interpreter)
      value_0_0 = value_0[0]
      if value_0_0.class.to_s == 'FileHandle'
        file_handle = value_0_0
        print_items.shift
        print_items.shift if print_items[0].class.to_s == 'CarriageControl'
      else
        file_handle = nil
      end
    end
    [file_handle, print_items]
  end

end

# PRINT
class PrintStatement < AbstractPrintStatement
  def initialize(line, tokens)
    super('PRINT', line)
    tokens = remove_break_tokens(tokens)
    @tokens_lists = ArgSplitter.split_tokens(tokens, true)
    @print_items = tokens_to_expressions(@tokens_lists)
  end

  def execute(interpreter, _)
    file_handle, print_items = extract_file_handle(@print_items, interpreter)
    fh = interpreter.get_file_handler(file_handle)
    print_items.each do |item|
      item.print(fh, interpreter)
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []
    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'ParamSeparatorToken'
        print_items << CarriageControl.new(tokens_list.to_s)
      elsif tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end
    add_implied_items(print_items)
    print_items
  end

  def add_expression(print_items, tokens)
    if !print_items.empty? &&
       print_items[-1].class.to_s == 'ValueScalarExpression'
      print_items << CarriageControl.new('')
    end
    begin
      print_items << ValueScalarExpression.new(tokens)
    rescue BASICException
      line_text = tokens.map(&:to_s).join
      @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
    end
  end

  def add_implied_items(print_items)
    print_items << CarriageControl.new('NL') if print_items.empty?
    print_items << CarriageControl.new('NL') if print_items[-1].printable?
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def initialize(line, tokens)
    super('GOTO', line)
    tokens = remove_break_tokens(tokens)
    if tokens.size == 1
      if tokens[0].numeric_constant?
        @destination = LineNumber.new(tokens[0])
      else
        @errors << "Invalid line number #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def to_s
    @keyword + ' ' + @destination.to_s
  end

  def execute(interpreter, _)
    interpreter.next_line_number = @destination
  end
end

# GOSUB
class GosubStatement < AbstractStatement
  def initialize(line, tokens)
    super('GOSUB', line)
    tokens = remove_break_tokens(tokens)
    if tokens.size == 1
      if tokens[0].numeric_constant?
        @destination = LineNumber.new(tokens[0])
      else
        @errors << "Invalid line number #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def to_s
    @keyword + ' ' + @destination.to_s
  end

  def execute(interpreter, _)
    interpreter.push_return(interpreter.next_line_number)
    interpreter.next_line_number = @destination
  end
end

# RETURN
class ReturnStatement < AbstractStatement
  def initialize(line, _tokens)
    super('RETURN', line)
  end

  def to_s
    @keyword
  end

  def execute(interpreter, _)
    interpreter.next_line_number = interpreter.pop_return
  end
end

# Helper class for FOR/NEXT
class ForNextControl
  attr_reader :control
  attr_reader :loop_start_number
  attr_reader :end

  def initialize(control, loop_start_number,
                 start, endv, step_value)
    @control = control
    @loop_start_number = loop_start_number
    @start = start
    @end = endv
    @step_value = step_value
    @current_value = start
  end

  def bump_control(interpreter, trace)
    @current_value += @step_value
    interpreter.set_value(@control, @current_value, trace)
  end

  def front_terminated?
    zero = NumericConstant.new(0)
    if @step_value > zero
      @start > @end
    elsif @step_value < zero
      @start < @end
    else
      false
    end
  end

  def terminated?(interpreter)
    zero = NumericConstant.new(0)
    current_value = interpreter.get_value(@control)
    if @step_value > zero
      current_value + @step_value > @end
    elsif @step_value < zero
      current_value + @step_value < @end
    else
      false
    end
  end
end

# FOR statement
class ForStatement < AbstractStatement
  def initialize(line, tokens)
    super('FOR', line)
    tokens = remove_break_tokens(tokens)
    # parse control variable, '=', numeric_expression, "TO",
    # numeric_expression, "STEP", numeric_expression
    begin
      tokens2 = make_control(tokens)
      tokens3 = make_to_value(tokens2)
      make_step_value(tokens3)
    rescue BASICException => e
      @errors << e.message
    end
  end

  def to_s
    if @has_step_value
      "#{@keyword} #{@control} = #{@start} TO #{@end}" + " STEP #{@step_value}"
    else
      "#{@keyword} #{@control} = #{@start} TO #{@end}"
    end
  end

  def execute(interpreter, trace)
    from = @start.evaluate(interpreter)[0]
    to = @end.evaluate(interpreter)[0]
    step = @step_value.evaluate(interpreter)[0]

    interpreter.set_value(@control, from, false)
    fornext_control =
      ForNextControl.new(@control, interpreter.next_line_number, from, to, step)

    interpreter.assign_fornext(fornext_control)
    terminated = fornext_control.front_terminated?
    interpreter.next_line_number =
      interpreter.find_closing_next(@control) if terminated

    io = interpreter.console_io
    print_trace_info(io, from, to, step, terminated) if trace
  end

  private

  def make_control(tokens)
    parts = split_on_token(tokens, '=')
    raise(BASICException, 'Incorrect initialization') if parts.size != 3
    raise(BASICException, 'Incorrect initialization') if parts[1].to_s != '='
    if parts[0][0].variable?
      @control = VariableName.new(parts[0][0])
    else
      @errors << 'Control variable must be a variable'
    end
    parts[2]
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

  def make_to_value(tokens)
    parts = split_on_token(tokens, 'TO')
    raise(BASICException, 'Missing start value') if
      parts.empty? || parts[0].to_s == 'TO'
    raise(BASICException, 'Missing \'TO\'') if
      parts.size < 2 || parts[1].to_s != 'TO'
    raise(BASICException, 'Missing end value') if parts.size != 3
    @start = ValueScalarExpression.new(parts[0])
    parts[2]
  end

  def make_step_value(tokens)
    parts = split_on_token(tokens, 'STEP')
    tokens_e = parts[0]
    @end = ValueScalarExpression.new(tokens_e)

    @has_step_value = parts.size == 3
    if @has_step_value
      tokens_s = parts[2]
      @step_value = ValueScalarExpression.new(tokens_s)
    else
      @step_value = ValueScalarExpression.new([NumericConstantToken.new(1)])
    end
  end

  def print_trace_info(io, from, to, step, terminated)
    io.trace_output(" #{@start} = #{from}")
    io.trace_output(" #{@end} = #{to}")
    io.trace_output(" #{@step_value} = #{step}")
    io.trace_output(" terminated:#{terminated}")
  end
end

# NEXT
class NextStatement < AbstractStatement
  attr_reader :control

  def initialize(line, tokens)
    super('NEXT', line)
    tokens = remove_break_tokens(tokens)
    # parse control variable
    @control = nil
    if tokens.size == 1
      if tokens[0].variable?
        @control = VariableName.new(tokens[0])
      else
        @errors << "Invalid control variable #{tokens[0]}"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def to_s
    @keyword + ' ' + @control.to_s
  end

  def execute(interpreter, trace)
    fornext_control = interpreter.retrieve_fornext(@control)
    # check control variable value
    # if matches end value, stop here
    terminated = fornext_control.terminated?(interpreter)
    if trace
      io = interpreter.console_io
      s = ' terminated:' + terminated.to_s
      io.trace_output(s)
    end
    return if terminated
    # set next line from top item
    interpreter.next_line_number = fornext_control.loop_start_number
    # change control variable value
    fornext_control.bump_control(interpreter, trace)
  end
end

# READ
class ReadStatement < AbstractStatement
  def initialize(line, tokens)
    super('READ', line)
    tokens = remove_break_tokens(tokens)
    @tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # variable [variable]...
  end

  def to_s
    list = []
    @tokens_lists.each do |tokens_list|
      s = ''
      tokens_list.each { |token| s += token.to_s }
      list << s
    end
    @keyword + ' ' + list.join(', ')
  end

  def execute(interpreter, trace)
    tokens_lists = @tokens_lists.clone
    unless tokens_lists.size.zero?
      begin
        value = first_value(tokens_lists, interpreter)
        fh = nil
        if value.class.to_s == 'FileHandle'
          fh = value
          tokens_lists.shift
        end
      rescue BASICException
      end
    end
    expression_list = []
    tokens_lists.each do |items_list|
      begin
        expression_list << TargetExpression.new(items_list, ScalarReference)
      rescue BASICException
        raise(BASICException, 'Invalid variable ' + items_list.map(&:to_s).join)
      end
    end

    ds = interpreter.get_data_store(fh)
    expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      value = ds.read
      interpreter.set_value(variable, value, trace)
    end
  end

  private

  def first_value(tokens_lists, interpreter)
    first_list = tokens_lists[0]
    expr = ValueScalarExpression.new(first_list)
    values = expr.evaluate(interpreter)
    values[0]
  end
end

# DATA
class DataStatement < AbstractStatement
  def initialize(line, tokens)
    super('DATA', line)
    tokens = remove_break_tokens(tokens)
    @expressions = ValueScalarExpression.new(tokens)
  end

  def to_s
    @keyword + ' ' + @expressions.to_s
  end

  def pre_execute(interpreter)
    ds = interpreter.get_data_store(nil)
    data_list = @expressions.evaluate(interpreter)
    ds.store(data_list)
  end

  def execute(_, _)
    0
  end
end

# RESTORE
class RestoreStatement < AbstractStatement
  def initialize(line, _tokens)
    super('RESTORE', line)
  end

  def to_s
    @keyword
  end

  def execute(interpreter, _)
    ds = interpreter.get_data_store(nil)
    ds.reset
  end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def initialize(line, tokens)
    super('DEF', line)
    tokens = remove_break_tokens(tokens)
    @name = ''
    @arguments = []
    @template = ''
    begin
      user_function_definition = UserFunctionDefinition.new(tokens)
      @name = user_function_definition.name
      @arguments = user_function_definition.arguments
      @template = user_function_definition.template
    rescue BASICException => e
      puts e.message
      @errors << e.message
    end
  end

  def to_s
    @keyword + ' ' + @name + "(#{@arguments.join(',')}) = " + @template.to_s
  end

  def pre_execute(interpreter)
    interpreter.set_user_function(@name, @arguments, @template)
  end

  def execute(_, _) end
end

# STOP
class StopStatement < AbstractStatement
  def initialize(line, _tokens)
    super('STOP', line)
  end

  def to_s
    @keyword
  end

  def execute(interpreter, _)
    io = interpreter.console_io
    io.newline_when_needed
    interpreter.stop
  end
end

# END
class EndStatement < AbstractStatement
  def initialize(line, _tokens)
    super('END', line)
  end

  def to_s
    @keyword
  end

  def execute(interpreter, _)
    io = interpreter.console_io
    io.newline_when_needed
    interpreter.stop
  end
end

# TRACE
class TraceStatement < AbstractStatement
  def initialize(line, tokens)
    super('TRACE', line)
    tokens = remove_break_tokens(tokens)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    if tokens_lists.empty?
      @errors << 'Syntax error'
    elsif tokens_lists[0][0].boolean_constant?
      @operation = BooleanConstant.new(tokens_lists[0][0])
    else
      @errors << "Syntax error, '#{tokens_lists[0][0]}' not boolean"
    end
  end

  def execute(interpreter, _)
    interpreter.trace(@operation.value)
  end

  def to_s
    @keyword + ' ' + (@operation.value ? 'ON' : 'OFF')
  end
end

# ARR PRINT
class ArrPrintStatement < AbstractPrintStatement
  def initialize(line, tokens)
    super('ARR PRINT', line)
    tokens = remove_break_tokens(tokens)
    @tokens_lists = ArgSplitter.split_tokens(tokens, true)
    @print_items = tokens_to_expressions(@tokens_lists)
  end

  def execute(interpreter, _)
    io = interpreter.console_io
    i = 0
    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.print(io, interpreter, carriage)
      end
      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []
    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'ParamSeparatorToken'
        print_items << CarriageControl.new(tokens_list)
      elsif tokens_list.class.to_s == 'Array'
        print_items << ValueArrayExpression.new(tokens_list)
      end
    end
    add_implied_items(print_items)
    print_items
  end

  def add_implied_items(print_items)
    print_items << CarriageControl.new('NL') if print_items.empty?
    print_items << CarriageControl.new(',') if print_items[-1].printable?
  end
end

# ARR READ
class ArrReadStatement < AbstractStatement
  def initialize(line, tokens)
    super('ARR READ', line)
    tokens = remove_break_tokens(tokens)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # variable [variable]...

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        expression = TargetExpression.new(tokens_list, ArrayReference)
        @expression_list << expression
      rescue BASICException
        @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
      end
    end
  end

  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end

  def execute(interpreter, trace)
    @expression_list.each do |expression|
      targets = expression.evaluate(interpreter)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?
        read_values(target.name, interpreter, trace)
      end
    end
  end

  private

  def read_values(name, interpreter, trace)
    dims = interpreter.get_dimensions(name)
    case dims.size
    when 1
      read_array(name, dims, interpreter, trace)
    else
      raise(BASICException, 'Dimensions for ARR READ must be 1')
    end
  end

  def read_array(name, dims, interpreter, trace)
    values = {}
    ds = interpreter.get_data_store(nil)
    (0..dims[0].to_i).each do |col|
      coord = make_coord(col)
      values[coord] = ds.read
    end
    interpreter.set_values(name, values, trace)
  end
end

# ARR assignment
class ArrLetStatement < AbstractStatement
  def initialize(line, tokens)
    super('ARR', line)
    tokens = remove_break_tokens(tokens)
    begin
      @assignment = ArrayAssignment.new(tokens) ###
      if @assignment.count_target.zero?
        @errors << 'Assignment must have left-hand value(s)'
      end
      if @assignment.count_value != 1
        @errors << 'Assignment must have only one right-hand value'
      end
    rescue BASICException => e
      @errors << e.message
      @assignment = @rest
    end
  end

  def to_s
    @keyword + ' ' + @assignment.to_s
  end

  def execute(interpreter, trace)
    r_value = first_value(interpreter)
    dims = r_value.dimensions
    values = r_value.values

    l_values = @assignment.eval_target(interpreter)
    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, dims)
      interpreter.set_values(l_value.name, values, trace)
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
    raise(BASICException, 'Expected Array') if
      r_value.class.to_s != 'BASICArray'
    r_value
  end
end

# MAT PRINT
class MatPrintStatement < AbstractPrintStatement
  def initialize(line, tokens)
    super('MAT PRINT', line)
    tokens = remove_break_tokens(tokens)
    @tokens_lists = ArgSplitter.split_tokens(tokens, true)
    @print_items = tokens_to_expressions(@tokens_lists)
  end

  def execute(interpreter, _)
    io = interpreter.console_io
    i = 0
    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.print(io, interpreter, carriage)
      end
      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []
    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'ParamSeparatorToken'
        print_items << CarriageControl.new(tokens_list)
      elsif tokens_list.class.to_s == 'Array'
        print_items << ValueMatrixExpression.new(tokens_list)
      end
    end
    add_implied_items(print_items)
    print_items
  end

  def add_implied_items(print_items)
    print_items << CarriageControl.new('NL') if print_items.empty?
    print_items << CarriageControl.new(',') if print_items[-1].printable?
  end
end

# MAT READ
class MatReadStatement < AbstractStatement
  def initialize(line, tokens)
    super('MAT READ', line)
    tokens = remove_break_tokens(tokens)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # variable [variable]...

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        expression = TargetExpression.new(tokens_list, MatrixReference)
        @expression_list << expression
      rescue BASICException
        @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
      end
    end
  end

  def to_s
    @keyword + ' ' + @expression_list.join(', ')
  end

  def execute(interpreter, trace)
    @expression_list.each do |expression|
      targets = expression.evaluate(interpreter)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?
        read_values(target.name, interpreter, trace)
      end
    end
  end

  private

  def read_values(name, interpreter, trace)
    dims = interpreter.get_dimensions(name)
    case dims.size
    when 1
      read_vector(name, dims, interpreter, trace)
    when 2
      read_matrix(name, dims, interpreter, trace)
    else
      raise(BASICException, 'Dimensions for MAT READ must be 1 or 2')
    end
  end

  def read_vector(name, dims, interpreter, trace)
    values = {}
    ds = interpreter.get_data_store(nil)
    (1..dims[0].to_i).each do |col|
      coord = make_coord(col)
      values[coord] = ds.read
    end
    interpreter.set_values(name, values, trace)
  end

  def read_matrix(name, dims, interpreter, trace)
    values = {}
    ds = interpreter.get_data_store(nil)
    (1..dims[0].to_i).each do |row|
      (1..dims[1].to_i).each do |col|
        coords = make_coords(row, col)
        values[coords] = ds.read
      end
    end
    interpreter.set_values(name, values, trace)
  end
end

# MAT assignment
class MatLetStatement < AbstractStatement
  def initialize(line, tokens)
    super('MAT', line)
    tokens = remove_break_tokens(tokens)
    begin
      @assignment = MatrixAssignment.new(tokens)
      if @assignment.count_target.zero?
        @errors << 'Assignment must have left-hand value(s)'
      end
      if @assignment.count_value != 1
        @errors << 'Assignment must have only one right-hand value'
      end
    rescue BASICException => e
      @errors << e.message
      @assignment = @rest
    end
  end

  def to_s
    @keyword + ' ' + @assignment.to_s
  end

  def execute(interpreter, trace)
    r_value = first_value(interpreter)
    dims = r_value.dimensions
    values = r_value.values_1 if dims.size == 1
    values = r_value.values_2 if dims.size == 2

    l_values = @assignment.eval_target(interpreter)
    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, dims)
      interpreter.set_values(l_value.name, values, trace)
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
    raise(BASICException, 'Expected Matrix') if r_value.class.to_s != 'Matrix'
    r_value
  end
end
