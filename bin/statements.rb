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
      PrintStatement,
      ReadStatement,
      RemarkStatement,
      RestoreStatement,
      ReturnStatement,
      StopStatement,
      TraceStatement,
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
      statement = UnknownStatement.new(text)

      keywords, tokens = extract_keywords(statement_tokens)

      if @statement_definitions.key?(keywords)
        tokens_lists = split_keywords(tokens)

        statement =
          @statement_definitions[keywords].new(keywords, tokens_lists)
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
  attr_accessor :profile_count
  attr_accessor :profile_time

  def self.extra_keywords
    []
  end

  def initialize(keywords, tokens_lists)
    @keywords = keywords
    @tokens = tokens_lists.flatten
    @errors = []
    @profile_count = 0
    @profile_time = 0
  end

  def dump
    ['Unimplemented']
  end

  def program_check(_, _, _)
    true
  end

  def pre_execute(_) end

  def profile
    text = AbstractToken.pretty_tokens(@keywords, @tokens)
    ' (' + @profile_time.round(4).to_s + '/' + @profile_count.to_s + ')' + text
  end

  def renumber(_) end

  def numerics
    nums = []

    # convert a sequence of minus sign and numeric token to a single token
    # the result list should be a list of tokens, not expressions
    # and we want a unary minus and value to render as number in crossref
    negate = false
    prev_unary_minus = false
    prev_operand = false
    @tokens.each do |token|
      negate = !negate if prev_unary_minus
      if token.numeric_constant?
        if negate
          nums << token.clone.negate
        else
          nums << token
        end
      end
      prev_unary_minus = token.operator? && token.to_s == '-' && !prev_operand
      prev_operand = token.groupend? || token.numeric_constant? || token.variable?
    end

    nums
  end

  def strings
    strs = @tokens.clone
    strs.keep_if(&:text_constant?)
  end

  def functions
    funcs = @tokens.clone
    funcs.keep_if(&:function?)
    funcs.map(&:to_s)
  end

  def userfuncs
    udfs = @tokens.clone
    udfs.keep_if(&:user_function?)
    udfs.map(&:to_s)
  end

  def variables
    vars = @tokens.clone
    vars.keep_if(&:variable?)
    vars.map(&:to_s)
  end

  protected

  def check_template(tokens_lists, template)
    return false unless tokens_lists.size == template.size

    result = true
    zip = template.zip(tokens_lists)
    zip.each do |pair|
      control = pair[0]
      value = pair[1]

      case control.class.to_s
      when 'String'
        result &= (value.keyword? &&
                   value.to_s == control)
      when 'Array'
        result &= (value.class.to_s == 'Array')
        result &= value.size == control[0] if control.size == 1
        result &= value.size >= control[0] if
          control.size == 2 && control[1] == '>='
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
           print_items[0].class.to_s == 'CarriageControl'
      candidate_file_tokens = print_items[0]

      if candidate_file_tokens.filehandle?
        file_tokens = print_items.shift
        print_items.shift if
          print_items[0].class.to_s == 'CarriageControl'
      end
    end
    [file_tokens, print_items]
  end

  def get_file_handle(interpreter, file_tokens)
    return nil if file_tokens.nil?
    
    file_handles = file_tokens.evaluate(interpreter, false)
    file_handles[0]
  end

  def add_implied_items(print_items, final)
    print_items << CarriageControl.new('NL') if print_items.empty?
    print_items << final if print_items[-1].printable?
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

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @expressions = ValueScalarExpression.new(tokens_lists[0])
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    @expressions.dump
  end

  def pre_execute(interpreter)
    ds = interpreter.get_data_store(nil)
    data_list = @expressions.evaluate(interpreter, false)
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

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @definition = nil
      begin
        @definition = UserFunctionDefinition.new(tokens_lists[0])
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
          @expression_list <<
            TargetExpression.new(tokens_list, CompoundDeclaration)
        rescue BASICExpressionError
          @errors << 'Invalid variable ' + tokens_list.map(&:to_s).join
        end
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    @expression_list.each { |expression| lines += expression.dump }
    lines
  end

  def execute(interpreter)
    @expression_list.each do |expression|
      variables = expression.evaluate(interpreter, false)
      variable = variables[0]
      subscripts = variable.subscripts
      if subscripts.empty?
        raise BASICRuntimeError, 'DIM statement requires subscript range'
      end
      interpreter.set_dimensions(variable, subscripts)
    end
  end

  def variables
    vars = []
    @expression_list.each do |expression|
      vars += expression.variables
    end
    vars
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

    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @expressions = ValueScalarExpression.new(tokens_lists[0])
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    @expressions.dump
  end

  def pre_execute(interpreter)
    file_names = @expressions.evaluate(interpreter, false)
    interpreter.add_file_names(file_names)
  end

  def execute(_) end

  def variables
    @expressions.variables
  end
