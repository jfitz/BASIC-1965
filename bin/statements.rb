def squeeze_out_spaces(text)
  text = text.strip
  in_remark = text.start_with?('REM')
  squeezed_text = ''
  in_quotes = false
  text.each_char do |c|
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

  def self.split_text(text)
    @args = []
    @current_arg = ''
    @parens_level = 0
    in_str = false
    text.each_char do |c|
      if in_str
        in_string(c)
      else
        not_in_string(c)
      end
      in_str = !in_str if c == '"'
    end
    @args << @current_arg if @current_arg.size > 0
    @args
  end

  def self.split_tokens(tokens, want_separators)
    lists = []
    list = []
    parens_level = 0
    tokens.each do |token|
      if token.operator? && token.separator? && parens_level == 0
        lists << list if list.size > 0
        lists << token if want_separators
        list = []
      else
        list << token
      end
      parens_level += 1 if token.operator? && token.open?
      parens_level -= 1 if token.operator? && token.close? && parens_level > 0
    end
    lists << list if list.size > 0
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
    @args << @current_arg if @current_arg.length > 0
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

# abstract token
class AbstractToken
  def initialize
    @is_keyword = false
    @is_operator = false
    @is_function = false
    @is_text_constant = false
    @is_numeric_constant = false
    @is_boolean_constant = false
    @is_user_function = false
    @is_variable = false
  end

  def keyword?
    @is_keyword
  end

  def operator?
    @is_operator
  end

  def function?
    @is_function
  end

  def text_constant?
    @is_text_constant
  end

  def numeric_constant?
    @is_numeric_constant
  end

  def boolean_constant?
    @is_boolean_constant
  end

  def user_function?
    @is_user_function
  end

  def variable?
    @is_variable
  end
end

# invalid token
class InvalidToken < AbstractToken
  attr_reader :text

  def initialize(text)
    @text = text
  end
end

# keyword token
class KeywordToken < AbstractToken
  attr_reader :keyword

  def initialize(text)
    @is_keyword = true
    @keyword = text
  end

  def leading?
    @keyword == 'MAT'
  end

  def trailing?
    @keyword == 'READ' || @keyword == 'PRINT'
  end

  def to_s
    @keyword
  end
end

# operator token
class OperatorToken < AbstractToken
  attr_reader :operator

  def initialize(text)
    @is_operator = true
    @operator = text
  end

  def equals?
    @operator == '='
  end

  def separator?
    @operator == ',' || @operator == ';'
  end

  def open?
    @operator == '('
  end

  def close?
    @operator == ')'
  end

  def to_s
    @operator
  end
end

# function token
class FunctionToken < AbstractToken
  attr_reader :function

  def initialize(text)
    @is_function = true
    @function = text
  end

  def to_s
    @function
  end
end

# text constant token
class TextConstantToken < AbstractToken
  attr_reader :text_constant

  def initialize(text)
    @is_text_constant = true
    @text_constant = text
  end

  def to_s
    @text_constant
  end
end

# numeric constant token
class NumericConstantToken < AbstractToken
  attr_reader :numeric_constant

  def initialize(text)
    @is_numeric_constant = true
    @numeric_constant = text
  end

  def to_i
    @numeric_constant.to_f.to_i
  end

  def to_s
    @numeric_constant.to_s
  end
end

# boolean constant token
class BooleanConstantToken < AbstractToken
  attr_reader :boolean_constant

  def initialize(text)
    @is_boolean_constant = true
    @boolean_constant = text
  end

  def to_s
    @boolean_constant.to_s
  end
end

# user function token
class UserFunctionToken < AbstractToken
  attr_reader :user_function

  def initialize(text)
    @is_user_function = true
    @user_function = text
  end
end

# variable token
class VariableToken < AbstractToken
  attr_reader :variable

  def initialize(text)
    @is_variable = true
    @variable = text
  end

  def hash
    @variable.hash
  end

  def to_s
    @variable
  end
end

