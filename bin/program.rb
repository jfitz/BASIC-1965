# Contain line numbers
class LineNumber
  attr_reader :line_number

  def initialize(line_number)
    legals = %[IntegerConstant NilClass]
    
    raise BASICSyntaxError, "Invalid line number object '#{line_number.class}'" unless
      legals.include?(line_number.class.to_s)

    unless line_number.nil?
      @line_number = line_number.to_i

      raise BASICSyntaxError, "Invalid line number '#{@line_number}'" unless
        @line_number >= $options['min_line_num'].value

      raise BASICSyntaxError, "Invalid line number '#{@line_number}'" unless
        @line_number <= $options['max_line_num'].value
    end
  end

  def eql?(other)
    @line_number == other.line_number
  end

  def ==(other)
    @line_number == other.line_number
  end

  def hash
    @line_number.hash
  end

  def succ
    LineNumber.new(@line_number + 1)
  end

  def <=>(other)
    comp_value <=> other.comp_value
  end

  def >(other)
    comp_value > other.comp_value
  end

  def >=(other)
    comp_value >= other.comp_value
  end

  def <(other)
    comp_value < other.comp_value
  end

  def <=(other)
    comp_value <= other.comp_value
  end

  def dump
    self.class.to_s + ':' + @line_number.to_s
  end

  def comp_value
    @line_number.nil? ? 0 : @line_number
  end

  def to_s
    @line_number.to_s
  end
end

# line number range, in form start-end
class LineNumberRange
  attr_reader :list

  def initialize(start, endline, program_line_numbers)
    @list = []

    program_line_numbers.each do |line_number|
      @list << line_number if line_number >= start && line_number <= endline
    end
  end
end

# line number range, in form start-count (count default is 20)
class LineNumberCountRange
  attr_reader :list

  def initialize(start, count, program_line_numbers)
    @list = []

    program_line_numbers.each do |line_number|
      if line_number >= start && count >= 0
        @list << line_number
        count -= 1
      end
    end
  end
end

# LineStmt class to hold line number and index within line
class LineStmt
  attr_reader :line_number
  attr_reader :statement

  def initialize(line_number, statement)
    raise BASICError.new("line_number class is #{line_number.class}") unless
      line_number.class.to_s == 'LineNumber'

    @line_number = line_number
    @statement = statement
  end

  def eql?(other)
    @line_number == other.line_number && @statement == other.statement
  end

  def ==(other)
    @line_number == other.line_number && @statement == other.statement
  end

  def hash
    @line_number.hash + @statement.hash
  end

  def index
    0
  end

  def to_s
    return @line_number.to_s if @statement.zero?
    @line_number.to_s + '.' + @statement.to_s
  end
end

# LineStmtMod class to hold line number and index within line
class LineStmtMod
  attr_reader :line_number
  attr_reader :statement
  attr_reader :index

  def initialize(line_number, statement, mod)
    raise BASICError.new("line_number class is #{line_number.class}") unless
      line_number.class.to_s == 'LineNumber'

    @line_number = line_number
    @statement = statement
    @index = mod
  end

  def eql?(other)
    @line_number == other.line_number &&
      @statement == other.statement &&
      @index == other.index
  end

  def ==(other)
    @line_number == other.line_number &&
      @statement == other.statement &&
      @index == other.index
  end

  def hash
    @line_number.hash + @statement.hash + @index.hash
  end

  def to_s
    return @line_number.to_s if @statement.zero? && @index.zero?
    return @line_number.to_s + '.' + @statement.to_s if @index.zero?
    @line_number.to_s + '.' + @statement.to_s + '.' + @index.to_s
  end

  def get_counterpart
    other_mod = -@index
    LineStmtMod.new(@line_number, @statement, other_mod)
  end
end