end

# Helper class for FOR/NEXT
class ForNextControl
  attr_reader :control
  attr_reader :loop_start_number
  attr_reader :end

  def initialize(control, interpreter, start, endv, step_value)
    @control = control
    @start = start
    @end = endv
    @step_value = step_value
    interpreter.set_value(@control, start)
    @loop_start_number = interpreter.next_line_number
  end

  def bump_control(interpreter)
    current_value = interpreter.get_value(@control, false)
    current_value += @step_value
    interpreter.unlock_variable(@control)
    interpreter.set_value(@control, current_value)
    interpreter.lock_variable(@control)
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
    current_value = interpreter.get_value(@control, true)
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
  def self.lead_keywords
    [
      [KeywordToken.new('FOR')]
    ]
  end

  def self.extra_keywords
    ['TO', 'STEP']
  end

  def initialize(keywords, tokens_lists)
    super

    template1 = [[1, '>='], 'TO', [1, '>=']]
    template2 = [[1, '>='], 'TO', [1, '>='], 'STEP', [1, '>=']]

    if check_template(tokens_lists, template1)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        @control = VariableName.new(tokens1[0])
        @start = ValueScalarExpression.new(tokens2)
        @end = ValueScalarExpression.new(tokens_lists[2])
        @step_value = ValueScalarExpression.new([NumericConstantToken.new(1)])
      rescue BASICExpressionError => e
        @errors << e.message
      end
    elsif check_template(tokens_lists, template2)
      begin
        tokens1, tokens2 = control_and_start(tokens_lists[0])
        @control = VariableName.new(tokens1[0])
        @start = ValueScalarExpression.new(tokens2)
        @end = ValueScalarExpression.new(tokens_lists[2])
        @step_value = ValueScalarExpression.new(tokens_lists[4])
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
    lines << 'step:    ' + @step_value.dump.to_s
    lines
  end

  def execute(interpreter)
    from = @start.evaluate(interpreter, true)[0]
    to = @end.evaluate(interpreter, true)[0]
    step = @step_value.evaluate(interpreter, true)[0]

    fornext_control =
      ForNextControl.new(@control, interpreter, from, to, step)

    interpreter.assign_fornext(fornext_control)
    interpreter.lock_variable(@control)
    terminated = fornext_control.front_terminated?
    if terminated
      interpreter.next_line_number =
        interpreter.find_closing_next(@control)
      interpreter.unlock_variable(@control)
    end

    io = interpreter.trace_out
    print_trace_info(io, from, to, step, terminated)
  end

  def variables
    vars = []
    vars << @control.to_s
    vars += @start.variables
    vars += @end.variables
    vars += @step_value.variables
  end

  private

  def control_and_start(tokens)
    parts = split_on_token(tokens, '=')
    raise(BASICError, 'Incorrect initialization') if
      parts.size != 3
    raise(BASICError, 'Incorrect initialization') if
      parts[1].to_s != '='

    @errors << 'Control variable must be a variable' unless
      parts[0][0].variable?

    [parts[0], parts[2]]
  end

  def print_trace_info(io, from, to, step, terminated)
    io.trace_output(" #{@start} = #{from}") unless @start.numeric_constant?
    io.trace_output(" #{@end} = #{to}") unless @end.numeric_constant?
    io.trace_output(" #{@step_value} = #{step}") unless @step_value.numeric_constant?
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

  def program_check(program, console_io, line_number)
    return true if program.line_number?(@destination)
    console_io.print_line("Line number #{@destination} not found in line #{line_number}")
    false
  end

  def execute(interpreter)
    interpreter.push_return(interpreter.next_line_number)
    interpreter.next_line_number = @destination
  end

  def renumber(renumber_map)
    @destination = renumber_map[@destination]
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

    template = [[1]]

    if check_template(tokens_lists, template)
      if tokens_lists[0][0].numeric_constant?
        @destination = LineNumber.new(tokens_lists[0][0])
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

  def program_check(program, console_io, line_number)
    return true if program.line_number?(@destination)
    console_io.print_line("Line number #{@destination} not found in line #{line_number}")
    false
  end

  def execute(interpreter)
    interpreter.next_line_number = @destination
  end

  def renumber(renumber_map)
    @destination = renumber_map[@destination]
    @tokens[-1] = NumericConstantToken.new(@destination.line_number)
  end