# Statement factory class
class StatementFactory
  def initialize
    @statement_definitions = statement_definitions
  end

  def parse(line)
    line_num = nil
    statement = nil
    m = /\A\d+/.match(line)
    unless m.nil?
      line_num = LineNumber.new(m[0])
      line_text = m.post_match
      statement = create(line_text)
    end
    [line_num, statement]
  end

  private

  def create(text)
    squeezed = squeeze_out_spaces(text)
    return EmptyStatement.new if squeezed == ''
    return RemarkStatement.new(text) if squeezed[0..2] == 'REM'

    tokens = tokenize(text)
    keyword = statement_word(tokens)
    create_regular_statement(keyword, text, squeezed, tokens)
  end

  def create_regular_statement(keyword, text, squeezed, tokens)
    statement = UnknownStatement.new(text)
    statement =
      @statement_definitions[keyword].new(text, squeezed, tokens) unless
        keyword.size == 0
    statement
  end

  def statement_word(tokens)
    keyword = nil
    keyword = tokens[0].keyword if tokens.length >= 1 && tokens[0].keyword?
    if tokens.length >= 2 && tokens[0].keyword? && tokens[1].keyword?
      keyword = tokens[0].keyword + tokens[1].keyword if
        tokens[0].leading? && tokens[1].trailing?
    end
    keyword
  end

  def tokenize(text)
    tokens = []
    invalid_tokenizer = InvalidTokenizer.new
    keywords = statement_definitions.keys + %w(TO STEP) - %w(MATPRINT MATREAD)
    keyword_tokenizer = ListTokenizer.new(keywords)
    operators = [
      '+', '-', '*', '/', '(', ')', '<', '<=', '=', '>=', '<>', ',', ';'
    ]
    operator_tokenizer = ListTokenizer.new(operators)
    function_tokenizer = ListTokenizer.new(FunctionFactory.function_names)
    text_tokenizer = TextTokenizer.new
    number_tokenizer = NumberTokenizer.new
    boolean_tokenizer = ListTokenizer.new(%w(ON OFF))
    userfunc_tokenizer = ListTokenizer.new(('FNA'..'FNZ').to_a)
    variable_tokenizer = VariableTokenizer.new

    text.each_char do |c|
      if keyword_tokenizer.try(c) ||
         operator_tokenizer.try(c) ||
         function_tokenizer.try(c) ||
         text_tokenizer.try(c) ||
         number_tokenizer.try(c) ||
         boolean_tokenizer.try(c) ||
         userfunc_tokenizer.try(c) ||
         variable_tokenizer.try(c)
        invalid_tokenizer.add(c)
        keyword_tokenizer.add(c)
        operator_tokenizer.add(c)
        function_tokenizer.add(c)
        text_tokenizer.add(c)
        number_tokenizer.add(c)
        boolean_tokenizer.add(c)
        userfunc_tokenizer.add(c)
        variable_tokenizer.add(c)
      else
        token = InvalidToken.new(invalid_tokenizer.token)
        token = KeywordToken.new(keyword_tokenizer.token) if
          keyword_tokenizer.ok
        token = OperatorToken.new(operator_tokenizer.token) if
          operator_tokenizer.ok
        token = FunctionToken.new(function_tokenizer.token) if
          function_tokenizer.ok
        token = TextConstantToken.new(text_tokenizer.token) if
          text_tokenizer.ok
        token = NumericConstantToken.new(number_tokenizer.token) if
          number_tokenizer.ok
        token = BooleanConstantToken.new(boolean_tokenizer.token) if
          boolean_tokenizer.ok
        token = UserFunctionToken.new(userfunc_tokenizer.token) if
          userfunc_tokenizer.ok
        token = VariableToken.new(variable_tokenizer.token) if
          variable_tokenizer.ok
        tokens << token
        invalid_tokenizer.reset
        keyword_tokenizer.reset
        operator_tokenizer.reset
        function_tokenizer.reset
        text_tokenizer.reset
        number_tokenizer.reset
        boolean_tokenizer.reset
        userfunc_tokenizer.reset
        variable_tokenizer.reset
        invalid_tokenizer.add(c)
        keyword_tokenizer.add(c)
        operator_tokenizer.add(c)
        function_tokenizer.add(c)
        text_tokenizer.add(c)
        number_tokenizer.add(c)
        boolean_tokenizer.add(c)
        userfunc_tokenizer.add(c)
        variable_tokenizer.add(c)
      end
    end
    token = InvalidToken.new(invalid_tokenizer.token)
    token = KeywordToken.new(keyword_tokenizer.token) if keyword_tokenizer.ok
    token = OperatorToken.new(operator_tokenizer.token) if
      operator_tokenizer.ok
    token = FunctionToken.new(function_tokenizer.token) if
      function_tokenizer.ok
    token = TextConstantToken.new(text_tokenizer.token) if text_tokenizer.ok
    token = NumericConstantToken.new(number_tokenizer.token) if
      number_tokenizer.ok
    token = BooleanConstantToken.new(boolean_tokenizer.token) if
      boolean_tokenizer.ok
    token = UserFunctionToken.new(userfunc_tokenizer.token) if
      userfunc_tokenizer.ok
    token = VariableToken.new(variable_tokenizer.token) if
      variable_tokenizer.ok
    tokens << token
    tokens
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
    if @errors.size == 0
      ' ' + to_s
    else
      @text
    end
  end

  def execute(interpreter, trace)
    if @errors.size == 0
      execute_cmd(interpreter, trace)
    else
      @errors.each do |error|
        puts "line #{interpreter.current_line_number}: #{error}"
      end
    end
  end

  protected

  # converts text line to constant values
  def textline_to_constants(line)
    values = []
    text_values = line.split(',')
    text_values.each do |value|
      v = value.strip
      fail(BASICException, "Value '#{value}' not numeric") unless
        NumericConstant.init?(v)
      values << NumericConstant.new(v)
    end
    values
  end

  # converts text line to constant values
  def tokens_to_constants(tokens)
    values = []
    tokens.each do |token|
      fail(BASICException, "Value '#{token}' not numeric") unless
        token.numeric_constant? || (token.operator? && token.separator?)
      values << NumericConstant.new(token.to_s) if token.numeric_constant?
    end
    values
  end

  def make_coord(c)
    '(' + c.to_s + ')'
  end

  def make_coords(r, c)
    '(' + r.to_s + ',' + c.to_s + ')'
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

  def execute_cmd(_, _)
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

  def execute_cmd(_, _)
    0
  end