# Line class to hold a line of code
class Line
  attr_reader :statements
  attr_reader :tokens
  attr_reader :warnings
  attr_accessor :origins
  attr_reader :destinations

  def initialize(text, statements, tokens, comment)
    @text = text
    @statements = statements
    @tokens = tokens
    @comment = comment
    @warnings = []

    list_width_max = $options['warn_list_width'].value
    @warnings << "Line exceeds LIST width limit #{list_width_max}" if
      list_width_max > 0 && text.size > list_width_max

    pretty_width_max = $options['warn_pretty_width'].value
    pretty_lines = pretty(false)
    pretty_line = pretty_lines[0]
    @warnings << "Line exceeds PRETTY width limit #{pretty_width_max}" if
      pretty_width_max > 0 && pretty_line.size > pretty_width_max
  end

  def uncache
    @statements.each(&:uncache)
  end

  def reset_profile_metrics
    @statements.each(&:reset_profile_metrics)
  end

  def reset_reachable
    @statements.each { |statement| statement.reachable = false }
  end

  def set_reachable(stmt)
    statement = @statements[stmt]

    return false if statement.nil?

    any_changes = statement.reachable == false
    statement.reachable = true

    any_changes
  end

  def number_valid_statements
    num = 0
    @statements.each { |statement| num += 1 if statement.valid }
    num
  end

  def number_exec_statements
    num = 0
    @statements.each { |statement| num += 1 if statement.executable }
    num
  end

  def number_comments
    num = 0
    @statements.each { |statement| num += 1 if statement.comment }
    num
  end

  def comprehension_effort
    num = 0
    @statements.each { |statement| num += statement.comprehension_effort }
    num
  end

  def mccabe_complexity
    num = 0
    @statements.each { |statement| num += statement.mccabe }
    num
  end

  def list
    @text
  end

  def pretty(multiline)
    if multiline
      pretty_lines = AbstractToken.pretty_multiline([], @tokens)
    else
      pretty_lines = [AbstractToken.pretty_tokens([], @tokens)]
    end

    pl2 = []

    pretty_lines.each do |pretty_line|
      pretty_line = ' ' + pretty_line unless pretty_line.empty?
      pl2 << pretty_line
    end

    pretty_lines = pl2

    unless @comment.nil?
      line_0 = pretty_lines[0]
      space = @text.size - (line_0.size + @comment.to_s.size)
      space = 5 if space < 5
      line_0 += ' ' * space
      line_0 += @comment.to_s
      pretty_lines[0] = line_0
    end

    pretty_lines
  end

  def analyze_pretty(number)
    texts = []

    @statements.each do |statement|
      texts += statement.analyze_pretty(number)

      number = ' ' * number.size
    end

    @statements.each do |statement|
      errors = statement.errors
      errors.each { |error| texts << "#{number} #{error}" }

      errors = statement.program_errors
      errors.each { |error| texts << "#{number} #{error}" }
    end

    texts
  end

  def parse
    texts = []

    @statements.each { |statement| texts << statement.dump }

    texts
  end

  def profile(number, show_timing)
    texts = []

    @statements.each do |statement|
      profile_lines = statement.profile(show_timing)

      profile_lines.each do |profile|
        text = number + profile
        texts << text

        number = ' ' * number.size
      end
    end

    texts
  end

  def renumber(renumber_map)
    tokens = []
    separator = StatementSeparatorToken.new('\\')

    @statements.each do |statement|
      statement.renumber(renumber_map)
      tokens << statement.keywords
      tokens << statement.tokens
      tokens << separator
    end

    tokens.pop
    text = AbstractToken.pretty_tokens([], tokens.flatten)
    text = ' ' + text unless text.empty?
    Line.new(text, @statements, tokens.flatten, @comment)
  end

  def build_destinations(line_number)
    @destinations = []

    @statements.each do |statement|
      # built-in transfers
      xfers = statement.transfers

      # auto-line transfers
      xfers += statement.transfers_auto

      # convert TransferRefLineStmt objects to TransferRefLine objects
      xfers.each do |xfer|
        # only transfers that have a different line number
        # we don't care about intra-line transfers
        @destinations << TransferRefLine.new(xfer.line_number, xfer.type) if
          xfer.line_number != line_number
      end
    end
  end

  def line_stmts(line_number)
    dests = {}

    @statements.each_with_index do |statement, stmt|
      line_number_stmt = LineStmt.new(line_number, stmt)

      xfers = statement.transfers
      xfers += statement.transfers_auto

      line_stmts = []

      # convert TransferRefLineStmt objects to LineStmt objects
      xfers.each do |xfer|
        line_stmts << LineStmt.new(xfer.line_number, xfer.statement)
      end

      dests[line_number_stmt] = line_stmts
    end

    dests
  end
end

# line reference for cross reference
class LineRef
  attr_reader :line_num
  attr_reader :assignment

  def initialize(line_num, assignment)
    @line_num = line_num
    @assignment = assignment
  end

  def eql?(other)
    @line_num == other.line_num &&
      @assignment == other.assignment
  end

  def ==(other)
    @line_num == other.line_num &&
      @assignment == other.assignment
  end

  def hash
    @line_num.hash + @assignment.hash
  end

  def <=>(other)
    return @assignment <=> other.assignment if @line_num == other.line_num

    @line_num <=> other.line_num
  end

  def to_s
    if @assignment
      @line_num.to_s + '='
    else
      @line_num.to_s
    end
  end
end

# Contain line number ranges
# used in LIST and DELETE commands
class LineListSpec
  attr_reader :line_numbers
  attr_reader :range_type

  def initialize(tokens, program_line_numbers)
    @line_numbers = []
    @range_type = :empty

    if tokens.empty?
      @line_numbers = program_line_numbers
      @range_type = :all
    elsif tokens.size == 1 &&
          tokens[0].numeric_constant?
      make_single(tokens[0], program_line_numbers)
    elsif tokens.size == 3 &&
          tokens[0].numeric_constant? &&
          tokens[1].to_s == '-' &&
          tokens[2].numeric_constant?
      make_range(tokens, program_line_numbers)
    elsif tokens.size == 2 &&
          tokens[0].numeric_constant? &&
          tokens[1].to_s == '+'
      make_count_range(tokens, program_line_numbers)
    elsif tokens.size == 3 &&
          tokens[0].numeric_constant? &&
          tokens[1].to_s == '+' &&
          tokens[2].numeric_constant?
      make_count_range(tokens, program_line_numbers)
    else
      raise(BASICCommandError, 'Invalid list specification')
    end
  end

  private

  def make_single(token, program_line_numbers)
    number = IntegerConstant.new(token)
    line_number = LineNumber.new(number)

    @line_numbers << line_number if
      program_line_numbers.include?(line_number)

    @range_type = :single
  end

  def make_range(tokens, program_line_numbers)
    start_number = IntegerConstant.new(tokens[0])
    start = LineNumber.new(start_number)
    end_number = IntegerConstant.new(tokens[2])
    endline = LineNumber.new(end_number)
    range = LineNumberRange.new(start, endline, program_line_numbers)
    @line_numbers = range.list
    @range_type = :range
  end

  def make_count_range(tokens, program_line_numbers)
    start_number = IntegerConstant.new(tokens[0])
    start = LineNumber.new(start_number)
    count = 20
    count = NumericConstant.new(tokens[2]).to_i if tokens.size > 2
    range = LineNumberCountRange.new(start, count, program_line_numbers)
    @line_numbers = range.list
    @range_type = :range
  end
end