end

# IF/THEN
class IfStatement < AbstractStatement
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
      condition = tokens_lists[0]

      destination = tokens_lists[2]
      parse_line(condition, destination[0])
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    lines += @expression.dump unless @expression.nil?
    lines
  end

  def program_check(program, console_io, line_number)
    return true if program.line_number?(@destination)
    console_io.print_line("Line number #{@destination} not found in line #{line_number}")
    false
  end

  def execute(interpreter)
    io = interpreter.trace_out
    s = ' ' + @expression.to_s
    io.trace_output(s)
    values = @expression.evaluate(interpreter, true)
    raise(BASICRuntimeError, 'Expression error') unless
      values.size == 1
    result = values[0]
    raise(BASICRuntimeError, 'Expression error') unless
      result.class.to_s == 'BooleanConstant'
    interpreter.next_line_number = @destination if result.value

    s = ' ' + result.to_s
    io.trace_output(s)
  end

  def renumber(renumber_map)
    @destination = renumber_map[@destination]
    @tokens[-1] = NumericConstantToken.new(@destination.line_number)
  end

  def variables
    vars = []
    vars += @expression.variables unless @expression.nil?
    vars
  end

  private

  def parse_line(expression, destination)
    if destination.numeric_constant?
      @destination = LineNumber.new(destination)
    else
      @errors << "Invalid line number #{destination}"
    end

    begin
      @expression = ValueScalarExpression.new(expression)
    rescue BASICExpressionError => e
      @errors << e.message
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
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []

    unless @input_items.nil?
      @input_items.each { |item| lines += item.dump }
    end

    lines
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :read)

    prompt = nil
    unless @prompt.nil?
      prompts = @prompt.evaluate(interpreter, false)
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
      l_values = hash['name'].evaluate(interpreter, false)
      l_value = l_values[0]
      value = hash['value']
      interpreter.set_value(l_value, value)
    end
  end

  def variables
    vars = []

    vars += @file_tokens.variables unless @file_tokens.nil?

    unless @input_items.nil?
      @input_items.each { |item| vars += item.variables }
    end

    vars
  end

  private

  include FileFunctions

  def first_token(input_items)
    input_items[0][0]
  end

  def first_value(input_items, interpreter)
    first_list = input_items[0]
    expr = ValueScalarExpression.new(first_list)
    values = expr.evaluate(interpreter, false)
    values[0]
  end

  def extract_prompt(print_items)
    print_items = print_items.clone
    prompt = nil

    unless print_items.empty? ||
           print_items[0].class.to_s == 'CarriageControl'
      candidate_prompt_tokens = print_items[0]

      if candidate_prompt_tokens.text_constant?
        prompt = print_items.shift
        print_items.shift if
          print_items[0].class.to_s == 'CarriageControl'
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
    if tokens[0].operator? && tokens[0].to_s == '#'
      print_items << ValueScalarExpression.new(tokens)
    elsif tokens[0].text_constant?
      print_items << ValueScalarExpression.new(tokens)
    else
      print_items << TargetExpression.new(tokens, ScalarReference)
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
      fhr.prompt(prompt)
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