end

# REMARK
class RemarkStatement < AbstractStatement
  def initialize(line)
    # override the method to squeeze spaces from line
    squeezed = line.strip
    super('REM', line)
    squeezed_keyword = squeeze_out_spaces('REM')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
  end

  def to_s
    @keyword + @rest
  end

  def execute_cmd(_, _)
    0
  end
end

# DIM
class DimStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)

    @errors << 'No variables specified' if tokens_lists.size == 0

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        @expression_list <<
          TargetExpression.new(nil, tokens_list, VariableDimension)
      rescue BASICException
        @errors << "Invalid variable #{tokens_list}"
      end
    end
  end

  def to_s
    @keyword.join(' ') + ' ' + @expression_list.join(', ')
  end

  def execute_cmd(interpreter, _)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter)
      variable = variables[0]
      subscripts = variable.subscripts
      if subscripts.size == 0
        fail BASICException, 'DIM statement requires subscript range'
      end
      interpreter.set_dimensions(variable.name, subscripts)
    end
  end
end

# LET
class LetStatement < AbstractStatement
  def initialize(line, squeezed, _tokens)
    super('LET', line)
    squeezed_keyword = squeeze_out_spaces('LET')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    begin
      @assignment = ScalarAssignment.new(@rest)
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

  def execute_cmd(interpreter, trace)
    l_values = @assignment.eval_target(interpreter)
    l_value = l_values[0]
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    interpreter.set_value(l_value, r_value, trace)
  end
end

# INPUT
class InputStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # [prompt string] variable [variable]...
    @default_prompt = TextConstant.new('"? "')
    @prompt = @default_prompt
    @expression_list = []
    if tokens_lists.length > 0
      if tokens_lists[0][0].text_constant?
        @prompt = TextConstant.new(tokens_lists[0][0].to_s)
        tokens_lists.shift
      end
      # check variables are specified
      if tokens_lists.length > 0
        @expression_list = build_expression_list(tokens_lists)
      else
        @errors << 'No variables specified'
      end
    else
      @errors << 'No variables specified'
    end
  end

  def to_s
    if @prompt != @default_prompt
      @keyword.join(' ') + ' ' + @prompt.to_s + ', ' + @expression_list.join(', ')
    else
      @keyword.join(' ') + ' ' + @expression_list.join(', ')
    end
  end

  def execute_cmd(interpreter, trace)
    printer = interpreter.print_handler
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
    fail(BASICException, 'Unequal lists') if names.size != values.size
    results = []
    (0...names.size).each do |i|
      results << { 'name' => names[i], 'value' => values[i] }
    end
    results
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
          TargetExpression.new(nil, tokens_list, ScalarReference)
      rescue BASICException
        @errors << "Invalid variable #{tokens_list}"
      end
    end
    expression_list
  end
