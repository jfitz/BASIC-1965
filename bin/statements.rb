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
      elsif token.operator? && token.separator? && parens_level == 0
        lists << list unless list.empty?
        lists << token if want_separators
        list = []
      else
        list << token
      end
      parens_level += 1 if token.operator? && token.open?
      parens_level -= 1 if token.operator? && token.close? && parens_level > 0
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
    if [',', ';'].include?(c) && @parens_level == 0
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
    @parens_level -= 1 if @parens_level > 0
  end
end

# Statement factory class
class StatementFactory
  def initialize
    @statement_definitions = statement_definitions
  end

  def parse(text)
    line_num = nil
    statement = nil
    m = /\A\d+/.match(text)
    unless m.nil?
      line_num = LineNumber.new(m[0])
      statement = create(m.post_match)
    end
    [line_num, statement]
  end

  private

  def create(text)
    squeezed = squeeze_out_spaces(text)
    return EmptyStatement.new if squeezed == ''
    return RemarkStatement.new(text) if squeezed[0..2] == 'REM'

    tokens = tokenize(squeezed)
    keyword = ''
    keyword << tokens.shift.to_s while !tokens.empty? && tokens[0].keyword?
    create_regular_statement(keyword, text, tokens)
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
    text_to_tokens(text, tokenizers)
  end

  def statement_definitions
    {
      'DATA' => DataStatement,
      'DEF' => DefineFunctionStatement,
      'DIM' => DimStatement,
      'END' => EndStatement,
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
    keywords = statement_definitions.keys + %w(THEN TO STEP) -
               %w(MATPRINT MATREAD)
    tokenizers << ListTokenizer.new(keywords, KeywordToken)
    operators = [
      '+', '-', '*', '/', '^', '(', ')',
      '<', '<=', '=', '>', '>=', '<>',
      ',', ';'
    ]
    tokenizers << ListTokenizer.new(operators, OperatorToken)
    tokenizers <<
      ListTokenizer.new(FunctionFactory.function_names, FunctionToken)
    tokenizers << TextTokenizer.new
    tokenizers << NumberTokenizer.new
    tokenizers << ListTokenizer.new(%w(ON OFF), BooleanConstantToken)
    tokenizers << ListTokenizer.new(('FNA'..'FNZ').to_a, UserFunctionToken)
    tokenizers << VariableTokenizer.new
    tokenizers << InvalidTokenizer.new
  end

  def text_to_tokens(text, tokenizers)
    tokens = []
    until text.nil? || text.empty?
      tokenizers.each { |tokenizer| tokenizer.try(text) }

      count = 0
      token = nil
      tokenizers.each do |tokenizer|
        if tokenizer.count > count
          token = tokenizer.token
          count = tokenizer.count
        end
      end
      tokens << token unless token.nil?
      text = text[count..-1]
    end
    tokens
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

  def make_coord(c)
    [NumericConstant.new(c)]
  end

  def make_coords(r, c)
    [NumericConstant.new(r), NumericConstant.new(c)]
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

# LET
class LetStatement < AbstractStatement
  def initialize(line, tokens)
    super('LET', line)
    begin
      @assignment = ScalarAssignment.new(tokens)
      if @assignment.count_target != 1
        @errors << 'Assignment must have only one left-hand value'
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
    l_value = l_values[0]
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    interpreter.set_value(l_value, r_value, trace)
  end
end

# INPUT
class InputStatement < AbstractStatement
  def initialize(line, tokens)
    super('INPUT', line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # [prompt string] variable [variable]...
    @default_prompt = TextConstant.new('"? "')
    @prompt = @default_prompt
    @expression_list = []
    if tokens_lists.empty?
      @errors << 'No variables specified'
    else
      if tokens_lists[0][0].text_constant?
        @prompt = TextConstant.new(tokens_lists[0][0].to_s)
        tokens_lists.shift
      end
      # check variables are specified
      if tokens_lists.empty?
        @errors << 'No variables specified'
      else
        @expression_list = build_expression_list(tokens_lists)
      end
    end
  end

  def to_s
    if @prompt != @default_prompt
      @keyword + ' ' + @prompt.to_s + ', ' + @expression_list.join(', ')
    else
      @keyword + ' ' + @expression_list.join(', ')
    end
  end

  def execute(interpreter, trace)
    printer = interpreter.printer
    values = input_values
    name_value_pairs =
      zip(@expression_list, values[0, @expression_list.length])
    name_value_pairs.each do |hash|
      l_values = hash['name'].evaluate(interpreter)
      l_value = l_values[0]
      value = hash['value']
      interpreter.set_value(l_value, value, trace)
    end
    printer.implied_newline
  end

  private

  def zip(names, values)
    raise(BASICException, 'Unequal lists') if names.size != values.size
    results = []
    (0...names.size).each do |i|
      results << { 'name' => names[i], 'value' => values[i] }
    end
    results
  end

  # converts text line to constant values
  def textline_to_constants(line)
    values = []
    text_values = line.split(',')
    text_values.each do |value|
      v = value.strip
      raise(BASICException, "Value '#{value}' not numeric") unless
        NumericConstant.init?(v)
      values << NumericConstant.new(v)
    end
    values
  end

  def input_values
    values = []
    prompt = @prompt
    while values.size < @expression_list.size
      print prompt.value
      input_line = gets
      values += textline_to_constants(input_line.chomp)
      prompt = @default_prompt
    end
    values
  end

  def build_expression_list(tokens_lists)
    expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        expression_list <<
          TargetExpression.new(tokens_list, ScalarReference)
      rescue BASICException
        @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
      end
    end
    expression_list
  end
end

# IF/THEN
class IfStatement < AbstractStatement
  def initialize(line, tokens)
    super('IF', line)
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
    result = @expression.evaluate(interpreter)[0]
    interpreter.next_line_number = @destination if result.value
    return unless trace
    printer = interpreter.printer
    s = ' ' + result.to_s
    printer.trace_output(s)
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

# PRINT
class PrintStatement < AbstractStatement
  def initialize(line, tokens)
    super('PRINT', line)
    tokens_lists = ArgSplitter.split_tokens(tokens, true)
    # variable/constant, [separator, variable/constant]... [separator]

    tokens_to_expressions(tokens_lists)
    add_implied_print_items
  end

  def to_s
    if @print_items.size == 1
      @keyword
    else
      @keyword + ' ' + @print_items.map(&:to_s).join.rstrip
    end
  end

  def execute(interpreter, _)
    printer = interpreter.printer
    @print_items.each do |item|
      item.print(printer, interpreter)
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    @print_items = []
    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'OperatorToken'
        add_carriage_control(tokens_list)
      elsif tokens_list.class.to_s == 'Array'
        add_expression(tokens_list)
      end
    end
  end

  def add_carriage_control(token)
    if token.separator?
      @print_items << CarriageControl.new(token.to_s)
    else
      @errors << 'Syntax error'
    end
  end

  def add_expression(tokens)
    if !@print_items.empty? &&
       @print_items[-1].class.to_s == 'ValueScalarExpression'
      @print_items << CarriageControl.new('')
    end
    begin
      @print_items << ValueScalarExpression.new(tokens)
    rescue BASICException
      line_text = tokens.map(&:to_s).join
      @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
    end
  end

  def add_implied_print_items
    @print_items << CarriageControl.new('NL') if @print_items.empty?
    @print_items << CarriageControl.new('NL') if @print_items[-1].printable?
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def initialize(line, tokens)
    super('GOTO', line)
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
      interpreter.find_closing_next(@control.to_s) if terminated

    print_trace_info(interpreter.printer, from, to, step, terminated) if
      trace
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
      parts.size < 1 || parts[0].to_s == 'TO'
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

  def print_trace_info(printer, from, to, step, terminated)
    printer.trace_output(" #{@start} = #{from}")
    printer.trace_output(" #{@end} = #{to}")
    printer.trace_output(" #{@step_value} = #{step}")
    printer.trace_output(" terminated:#{terminated}")
  end
end

# NEXT
class NextStatement < AbstractStatement
  attr_reader :control

  def initialize(line, tokens)
    super('NEXT', line)
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
      printer = interpreter.printer
      s = ' terminated:' + terminated.to_s
      printer.trace_output(s)
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
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # variable [variable]...

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        @expression_list << TargetExpression.new(tokens_list, ScalarReference)
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
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      value = interpreter.read_data
      interpreter.set_value(variable, value, trace)
    end
  end
end

# DATA
class DataStatement < AbstractStatement
  def initialize(line, tokens)
    super('DATA', line)
    @expressions = ValueScalarExpression.new(tokens)
  end

  def to_s
    @keyword + ' ' + @expressions.to_s
  end

  def pre_execute(interpreter)
    data_list = @expressions.evaluate(interpreter)
    interpreter.store_data(data_list)
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
    interpreter.reset_data
  end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def initialize(line, tokens)
    super('DEF', line)
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

  def execute(_, _)
  end
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
    printer = interpreter.printer
    printer.newline_when_needed
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
    printer = interpreter.printer
    printer.newline_when_needed
    interpreter.stop
  end
end

# TRACE
class TraceStatement < AbstractStatement
  def initialize(line, tokens)
    super('TRACE', line)
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

# MAT PRINT
class MatPrintStatement < AbstractStatement
  def initialize(line, tokens)
    super('MAT PRINT', line)
    tokens_lists = ArgSplitter.split_tokens(tokens, true)
    # variable, [separator, variable]... [separator]

    @print_items = tokens_to_expressions(tokens_lists)
    add_implied_print_items
  end

  def to_s
    if @print_items.size == 1
      @keyword
    else
      @keyword + ' ' + @print_items.map(&:to_s).join.rstrip
    end
  end

  def execute(interpreter, _)
    printer = interpreter.printer
    i = 0
    @print_items.each do |item|
      if item.printable?
        carriage = CarriageControl.new('')
        carriage = @print_items[i + 1] if
          i < @print_items.size &&
          !@print_items[i + 1].printable?
        item.print(printer, interpreter, carriage)
      end
      i += 1
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []
    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'OperatorToken'
        raise(BASICException, 'Syntax error') unless tokens_list.separator?
        print_items << CarriageControl.new(tokens_list.to_s)
      elsif tokens_list.class.to_s == 'Array'
        print_items << ValueMatrixExpression.new(tokens_list)
      end
    end
    print_items
  end

  def add_implied_print_items
    @print_items << CarriageControl.new('NL') if @print_items.empty?
    @print_items << CarriageControl.new(',') if @print_items[-1].printable?
  end
end

# MAT READ
class MatReadStatement < AbstractStatement
  def initialize(line, tokens)
    super('MAT READ', line)
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
    (1..dims[0].to_i).each do |col|
      coord = make_coord(col)
      values[coord] = interpreter.read_data
    end
    interpreter.set_values(name, values, trace)
  end

  def read_matrix(name, dims, interpreter, trace)
    values = {}
    (1..dims[0].to_i).each do |row|
      (1..dims[1].to_i).each do |col|
        coords = make_coords(row, col)
        values[coords] = interpreter.read_data
      end
    end
    interpreter.set_values(name, values, trace)
  end
end

# MAT assignment
class MatLetStatement < AbstractStatement
  def initialize(line, tokens)
    super('MAT', line)
    begin
      @assignment = MatrixAssignment.new(tokens)
      if @assignment.count_target != 1
        @errors << 'Assignment must have only one left-hand value'
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
    l_value = first_target(interpreter)
    name = l_value
    r_value = first_value(interpreter)
    dims = r_value.dimensions
    interpreter.set_dimensions(name, dims)
    values = r_value.values_1 if dims.size == 1
    values = r_value.values_2 if dims.size == 2
    interpreter.set_values(l_value.name, values, trace)
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