# LET
class LetStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('LET')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super

    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = ScalarAssignment.new(tokens_lists[0])

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value != 1
          @errors << 'Assignment must have only one right-hand value'
        end
      rescue BASICError => e
        @errors << e.message
      end
    else
      @errors << 'Syntax error'
    end
  end

  def dump
    lines = []
    lines += @assignment.dump unless @assignment.nil?
    lines
  end

  def execute(interpreter)
    l_values = @assignment.eval_target(interpreter)
    r_values = @assignment.eval_value(interpreter)
    r_value = r_values[0]
    l_values.each do |l_value|
      interpreter.set_value(l_value, r_value)
    end
  end
  
  def variables
    vars = []
    vars = @assignment.variables unless @assignment.nil?
    vars
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
        @control = VariableName.new(tokens_lists[0][0])
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
    # check control variable value
    # if matches end value, stop here
    terminated = fornext_control.terminated?(interpreter)
    io = interpreter.trace_out
    s = ' terminated:' + terminated.to_s
    io.trace_output(s)
    if terminated
      interpreter.unlock_variable(@control)
    else
      # set next line from top item
      interpreter.next_line_number = fornext_control.loop_start_number
      # change control variable value
      fornext_control.bump_control(interpreter)
    end
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
      lines << 'FILE'
      lines += @file_tokens.dump
    end

    lines << 'ITEMS'
    unless @print_items.nil?
      @print_items.each { |item| lines += item.dump }
    end

    lines
  end

  def variables
    vars = []

    vars += @file_tokens.variables unless @file_tokens.nil?

    unless @print_items.nil?
      @print_items.each { |item| vars += item.variables }
    end

    vars
  end

  private

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
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    @print_items.each do |item|
      item.print(fhr, interpreter)
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'ParamSeparatorToken'
        print_items << CarriageControl.new(tokens_list.to_s)
      end

      if tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end

    add_implied_items(print_items, @final)
    print_items
  end

  def add_expression(print_items, tokens)
    if !print_items.empty? &&
       print_items[-1].class.to_s == 'ValueScalarExpression'
      print_items << CarriageControl.new('')
    end

    print_items << ValueScalarExpression.new(tokens)

  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
  end
end

# common for READ, ARR READ, MAT READ
class AbstractReadStatement < AbstractStatement
  def initialize(keywords, tokens_lists)
    super
  end

  def dump
    lines = []

    unless @read_items.nil?
      @read_items.each { |item| lines += item.dump }
    end

    lines
  end

  def variables
    vars = []

    vars += @file_tokens.variables unless @file_tokens.nil?


    unless @read_items.nil?
      @read_items.each { |item| vars += item.variables }
    end

    vars
  end

  private

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
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @read_items.each do |item|
      targets = item.evaluate(interpreter, false)
      targets.each do |target|
        value = ds.read
        interpreter.set_value(target, value)
      end
    end
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
    if tokens[0].operator? && tokens[0].to_s == '#'
      print_items << ValueScalarExpression.new(tokens)
    else
      print_items << TargetExpression.new(tokens, ScalarReference)
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

# TRACE
class TraceStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('TRACE')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      @tokens_lists = split_tokens(tokens_lists[0], false)
    else
      @errors << 'Syntax error'
    end

    @errors << 'Too many values' if @tokens_lists.size > 1
    @expression = ValueScalarExpression.new(tokens_lists[0])
  end

  def dump
    @expression.dump
  end

  def execute(interpreter)
    values = @expression.evaluate(interpreter, true)
    value = values[0]
    interpreter.trace(value.to_v)
  end
  
  def variables
    vars = []
    vars += @expression.variables unless @expression.nil?
    vars
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

    unless @print_items.nil?
      @print_items.each { |item| lines += item.dump }
    end

    lines
  end

  def variables
    vars = []

    vars += @file_tokens.variables unless @file_tokens.nil?

    unless @print_items.nil?
      @print_items.each { |item| vars += item.variables }
    end

    vars
  end

  private

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
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    fhr = interpreter.get_file_handler(fh, :print)

    @print_items.each do |item|
      item.write(fhr, interpreter)
    end
  end

  private

  def tokens_to_expressions(tokens_lists)
    print_items = []

    tokens_lists.each do |tokens_list|
      if tokens_list.class.to_s == 'ParamSeparatorToken'
        print_items << CarriageControl.new(tokens_list.to_s)
      end

      if tokens_list.class.to_s == 'Array'
        add_expression(print_items, tokens_list)
      end
    end

    add_implied_items(print_items, @final)
    print_items
  end

  def add_expression(print_items, tokens)
    if !print_items.empty? &&
       print_items[-1].class.to_s == 'ValueScalarExpression'
      print_items << CarriageControl.new('')
    end

    print_items << ValueScalarExpression.new(tokens)

  rescue BASICExpressionError
    line_text = tokens.map(&:to_s).join
    @errors << 'Syntax error: "' + line_text + '" is not a value or operator'
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
    super(keywords, tokens_lists, CarriageControl.new(','))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
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
        item.print(fhr, interpreter, carriage)
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
      end

      if tokens_list.class.to_s == 'Array'
        print_items << ValueArrayExpression.new(tokens_list)
      end
    end

    add_implied_items(print_items, @final)
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
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @read_items.each do |item|
      targets = item.evaluate(interpreter, false)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?
        read_values(target.name, interpreter, ds)
      end
    end
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
    if tokens[0].operator? && tokens[0].to_s == '#'
      print_items << ValueScalarExpression.new(tokens)
    else
      print_items << TargetExpression.new(tokens, ArrayReference)
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

    (0..dims[0].to_i).each do |col|
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
    super(keywords, tokens_lists, CarriageControl.new(','))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
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
        item.write(fhr, interpreter, carriage)
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
      end

      if tokens_list.class.to_s == 'Array'
        print_items << ValueArrayExpression.new(tokens_list)
      end
    end

    add_implied_items(print_items, @final)
    print_items
  end