# transfer of control
class TransferRefLineStmt
  attr_reader :line_number
  attr_reader :statement
  attr_reader :type

  def initialize(line_number, statement, type)
    raise BASICError.new("Invalid line number #{line_number.class}:#{line_number}") unless
      line_number.class.to_s == 'LineNumber'

    @line_number = line_number
    @statement = statement
    @type = type
  end

  def eql?(other)
    @line_number == other.line_number &&
      @statement == other.statement &&
      @type == other.type
  end

  def ==(other)
    @line_number == other.line_number &&
      @statement == other.statement &&
      @type == other.type
  end

  def hash
    @line_number.hash + @statement.hash + @type.hash
  end

  def <=>(other)
    if @line_number == other.line_number
      if @statement == other.statement
        @type <=> other.type
      else
        @statement <=> other.statement
      end
    else
      @line_number <=> other.line_number
    end
  end

  def to_s
    "#{@line_number}:#{@statement}:#{@type}"
  end
end

# transfer of control
class TransferRefLine
  attr_reader :line_number
  attr_reader :type

  def initialize(line_number, type)
    raise BASICError.new("Invalid line number #{line_number.class}:#{line_number}") unless
      line_number.class.to_s == 'LineNumber'

    @line_number = line_number
    @type = type
  end

  def eql?(other)
    @line_number == other.line_number && @type == other.type
  end

  def ==(other)
    @line_number == other.line_number && @type == other.type
  end

  def hash
    @line_number.hash + @type.hash
  end

  def <=>(other)
    if @line_number == other.line_number
      @type <=> other.type
    else
      @line_number <=> other.line_number
    end
  end

  def statement
    0
  end

  def to_s
    "#{@line_number}:#{@type}"
  end
end