end

# IF/THEN
class IfStatement < AbstractStatement
  def initialize(line, squeezed, tokens)
    super('IF', line)
    squeezed_keyword = squeeze_out_spaces('IF')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    parts = @rest.split('THEN')
    begin
      @boolean_expression = BooleanExpression.new(parts[0])
    rescue BASICException => e
      @errors << e.message
      @boolean_expression = parts[0]
    end
    if tokens[-1].numeric_constant?
      @destination = LineNumber.new(tokens[-1])
    else
      @errors << "Invalid line number #{tokens[1]}"
    end
  end

  def to_s
    @keyword + ' ' + @boolean_expression.to_s + ' THEN ' + @destination.to_s
  end

  def execute_cmd(interpreter, trace)
    @boolean_expression.evaluate(interpreter)
    interpreter.next_line_number = @destination if @boolean_expression.result
    return unless trace
    printer = interpreter.print_handler
    s = ' ' + @boolean_expression.evaluated_to_s +
        ' ' + @boolean_expression.result.to_s
    printer.trace_output(s)
  end
end

# PRINT
class PrintStatement < AbstractStatement
  def initialize(line, squeezed, _tokens)
    super('PRINT', line)
    squeezed_keyword = squeeze_out_spaces('PRINT')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    item_list = ArgSplitter.split_text(@rest)
    # variable/constant, [separator, variable/constant]... [separator]

    @print_items = []
    previous_item = CarriageControl.new('')
    item_list.each do |print_item|
      add_print_item(print_item, previous_item)
      previous_item = @print_items[-1]
    end
    add_implied_print_items
  end

  def to_s
    varnames = []
    @print_items.each do |item|
      varnames << item.to_s
    end
    trailer = ' ' + varnames.join('')
    @keyword + trailer.rstrip
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
    @print_items.each do |item|
      item.print(printer, interpreter)
    end
  end

  private

  def add_print_item(print_item, previous_item)
    if CarriageControl.init?(print_item)
      @print_items << CarriageControl.new(print_item)
    else
      # insert a plain carriage control between two printable things
      @print_items << CarriageControl.new('') if previous_item.printable?
      add_printable(print_item)
    end
  end

  def add_printable(print_item)
    if TextConstant.init?(print_item.strip)
      @print_items << TextConstant.new(print_item.strip)
    else
      begin
        @print_items << ValueScalarExpression.new(print_item.strip)
      rescue BASICException => e
        @errors << "Invalid print item '#{print_item}': #{e.message}"
      end
    end
  end

  def add_implied_print_items
    @print_items << CarriageControl.new('NL') if @print_items.size == 0
    @print_items << CarriageControl.new('NL') if @print_items[-1].printable?
  end
end

# GOTO
class GotoStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
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
    @keyword.join(' ') + ' ' + @destination.to_s
  end

  def execute_cmd(interpreter, _)
    interpreter.next_line_number = @destination
  end
end

# GOSUB
class GosubStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
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
    @keyword.join(' ') + ' ' + @destination.to_s
  end

  def execute_cmd(interpreter, _)
    interpreter.push_return(interpreter.next_line_number)
    interpreter.next_line_number = @destination
  end
end