end

# ARR assignment
class ArrLetStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('ARR')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = ArrayAssignment.new(tokens_lists[0])
        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end
        if @assignment.count_value != 1
          @errors << 'Assignment must have only one right-hand value'
        end
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
    values = r_value.values

    l_values = @assignment.eval_target(interpreter)
    l_values.each do |l_value|
      interpreter.set_dimensions(l_value, dims)
      interpreter.set_values(l_value.name, values)
    end
  end
  
  def variables
    vars = []
    vars = @assignment.variables unless @assignment.nil?
    vars
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
    super(keywords, tokens_lists, CarriageControl.new(','))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
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
        item.print(fhr, interpreter, carriage)
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
      end

      if tokens_list.class.to_s == 'Array'
        print_items << ValueMatrixExpression.new(tokens_list)
      end
    end

    add_implied_items(print_items, @final)
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
    else
      @errors << 'Syntax error'
    end
  end

  def execute(interpreter)
    fh = get_file_handle(interpreter, @file_tokens)
    ds = interpreter.get_data_store(fh)

    @read_items.each do |item|
      targets = item.evaluate(interpreter, false)
      targets.each do |target|
        interpreter.set_dimensions(target, target.dimensions) if
          target.dimensions?
        read_values(target.name, interpreter, ds)
      end
    end
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
    if tokens[0].operator? && tokens[0].to_s == '#'
      print_items << ValueScalarExpression.new(tokens)
    else
      print_items << TargetExpression.new(tokens, MatrixReference)
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

    (1..dims[0].to_i).each do |col|
      coord = make_coord(col)
      values[coord] = ds.read
    end

    interpreter.set_values(name, values)
  end

  def read_matrix(name, dims, interpreter, ds)
    values = {}

    (1..dims[0].to_i).each do |row|
      (1..dims[1].to_i).each do |col|
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
    super(keywords, tokens_lists, CarriageControl.new(','))
    template = [[1, '>=']]

    if check_template(tokens_lists, template)
      tokens_lists = split_tokens(tokens_lists[0], true)
      print_items = tokens_to_expressions(tokens_lists)
      @file_tokens, @print_items = extract_file_handle(print_items)
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
        item.write(fhr, interpreter, carriage)
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
      end

      if tokens_list.class.to_s == 'Array'
        print_items << ValueMatrixExpression.new(tokens_list)
      end
    end

    add_implied_items(print_items, @final)
    print_items
  end
end

# MAT assignment
class MatLetStatement < AbstractStatement
  def self.lead_keywords
    [
      [KeywordToken.new('MAT')]
    ]
  end

  def initialize(keywords, tokens_lists)
    super
    template = [[3, '>=']]

    if check_template(tokens_lists, template)
      begin
        @assignment = MatrixAssignment.new(tokens_lists[0])

        if @assignment.count_target.zero?
          @errors << 'Assignment must have left-hand value(s)'
        end

        if @assignment.count_value != 1
          @errors << 'Assignment must have only one right-hand value'
        end

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
  
  def variables
    vars = []
    vars = @assignment.variables unless @assignment.nil?
    vars
  end
end