# program container
class Program
  attr_reader :lines

  def initialize(console_io, tokenbuilders)
    @console_io = console_io
    @statement_factory = StatementFactory.instance
    @statement_factory.tokenbuilders = tokenbuilders
    @lines = {}
    @errors = []
  end

  def clear
    @lines = {}
    @errors = []
  end

  def uncache
    @lines.each { |line_number, line| line.uncache }
  end

  def empty?
    @lines.empty?
  end

  def errors
    texts = []

    @errors.each do |error|
      texts << "error #{error['message']} in line #{error['line']}"
    end

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        errors = statement.errors
        errors.each { |error| texts << error + " in line #{line_number}" }

        errors = statement.program_errors
        errors.each { |error| texts << error + " in line #{line_number}" }
      end
    end

    texts
  end

  def find_next_line(current_line_stmt_mod)
    # find next numbered statement
    line_numbers = @lines.keys.sort
    line_number = current_line_stmt_mod.line_number
    index = line_numbers.index(line_number)
    next_line_number = line_numbers[index + 1]

    unless next_line_number.nil?
      line = @lines[next_line_number]
      statements = line.statements
      statement = statements[0]
      start_mod = statement.start_index
      next_line_stmt_mod = LineStmtMod.new(next_line_number, 0, start_mod)

      return next_line_stmt_mod
    end

    # nothing left to execute
    nil
  end

  def find_first_statement
    # set next line to first statement
    line_number = first_line_number
    line = lines[line_number]

    statements = line.statements
    stmt = 0
    part_of_user_function = nil

    # find next statement within the current line
    stmt += 1 while
      stmt < statements.size &&
      statements[stmt].part_of_user_function != part_of_user_function

    if stmt < statements.size
      start_mod = statements[stmt].start_index

      return LineStmtMod.new(line_number, stmt, start_mod)
    end

    # find the next statement in a following line
    line_numbers = @lines.keys.sort
    index = line_numbers.index(line_number) + 1
    line_number = line_numbers[index]

    until line_number.nil?
      line = @lines[line_number]

      statements = line.statements
      stmt = 0

      stmt += 1 while
        stmt < statements.size &&
        statements[stmt].part_of_user_function != part_of_user_function

      if stmt < statements.size
        start_mod = statements[stmt].start_index

        return LineStmtMod.new(line_number, stmt, start_mod)
      end

      index += 1
      line_number = line_numbers[index]
    end

    # nothing left to execute
    nil
  end

  def find_next_line_stmt(current_line_stmt)
    # find next index with current statement
    line_number = current_line_stmt.line_number
    line = @lines[line_number]

    statements = line.statements
    stmt = current_line_stmt.statement
    part_of_user_function = statements[stmt].part_of_user_function

    # find next statement within the current line
    stmt += 1

    stmt += 1 while
      stmt < statements.size &&
      statements[stmt].part_of_user_function != part_of_user_function

    return LineStmt.new(line_number, stmt) if stmt < statements.size

    # find the next statement in a following line
    line_numbers = @lines.keys.sort
    line_number = current_line_stmt.line_number
    index = line_numbers.index(line_number) + 1
    line_number = line_numbers[index]

    until line_number.nil?
      line = @lines[line_number]

      statements = line.statements
      stmt = 0

      stmt += 1 while
        stmt < statements.size &&
        statements[stmt].part_of_user_function != part_of_user_function

      return LineStmt.new(line_number, stmt) if stmt < statements.size

      index += 1
      line_number = line_numbers[index]
    end

    # nothing left to execute
    nil
  end

  def find_next_line_stmt_mod(current_line_stmt_mod)
    # find next index with current statement
    line_number = current_line_stmt_mod.line_number
    line = @lines[line_number]

    statements = line.statements
    stmt = current_line_stmt_mod.statement
    statement = statements[stmt]
    part_of_user_function = statement.part_of_user_function

    mod = current_line_stmt_mod.index

    if mod < statement.last_index
      mod += 1
      return LineStmtMod.new(line_number, stmt, mod)
    end

    # find next statement within the current line
    stmt += 1

    stmt += 1 while
      stmt < statements.size &&
      statements[stmt].part_of_user_function != part_of_user_function

    if stmt < statements.size
      start_mod = statements[stmt].start_index

      return LineStmtMod.new(line_number, stmt, start_mod)
    end

    # find the next statement in a following line
    line_numbers = @lines.keys.sort
    line_number = current_line_stmt_mod.line_number
    index = line_numbers.index(line_number) + 1
    line_number = line_numbers[index]

    until line_number.nil?
      line = @lines[line_number]

      statements = line.statements
      stmt = 0

      stmt += 1 while
        stmt < statements.size &&
        statements[stmt].part_of_user_function != part_of_user_function

      if stmt < statements.size
        start_mod = statements[stmt].start_index

        return LineStmtMod.new(line_number, stmt, start_mod)
      end

      index += 1
      line_number = line_numbers[index]
    end

    # nothing left to execute
    nil
  end

  def line_number?(line_number)
    @lines.key?(line_number)
  end

  def first_line_number
    @lines.min[0]
  end

  def user_function_line(function_signature)
    @user_function_start_lines[function_signature]
  end

  private

  def line_list_spec(tokens)
    line_numbers = @lines.keys.sort
    LineListSpec.new(tokens, line_numbers)
  end

  def renumber_spec(tokens)
    start = 10
    step = 10

    i = 0

    # do not change to each_with_index
    # separator tokens are still present
    tokens.each do |token|
      if token.class.to_s == 'NumericConstantToken'
        case i
        when 0
          # first number is step
          step = token.to_i
          start = token.to_i
        when 1
          # second number is start
          start = token.to_i
        end

        i += 1
      end
    end

    raise(BASICCommandError, 'Invalid renumber step') if step.zero?

    [start, step]
  end

  public

  def list(args, list_tokens)
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    line_number_range = line_list_spec(args)
    line_numbers = line_number_range.line_numbers
    list_lines_errors(line_numbers, list_tokens)
  end

  def parse(args)
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    line_number_range = line_list_spec(args)
    line_numbers = line_number_range.line_numbers
    parse_lines_errors(line_numbers)
  end

  # report statistics, complexity, and the lines which are unreachable
  def analyze
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    texts = []

    unless @errors.empty?
      @errors.each do |error|
        texts << "error #{error['message']} in line #{error['line']}"
      end

      texts << ''
    end
    
    # report statistics
    texts << 'Statistics:'
    texts << ''
    texts += code_statistics
    texts << ''

    # report complexity
    texts << 'Complexity:'
    texts << ''
    texts += code_complexity
    texts << ''

    texts += analyze_pretty

    # report unreachable lines
    texts << 'Unreachable code:'
    texts << ''
    texts += unreachable_code
  end

  def analyze_pretty
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    texts = []

    build_line_destinations
    build_line_origins

    # add marker for entry point (first active line)
    first_line_number_stmt_mod = find_first_statement
    line_number = first_line_number_stmt_mod.line_number
    line = @lines[line_number]
    unless line.nil?
      line.origins = [] if line.origins.nil?
      empty_line_number = LineNumber.new(nil)
      line.origins << TransferRefLine.new(empty_line_number, :start)
    end

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]

      # pretty-print the line with complexity statistics
      number = line_number.to_s
      
      texts += line.analyze_pretty(number)

      # print origins to this line
      line_origins = line.origins
      line_origins = [] if line_origins.nil?
      origs = line_origins.sort.uniq.map(&:to_s).join(', ')
      texts << '  Origs: ' + origs

      # check all origins are consistent for GOSUB
      any_gosub = false
      any_other = false
      line_origins.each do |origin|
        any_gosub = true if origin.type == :gosub
        any_other = true if origin.type != :gosub
      end
      texts << '  Inconsistent GOSUB origins' if any_gosub && any_other

      # print destinations from this line
      line_dests = line.destinations
      line_dests = [] if line_dests.nil?
      dests = line_dests.sort.uniq.map(&:to_s).join(', ')
      texts << '  Dests: ' + dests
    end

    texts << ''
  end

  def pretty(args, pretty_multiline)
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    line_number_range = line_list_spec(args)
    line_numbers = line_number_range.line_numbers
    pretty_lines_errors(line_numbers, pretty_multiline)
  end

  def reset_profile_metrics
    @lines.each { |line_number, line| line.reset_profile_metrics }
  end

  private

  def code_statistics
    lines = []

    lines << 'Number of lines: ' + @lines.size.to_s
    lines << 'Number of valid statements: ' + number_valid_statements.to_s
    lines << 'Number of comments: ' + number_comments.to_s
    lines << 'Number of executable statements: ' + number_exec_statements.to_s
  end

  def number_valid_statements
    num = 0
    @lines.each { |_, line| num += line.number_valid_statements }
    num
  end

  def number_exec_statements
    num = 0
    @lines.each { |_, line| num += line.number_exec_statements }
    num
  end

  def number_comments
    num = 0
    @lines.each { |_, line| num += line.number_comments }
    num
  end

  def comprehension_effort
    num = 0
    @lines.each { |_, line| num += line.comprehension_effort }
    num
  end

  def mccabe_complexity
    num = 1
    @lines.each { |_, line| num += line.mccabe_complexity }
    num
  end

  def halstead
    list_operators = []
    list_constants = []
    list_variables = []
    list_functions = []
    list_linenums = []
    list_separators = []

    operator_keywords = %w[FOR GOTO GOSUB IF NEXT RETURN]

    @lines.each do |_, line|
      statements = line.statements

      statements.each do |statement|
        list_operators += statement.operators

        tokens = statement.keywords.flatten + statement.tokens
        keywords = []

        tokens.each do |token|
          t = token.to_s
          keywords << t if token.keyword?
        end

        keywords.each do |keyword|
          list_operators << keyword if operator_keywords.include?(keyword)
        end

        list_constants += statement.numerics
        list_constants += statement.strings
        list_variables += statement.variables
        list_functions += statement.functions
        list_functions += statement.userfuncs
        list_linenums += statement.linenums

        list_separators += statement.separators
      end
    end

    num_operators = list_operators.size
    num_distinct_operators = list_operators.uniq.size

    num_constants = list_constants.size
    num_distinct_constants = list_constants.uniq.size

    num_variables = list_variables.size
    num_distinct_variables = list_variables.uniq.size

    num_functions = list_functions.size
    num_distinct_functions = list_functions.uniq.size

    num_linenums = list_linenums.size
    num_distinct_linenums = list_linenums.uniq.size

    num_separators = list_separators.size
    num_distinct_separators = list_separators.uniq.size

    # Halstead definitions
    # number of operators
    n1 = num_distinct_operators + num_distinct_functions + num_distinct_separators
    n2 = num_distinct_constants + num_distinct_variables + num_distinct_linenums
    nn1 = num_operators + num_functions + num_separators
    nn2 = num_constants + num_variables + num_linenums

    # compute length, volume, abstraction level, effort
    length = nn1 + nn2
    vocabulary = n1 + n2
    volume = 0
    volume = length * Math.log(vocabulary) if vocabulary > 0
    difficulty = 0
    difficulty = (n1.to_f / 2) * (nn2.to_f / n2) if n2 > 0
    effort = difficulty * volume
    language_level = 0
    language_level = volume / difficulty**2 if difficulty > 0
    intelligence = 0
    intelligence = volume / difficulty if difficulty > 0
    time = effort / (60 * 18) # 18 is the Stoud number for programming

    [
      length,
      vocabulary,
      volume,
      difficulty,
      effort,
      language_level,
      intelligence,
      time
    ]
  end

  def build_line_destinations
    # build list of "gotos"
    @lines.each do |line_number, line|
      line.build_destinations(line_number)
    end
  end

  def build_line_origins
    # build list of "come-froms"
    @lines.each { |_, line| line.origins = [] }
    
    origins = {}

    # for each line
    @lines.each do |line_number, line|
      # get destinations
      destinations = line.destinations

      # for each destination
      destinations.each do |dest|
        # get its line
        dest_line = @lines[dest.line_number]

        # add transfer to origin table
        unless dest_line.nil?
          dest_line.origins << TransferRefLine.new(line_number, dest.type)
        end
      end
    end
  end

  def build_line_stmts
    # build dictionary of destination LineStmt objects
    line_stmts = {}

    @lines.each do |line_number, line|
      line_line_stmts = line.line_stmts(line_number)

      line_line_stmts.each do |line_number_stmt, stmt_line_stmts|
        line_stmts[line_number_stmt] = stmt_line_stmts
      end
    end

    line_stmts
  end

  def unreachable_code
    line_stmts = build_line_stmts

    # assume statements are dead until connected to a live statement
    @lines.each { |_, line| line.reset_reachable }

    # first line is live
    first_line_number_stmt_mod = find_first_statement
    first_line_number = first_line_number_stmt_mod.line_number
    first_line = @lines[first_line_number]
    first_stmt = first_line_number_stmt_mod.statement
    first_line.set_reachable(first_stmt)

    # walk the entire program and mark lines as live
    # repeat until no changes
    any_changes = true
    while any_changes
      any_changes = false

      @lines.each do |line_number, line|
        statements = @lines[line_number].statements

        statements.each_with_index do |statement, stmt|
          # only reachable lines can reach other lines
          if statement.reachable
            # a reachable line updates its targets to 'reachable'
            line_number_stmt = LineStmt.new(line_number, stmt)
            stmt_line_stmts = line_stmts[line_number_stmt]

            stmt_line_stmts.each do |line_stmt|
              dest_line_number = line_stmt.line_number
              dest_line = @lines[dest_line_number]
              dest_stmt = line_stmt.statement
              any_changes = dest_line.set_reachable(dest_stmt) unless
                dest_line.nil?
            end
          end
        end
      end
    end

    # build list of lines that are not reachable
    lines = []
    @lines.each do |line_number, line|
      statements = line.statements
      statements.each_with_index do |statement, stmt|
        if statement.executable && !statement.reachable
          text = statement.pretty
          line_number_stmt = LineStmt.new(line_number, stmt)
          lines << "#{line_number_stmt}: #{text}" unless text.empty?
        end
      end
    end

    lines << 'All executable lines are reachable.' if lines.empty?
    lines
  end

  def code_complexity
    lines = []

    num_comm = number_comments
    num_valid = number_valid_statements
    density = 0
    density = num_comm.to_f / num_valid.to_f if num_valid > 0
    lines << 'Comment density: ' + ('%.3f' % density)

    lines << 'Comprehension effort: ' + comprehension_effort.to_s

    lines << 'McCabe complexity: ' + mccabe_complexity.to_s

    lines << 'Halstead complexity:'
    length, vocabulary, volume, difficulty, effort, language, intelligence, time = halstead
    lines << ' length: ' + length.to_s
    lines << ' volume: ' + ('%.3f' % volume)
    lines << ' difficulty: ' + ('%.3f' % difficulty)
    lines << ' effort: ' + ('%.3f' % effort)
    lines << ' language: ' + ('%.3f' % language)
    lines << ' intelligence: ' + ('%.3f' % intelligence)
    lines << ' time: ' + ('%.3f' % time)
  end

  public

  def errors?
    any_errors = !@errors.empty?

    @lines.each do |line_number, line|
      statements = line.statements
      statements.each { |statement| any_errors |= statement.errors? }
    end

    any_errors
  end

  def optimize(interpreter)
    optimize_statements(interpreter)
    assign_singleline_function_markers
    assign_multiline_function_markers
    assign_autonext
    set_transfers
    set_transfers_auto
    check_program
    check_function_markers
  end

  def optimize_statements(interpreter)
    @errors = []

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        line_stmt = LineStmt.new(line_number, stmt)
        statement.optimize(interpreter, line_stmt, self)
      end
    end
  end

  def assign_singleline_function_markers
    @user_function_start_lines = {}
    part_of_user_function = nil

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        if statement.singledef?
          function_signature = statement.function_signature
          line_stmt_mod = LineStmtMod.new(line_number, stmt, 0)
          @user_function_start_lines[function_signature] = line_stmt_mod
          part_of_user_function = function_signature
        end

        statement.part_of_user_function = part_of_user_function

        part_of_user_function = nil
      end
    end
  end

  def assign_multiline_function_markers
    part_of_user_function = nil

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        if statement.multidef?
          function_signature = statement.function_signature
          line_stmt_mod = LineStmtMod.new(line_number, stmt, 0)
          @user_function_start_lines[function_signature] = line_stmt_mod
          part_of_user_function = function_signature
        end

        unless part_of_user_function.nil?
          if statement.part_of_user_function.nil?
            statement.part_of_user_function = part_of_user_function 
          else
            @errors <<
            {
              'message' => "Embedded function #{statement.part_of_user_function}",
              'line' => line_number
            }
          end
        end

        part_of_user_function = nil if statement.multiend?
      end
    end
  end

  def assign_autonext
    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        statement.set_autonext_line_stmt(nil)

        if statement.autonext
          start_mod = statement.start_index
          line_stmt = LineStmt.new(line_number, stmt)

          # get statement at start of next line
          next_line_number_stmt_mod = find_next_line(line_stmt)

          statement.set_autonext_line(next_line_number_stmt_mod) unless
            next_line_number_stmt_mod.nil?

          # get next statement (may be on same line)
          next_line_stmt = find_next_line_stmt(line_stmt)

          unless next_line_stmt.nil?
            next_line_number = next_line_stmt.line_number
            next_stmt = next_line_stmt.statement
            next_line = @lines[next_line_number]

            unless next_line.nil?
              next_statements = next_line.statements

              next_statement = next_statements[next_stmt]

              unless next_statement.nil?
                next_mod = next_statement.start_index
                next_line_stmt_mod = LineStmtMod.new(next_line_number, next_stmt, next_mod)
                statement.set_autonext_line_stmt(next_line_stmt_mod)
              end
            end
          end
        end
      end
    end
  end

  def set_transfers
    @lines.each do |line_number, line|
      statements = line.statements

      statements.each do |statement|
        statement.set_transfers(@user_function_start_lines)
      end
    end
  end

  def set_transfers_auto
    @lines.each do |line_number, line|
      statements = line.statements

      statements.each do |statement|
        statement.set_transfers_auto
      end
    end
  end

  def init_data(interpreter)
    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        statement.init_data(interpreter)
      end
    end
  end

  def check_program
    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        line_number_stmt = LineStmt.new(line_number, stmt)
        statement.check_program(self, line_number_stmt)
      end
    end
  end

  def check_function_markers
    part_of_user_function = nil

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        if !part_of_user_function.nil? && statement.multidef?
          @errors <<
          {
            'message' => "Missing FNEND before DEF",
            'line' => line_number
          }
        end

        if statement.multidef?
          part_of_user_function = statement.function_signature
        end

        part_of_user_function = nil if statement.multiend?
      end
    end
  end

  def find_closing_next_line_stmt(control, current_line_stmt)
    # move to the next statement
    line_number = current_line_stmt.line_number
    line = @lines[line_number]
    statements = line.statements

    walk_line_stmt = current_line_stmt

    # search for a NEXT with the same control variable
    for_level = 0

    until walk_line_stmt.nil?
      line_number = walk_line_stmt.line_number
      stmt = walk_line_stmt.statement
      line = @lines[line_number]

      statement = @lines[line_number].statements[stmt]

      for_level += statement.number_for_stmts

      # consider only core statements, not modifiers

      if statement.class.to_s == 'NextStatement'
        stmt_control = statement.control

        for_level -= 1

        raise BASICPreexecuteError.new(:te_for_no_next, control.to_s) if
          for_level < 0

        if stmt_control == control ||
           stmt_control.empty? && for_level.zero?
          return LineStmt.new(line_number, stmt)
        end
      end

      walk_line_stmt = find_next_line_stmt(walk_line_stmt)
    end

    # if none found, error
    raise BASICPreexecuteError.new(:te_for_no_next, control.to_s)
  end

  def find_closing_endfunc_line_stmt(name, current_line_stmt)
    # move to the next statement
    line_number = current_line_stmt.line_number
    line = @lines[line_number]
    statements = line.statements

    walk_line_stmt = current_line_stmt

    # search for a ENDFUNCTION or FNEND
    until walk_line_stmt.nil?
      line_number = walk_line_stmt.line_number
      stmt = walk_line_stmt.statement
      line = @lines[line_number]

      statement = @lines[line_number].statements[stmt]

      # consider only core statements, not modifiers

      if statement.class.to_s == 'FnendStatement'
        return LineStmt.new(line_number, stmt)
      end

      walk_line_stmt = find_next_line_stmt(walk_line_stmt)
    end

    # if none found, error
    raise BASICPreexecuteError.new(:te_deffun_no_endfun, name.to_s)
  end

  def profile(args, show_timing)
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    line_number_range = line_list_spec(args)
    line_numbers = line_number_range.line_numbers
    profile_lines_errors(line_numbers, show_timing)
  end

  def save
    lines = []

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      lines << line_number.to_s + line.list
    end

    lines
  end

  def delete(args)
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    line_number_range = line_list_spec(args)

    raise(BASICCommandError, 'Type NEW to delete an entire program') if
      line_number_range.range_type == :all

    line_numbers = line_number_range.line_numbers
    delete_specific_lines(line_numbers)
  end

  def enblank(args)
    line_number_range = line_list_spec(args)

    raise(BASICCommandError, 'No program loaded') if
      @lines.empty?

    raise(BASICCommandError, 'You cannot delete an entire program') if
      line_number_range.range_type == :all

    line_numbers = line_number_range.line_numbers
    enblank_specific_lines(line_numbers)
  end

  # generate new line numbers
  def renumber(args)
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    start, step = renumber_spec(args)
    renumber_map = {}
    new_number = start

    @lines.keys.sort.each do |line_number|
      token = NumericConstantToken.new(new_number)
      number = IntegerConstant.new(token)
      new_line_number = LineNumber.new(number)
      renumber_map[line_number] = new_line_number
      new_number += step
    end

    # assign new line numbers
    new_lines = {}

    @lines.keys.sort.each do |line_number|
      new_line_number = renumber_map[line_number]
      line = @lines[line_number]
      new_lines[new_line_number] = line.renumber(renumber_map)
    end

    @lines = new_lines
    renumber_map
  end

  private

  def numeric_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs += statement.numerics
        rs += statement.modifier_numerics
      end

      refs[line_number] = rs
    end

    refs
  end

  def booleans_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs += statement.booleans
        rs += statement.modifier_booleans
      end

      refs[line_number] = rs
    end

    refs
  end

  def strings_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs += statement.strings
        rs += statement.modifier_strings
      end

      refs[line_number] = rs
    end

    refs
  end

  def function_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs = statement.functions
        rs += statement.modifier_functions
      end

      refs[line_number] = rs
    end

    refs
  end

  def user_function_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs += statement.userfuncs
        rs += statement.modifier_userfuncs
      end

      refs[line_number] = rs
    end

    refs
  end

  def variables_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs += statement.variables
        rs += statement.modifier_variables
      end

      refs[line_number] = rs
    end

    refs
  end

  def operators_refs
    refs = {}

    @lines.each do |line_number, line|
      statements = line.statements

      rs = []

      statements.each do |statement|
        rs += statement.operators
        rs += statement.modifier_operators
      end

      refs[line_number] = rs
    end

    refs
  end

  def linenums_refs
    refs = {}

    @lines.each do |line_number, line|
      line = @lines[line_number]
      statements = line.statements

      rs = []

      statements.each { |statement| rs += statement.linenums }

      refs[line_number] = rs
    end

    refs
  end

  def print_numeric_refs(refs)
    texts = []

    # find length of longest token
    num_spaces = 0

    refs.keys.sort.each do |ref|
      token = ref.symbol_text
      size = token.size
      num_spaces = size if size > num_spaces
    end

    # print each token and its referring lines
    refs.keys.sort.each do |ref|
      token = ref.symbol_text
      n_spaces = num_spaces - token.size + 2
      spaces = ' ' * n_spaces
      lines = refs[ref]
      line_refs = lines.sort.map(&:to_s).uniq.join(', ')

      texts << token + ':' + spaces + line_refs
    end

    texts
  end

  def print_object_refs(refs)
    texts = []

    # find length of longest token
    num_spaces = 0

    refs.keys.sort.each do |ref|
      token = ref.to_s
      size = token.size
      # longer tokens list token and referrals on second line
      num_spaces = size if size > num_spaces && size < 41
    end

    # print each token and its referring lines
    refs.keys.sort.each do |ref|
      token = ref.to_s
      lines = refs[ref]
      line_refs = lines.sort.map(&:to_s).uniq.join(', ')

      if token.size < 41
        n_spaces = num_spaces - token.size + 2
        spaces = ' ' * n_spaces

        texts << token + ':' + spaces + line_refs
      else
        n_spaces = 5
        spaces = ' ' * n_spaces

        texts << token + ':'
        texts << spaces + line_refs
      end
    end

    texts
  end

  def print_unused(variables)
    texts = []

    # split variable references into 'reference' and 'value' lists
    vars_refs = []
    vars_vals = []

    variables.keys.sort.each do |xref|
      if xref.is_ref
        vars_refs << xref.to_text
      else
        vars_vals << xref.to_text
      end
    end

    # identify variables assigned but not used
    unused = []

    vars_refs.each do |var_ref|
      unused << var_ref unless vars_vals.include?(var_ref)
    end

    # identify variables used but not assigned
    unassigned = []

    vars_vals.each do |var_val|
      unassigned << var_val unless vars_refs.include?(var_val)
    end

    unless unused.empty?
      texts << ''
      texts << 'Assigned but not used: ' + unused.join(', ')
    end

    unless unassigned.empty?
      texts << ''
      texts << 'Used but not assigned: ' + unassigned.join(', ')
    end

    texts
  end

  def make_summary(list)
    summary = {}

    list.each do |line_number, refs|
      line_ref = LineRef.new(line_number, false)

      refs.each do |ref|
        entries = summary.key?(ref) ? summary[ref] : []
        entries << line_ref
        summary[ref] = entries
      end
    end

    summary
  end

  public

  # generate cross-reference list
  def crossref
    raise(BASICCommandError, 'No program loaded') if @lines.empty?

    texts = []

    texts << 'Cross reference'

    nums_list = numeric_refs
    numerics = make_summary(nums_list)
    unless numerics.empty?
      texts << ''
      texts << 'Numeric constants:'
      texts += print_numeric_refs(numerics)
    end

    strs_list = strings_refs
    strings = make_summary(strs_list)
    unless strings.empty?
      texts << ''
      texts << 'String constants:'
      texts += print_object_refs(strings)
    end

    bool_list = booleans_refs
    booleans = make_summary(bool_list)
    unless booleans.empty?
      texts << ''
      texts << 'Boolean constants:'
      texts += print_numeric_refs(booleans)
    end

    funcs_list = function_refs
    functions = make_summary(funcs_list)
    unless functions.empty?
      texts << ''
      texts << 'Functions:'
      texts += print_object_refs(functions)
    end

    udfs_list = user_function_refs
    userfuncs = make_summary(udfs_list)
    unless userfuncs.empty?
      texts << ''
      texts << 'User-defined functions:'
      texts += print_object_refs(userfuncs)
      texts += print_unused(userfuncs)
    end

    vars_list = variables_refs
    variables = make_summary(vars_list)
    unless variables.empty?
      texts << ''
      texts << 'Variables:'
      texts += print_object_refs(variables)
      texts += print_unused(variables)
    end

    opers_list = operators_refs
    operators = make_summary(opers_list)
    unless operators.empty?
      texts << ''
      texts << 'Operators:'
      texts += print_object_refs(operators)
    end

    lines_list = linenums_refs
    linenums = make_summary(lines_list)
    unless linenums.empty?
      texts << ''
      texts << 'Line numbers:'
      texts += print_object_refs(linenums)
    end

    texts
  end

  private

  def parse_line(line)
    @statement_factory.parse(line)
  rescue BASICError => e
    @console_io.print_line("Syntax error: #{e.message}")
  end

  def check_line_duplicate(line_num, print_errors)
    # warn about duplicate lines when loading
    # but not when typing
    @console_io.print_line("Duplicate line number #{line_num}") if
      @lines.key?(line_num) && print_errors
  end

  def check_line_sequence(line_num, print_errors)
    # warn about lines out of sequence
    # but not when typing
    @console_io.print_line("Line #{line_num} is out of sequence") if
      !@lines.empty? &&
      line_num < @lines.max[0] &&
      print_errors
  end

  public

  def store_line(cmd, print_seq_errors, print_errors)
    line_num, line = parse_line(cmd)

    if !line_num.nil? && !line.nil?
      check_line_duplicate(line_num, print_seq_errors)
      check_line_sequence(line_num, print_seq_errors)
      @lines[line_num] = line
      statements = line.statements
      any_errors = false

      statements.each do |statement|
        statement.errors.each { |error| @console_io.print_line(error) } if
          print_errors

        any_errors |= !statement.errors.empty?
      end

      any_errors
    else
      true
    end
  end

  private

  def list_lines_errors(line_numbers, list_tokens)
    texts = []

    line_numbers.each do |line_number|
      line = @lines[line_number]

      # print the line
      texts << line_number.to_s + line.list

      line.warnings.each { |warning| texts << ' WARNING: ' + warning }

      statements = line.statements

      # print the errors
      statements.each do |statement|
        statement.errors.each { |error| texts << ' ' + error }
        statement.program_errors.each { |error| texts << ' ' + error }
      end

      # print the warnings
      statements.each do |statement|
        statement.warnings.each { |warning| texts << ' WARNING: ' + warning }
      end

      next unless list_tokens

      tokens = line.tokens
      text_tokens = tokens.map(&:to_s)

      texts << 'TOKENS: ' + text_tokens.to_s
    end

    texts
  end

  def parse_lines_errors(line_numbers)
    texts = []

    line_numbers.each do |line_number|
      line = @lines[line_number]

      # print the line
      texts << line_number.to_s + line.list

      line.warnings.each { |warning| texts << ' WARNING: ' + warning }

      statements = line.statements

      # print the errors
      statements.each do |statement|
        statement.errors.each { |error| texts << ' ' + error }
        statement.program_errors.each { |error| texts << ' ' + error }
      end

      # print the warnings
      statements.each do |statement|
        statement.warnings.each { |warning| texts << ' WARNING: ' + warning }
      end

      # print the line components
      statements.each do |statement|
        parses = statement.dump
        parses.each { |text| texts << ' ' + text }
      end
    end

    texts
  end

  def pretty_lines_errors(line_numbers, pretty_multiline)
    texts = []

    line_numbers.each do |line_number|
      line = @lines[line_number]

      # print the line
      number = line_number.to_s
      pretty_lines = line.pretty(pretty_multiline)

      pretty_lines.each do |pretty_line|
        texts << number + pretty_line
        number = ' ' * number.size
      end

      line.warnings.each { |warning| texts << ' WARNING: ' + warning }

      statements = line.statements

      # print the errors
      statements.each do |statement|
        statement.errors.each { |error| texts << ' ' + error }
        statement.program_errors.each { |error| texts << ' ' + error }
      end

      # print the warnings
      statements.each do |statement|
        statement.warnings.each { |warning| texts << ' WARNING: ' + warning }
      end
    end

    texts
  end

  def profile_lines_errors(line_numbers, show_timing)
    texts = []

    line_numbers.each do |line_number|
      line = @lines[line_number]

      number = line_number.to_s
      texts += line.profile(number, show_timing)
    end

    texts
  end

  def list_lines(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      text = line.list
      @console_io.print_line(line_number.to_s + text)
    end
  end

  def list_and_delete_lines(line_numbers)
    list_lines(line_numbers)
    print 'DELETE THESE LINES? '
    answer = @console_io.read_line
    delete_specific_lines(line_numbers) if answer == 'YES'
  end

  def delete_specific_lines(line_numbers)
    line_numbers.each { |line_number| @lines.delete(line_number) }
  end

  def enblank_specific_lines(line_numbers)
    line_numbers.each do |line_number|
      blank_line = line_number.to_s
      line_num, line = @statement_factory.parse(blank_line)
      @lines[line_num] = line
    end
  end
end