# RETURN
class ReturnStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
  end

  def to_s
    @keyword.join(' ')
  end

  def execute_cmd(interpreter, _)
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

  def bump_control(interpreter)
    @current_value += @step_value
    interpreter.set_value(@control, @current_value, false)
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
  def initialize(line, squeezed, tokens)
    super('FOR', line)
    squeezed_keyword = squeeze_out_spaces('FOR')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    # parse control variable, '=', numeric_expression, "TO",
    # numeric_expression, "STEP", numeric_expression
    parts = make_control(tokens)
    parts = make_to_value(parts)
    make_step_value(parts)
  end

  def to_s
    if @has_step_value
      "#{@keyword} #{@control} = #{@start} TO #{@end} STEP #{@step_value}"
    else
      "#{@keyword} #{@control} = #{@start} TO #{@end}"
    end
  end

  def execute_cmd(interpreter, _)
    loop_end_number = interpreter.find_closing_next(@control.to_s)
    from_value = @start.evaluate(interpreter)[0]
    interpreter.set_value(@control, from_value, false)
    to_value = @end.evaluate(interpreter)[0]
    step_value = @step_value.evaluate(interpreter)[0]
    fornext_control =
      ForNextControl.new(@control, interpreter.next_line_number,
                         from_value, to_value, step_value)
    interpreter.assign_fornext(fornext_control)
    interpreter.next_line_number = loop_end_number if
      fornext_control.front_terminated?
  end

  private

  def make_control(tokens)
    parts = @rest.split('=', 2)
    fail(BASICException, 'Syntax error') if parts.size != 2
    if tokens.size > 3
      if tokens[1].variable?
        @control = VariableName.new(tokens[1])
      else
        @errors << 'Control variable must be a variable'
      end
      if tokens[2].operator?
        @errors << "Syntax error, missing '=' sign" unless tokens[2].equals?
      else
        @errors << 'Syntax error, not enough items'
      end
    else
      @errors << 'Syntax error'
    end
    parts
  end

  def make_to_value(parts)
    parts = parts[1].split('TO', 2)
    fail(BASICException, 'Syntax error') if parts.size != 2
    @start = ValueScalarExpression.new(parts[0])
    parts
  end

  def make_step_value(parts)
    parts = parts[1].split('STEP', 2)
    @end = ValueScalarExpression.new(parts[0])

    @has_step_value = parts.size > 1
    @step_value = ValueScalarExpression.new('1')
    @step_value = ValueScalarExpression.new(parts[1]) if parts.size > 1
  end
end

# NEXT
class NextStatement < AbstractStatement
  attr_reader :control

  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
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
    @keyword.join(' ') + ' ' + @control.to_s
  end

  def execute_cmd(interpreter, _)
    fornext_control = interpreter.retrieve_fornext(@control)
    # check control variable value
    # if matches end value, stop here
    return if fornext_control.terminated?(interpreter)
    # set next line from top item
    interpreter.next_line_number = fornext_control.loop_start_number
    # change control variable value
    fornext_control.bump_control(interpreter)
  end
end

# READ
class ReadStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # variable [variable]...

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        @expression_list << TargetExpression.new(nil, tokens_list, ScalarReference)
      rescue BASICException
        @errors << "Invalid variable #{tokens_list}"
      end
    end
  end

  def to_s
    @keyword.join(' ') + ' ' + @expression_list.join(', ')
  end

  def execute_cmd(interpreter, trace)
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
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    @data_list = tokens_to_constants(tokens)
  end

  def to_s
    @keyword.join(' ') + ' ' + @data_list.join(', ')
  end

  def pre_execute(interpreter)
    interpreter.store_data(@data_list)
  end

  def execute_cmd(_, _)
    0
  end
end

# RESTORE
class RestoreStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
  end

  def to_s
    @keyword.join(' ')
  end

  def execute_cmd(interpreter, _)
    interpreter.reset_data
  end
end

# DEF FNx
class DefineFunctionStatement < AbstractStatement
  def initialize(line, squeezed, _tokens)
    super('DEF', line)
    squeezed_keyword = squeeze_out_spaces('DEF')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    @name = ''
    @arguments = []
    @template = ''
    begin
      user_function_definition = UserFunctionDefinition.new(@rest)
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

  def execute_cmd(_, _)
  end
end

# STOP
class StopStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
  end

  def to_s
    @keyword.join(' ')
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
    printer.newline_when_needed
    interpreter.stop
  end
end

# END
class EndStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
  end

  def to_s
    @keyword.join(' ')
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
    printer.newline_when_needed
    interpreter.stop
  end
end

# TRACE
class TraceStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    if tokens_lists.size > 0
      if tokens_lists[0][0].boolean_constant?
        @operation = BooleanConstant.new(tokens_lists[0][0])
      else
        @errors << "Syntax error, '#{tokens_lists[0][0]}' not boolean"
      end
    else
      @errors << 'Syntax error'
    end
  end

  def execute_cmd(interpreter, _)
    interpreter.trace(@operation.value)
  end

  def to_s
    @keyword.join(' ') + ' ' + (@operation.value ? 'ON' : 'OFF')
  end
end

# MAT PRINT
class MatPrintStatement < AbstractStatement
  def initialize(line, squeezed, _tokens)
    super('MAT PRINT', line)
    squeezed_keyword = squeeze_out_spaces('MAT PRINT')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    item_list = ArgSplitter.split_text(@rest)
    # variable, [separator, variable]... [separator]

    @print_items = []
    previous_item = CarriageControl.new('')
    item_list.each do |print_item|
      add_print_item(print_item, previous_item)
      previous_item = @print_items[-1]
    end

    add_implied_print_items
  end

  def to_s
    varnames = []
    @print_items.each do |item|
      varnames << item.to_s
    end
    trailer = ' ' + varnames.join('')
    @keyword + trailer.rstrip
  end

  def execute_cmd(interpreter, _)
    printer = interpreter.print_handler
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

  def add_print_item(print_item, previous_item)
    if CarriageControl.init?(print_item)
      # the item is a carriage control item
      # save previous print thing, or create an empty one
      @print_items << CarriageControl.new(print_item)
    else
      # insert a plain carriage control
      @print_items << CarriageControl.new('') if previous_item.printable?
      begin
        @print_items << ValueMatrixExpression.new(print_item.strip)
      rescue BASICException => e
        @errors << "Invalid print item '#{print_item}': #{e.message}"
      end
    end
  end

  def add_implied_print_items
    @print_items << CarriageControl.new('NL') if @print_items.size == 0
    @print_items << CarriageControl.new(',') if @print_items[-1].printable?
  end
end

# MAT READ
class MatReadStatement < AbstractStatement
  def initialize(line, _, tokens)
    keyword = []
    keyword << tokens.shift.to_s while tokens.size > 0 && tokens[0].keyword?
    super(keyword, line)
    tokens_lists = ArgSplitter.split_tokens(tokens, false)
    # variable [variable]...

    @expression_list = []
    tokens_lists.each do |tokens_list|
      begin
        expression = TargetExpression.new(nil, tokens_list, MatrixReference)
        @expression_list << expression
      rescue BASICException
        @errors << "Invalid variable #{tokens_list}"
      end
    end
  end

  def to_s
    @keyword.join(' ') + ' ' + @expression_list.join(', ')
  end

  def execute_cmd(interpreter, trace)
    @expression_list.each do |expression|
      targets = expression.evaluate(interpreter)
      targets.each do |target|
        name = target.name
        interpreter.set_dimensions(name, target.dimensions) if
          target.dimensions?
        read_values(name, interpreter, trace)
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
      fail(BASICException, 'Dimensions for MAT READ must be 1 or 2')
    end
  end

  def read_vector(name, dims, interpreter, trace)
    values = {}
    (1..dims[0].to_i).each do |col|
      values[make_coord(col)] = interpreter.read_data
    end
    interpreter.set_values(name, values, trace)
  end

  def read_matrix(name, dims, interpreter, trace)
    values = {}
    (1..dims[0].to_i).each do |row|
      (1..dims[1].to_i).each do |col|
        values[make_coords(row, col)] = interpreter.read_data
      end
    end
    interpreter.set_values(name, values, trace)
  end
end

# MAT assignment
class MatLetStatement < AbstractStatement
  def initialize(line, squeezed, _tokens)
    super('MAT', line)
    squeezed_keyword = squeeze_out_spaces('MAT')
    length = squeezed_keyword.length
    @rest = squeezed[length..-1]
    begin
      @assignment = MatrixAssignment.new(@rest)
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

  def execute_cmd(interpreter, trace)
    l_value = first_target(interpreter)
    name = l_value.name
    r_value = first_value(interpreter)
    dims = r_value.dimensions
    interpreter.set_dimensions(name, dims)
    values = r_value.values_1 if dims.size == 1
    values = r_value.values_2 if dims.size == 2
    interpreter.set_values(name, values, trace)
  end

  private

  def first_target(interpreter)
    l_values = @assignment.eval_target(interpreter)
    l_values[0]
  end

  def first_value(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    fail(BASICException, 'Expected Matrix') if r_value.class.to_s != 'Matrix'
    r_value
  end
end
