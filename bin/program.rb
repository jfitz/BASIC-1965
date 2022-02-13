# frozen_string_literal: true

# Contain line numbers
class LineNumber
  attr_reader :line_number

  def initialize(line_number)
    legals = %(IntegerConstant NilClass)

    unless legals.include?(line_number.class.to_s)
      raise BASICSyntaxError,
            "Invalid line number object '#{line_number.class}'"
    end

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
    "#{self.class}:#{@line_number}"
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
  attr_reader :line_number, :statement

  def initialize(line_number, statement)
    raise BASICError, "line_number class is #{line_number.class}" unless
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

    "#{@line_number}.#{@statement}"
  end
end

# LineStmtMod class to hold line number and index within line
class LineStmtMod
  attr_reader :line_number, :statement, :index

  def initialize(line_number, statement, mod)
    raise BASICError, "line_number class is #{line_number.class}" unless
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
    return "#{@line_number}.#{@statement}" if @index.zero?

    "#{@line_number}.#{@statement}.#{@index}"
  end

  def get_counterpart
    other_mod = -@index
    LineStmtMod.new(@line_number, @statement, other_mod)
  end
end

# Line class to hold a line of code
class Line
  attr_reader :statements, :tokens, :warnings, :origins, :destinations

  def initialize(text, statements, tokens, comment)
    @text = text
    @statements = statements
    @tokens = tokens
    @comment = comment
    @warnings = []

    list_width_max = $options['warn_list_width'].value
    @warnings << "Line exceeds LIST width limit #{list_width_max}" if
      list_width_max.positive? && text.size > list_width_max

    pretty_width_max = $options['warn_pretty_width'].value
    pretty_lines = pretty(false)
    pretty_line = pretty_lines[0]
    @warnings << "Line exceeds PRETTY width limit #{pretty_width_max}" if
      pretty_width_max.positive? && pretty_line.size > pretty_width_max
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

  def set_transfers(user_function_start_lines)
    @statements.each do |statement|
      statement.set_transfers(user_function_start_lines)
    end
  end

  def set_transfers_auto(program, line_number)
    @statements.each_with_index do |statement, stmt|
      statement.set_transfers_auto(program, line_number, stmt)
    end
  end

  def clear_origins
    @statements.each { |statement| statement.origins = [] }
  end

  def add_statement_origin(stmt, xfer)
    statement = @statements[stmt]

    statement.origins << xfer unless statement.nil?
  end

  def transfers_to_origins(program, line_number)
    @statements.each_with_index do |statement, stmt|
      statement.transfers_to_origins(program, line_number, stmt)
    end
  end

  def set_reachable(stmt)
    any_changes = false

    statement = @statements[stmt]

    if !statement.nil? && !statement.reachable
      statement.reachable = true
      any_changes = true
    end

    any_changes
  end

  def check_statements(program, line_number)
    @statements.each_with_index do |statement, stmt|
      line_number_stmt = LineStmt.new(line_number, stmt)
      statement.check_gosub_origins(program, line_number_stmt)
      statement.check_onerror_origins(program, line_number_stmt)
    end
  end

  def check_program(program, line_number)
    @statements.each_with_index do |statement, stmt|
      line_number_stmt = LineStmt.new(line_number, stmt)
      statement.check_program(program, line_number_stmt)
    end
  end

  def number_valid_statements
    num = 0
    @statements.each { |statement| num += 1 if statement.valid }
    num
  end

  def number_exec_statements
    num = 0
    @statements.each { |statement| num += 1 if statement.executable == :run}
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
    pretty_lines = if multiline
                     AbstractToken.pretty_multiline([], @tokens)
                   else
                     [AbstractToken.pretty_tokens([], @tokens)]
                   end

    pl2 = []

    pretty_lines.each do |pretty_line|
      pretty_line = " #{pretty_line}" unless pretty_line.empty?
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
      errors.each { |error| texts << "#{number} ERROR: #{error}" }

      errors = statement.program_errors
      errors.each { |error| texts << "#{number} ERROR: #{error}" }

      warnings = statement.warnings
      warnings.each { |warning| texts << "#{number} WARNING: #{warning}" }

      warnings = statement.program_warnings
      warnings.each { |warning| texts << "#{number} WARNING: #{warning}" }
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
    text = " #{text}" unless text.empty?
    Line.new(text, @statements, tokens.flatten, @comment)
  end

  def build_destinations(line_number)
    @destinations = []

    @statements.each do |statement|
      xfers = statement.transfers + statement.transfers_auto

      # convert TransferRefLineStmt objects to TransferRefLine objects
      xfers.each do |xfer|
        # only transfers that have a different line number
        # we don't care about intra-line transfers
        @destinations << TransferRefLine.new(xfer.line_number, xfer.type) if
          xfer.line_number != line_number
      end
    end
  end

  def build_origins(line_number)
    @origins = []

    @statements.each do |statement|
      xfers = statement.origins

      # convert TransferRefLineStmt objects to TransferRefLine objects
      xfers.each do |xfer|
        # only transfers that have a different line number
        # we don't care about intra-line transfers
        @origins << TransferRefLine.new(xfer.line_number, xfer.type) if
          xfer.line_number != line_number
      end
    end
  end

  def line_stmts(line_number)
    dests = {}

    @statements.each_with_index do |statement, stmt|
      line_number_stmt = LineStmt.new(line_number, stmt)

      xfers = statement.transfers + statement.transfers_auto

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
  attr_reader :line_num, :assignment

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
      "#{@line_num}="
    else
      @line_num.to_s
    end
  end
end

# Contain line number ranges
# used in LIST and DELETE commands
class LineListSpec
  attr_reader :line_numbers, :range_type

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
  attr_reader :line_number, :statement, :type

  def initialize(line_number, statement, type)
    unless line_number.class.to_s == 'LineNumber'
      raise BASICError,
            "Invalid line number #{line_number.class}:#{line_number}"
    end

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
  attr_reader :line_number, :type

  def initialize(line_number, type)
    unless line_number.class.to_s == 'LineNumber'
      raise BASICError,
            "Invalid line number #{line_number.class}:#{line_number}"
    end

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
  attr_reader :lines, :first_line_number_stmt_mod

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
    @lines.each { |_line_number, line| line.uncache }
  end

  def empty?
    @lines.empty?
  end

  def errors
    texts = []

    @errors.each do |error|
      texts << "ERROR: #{error['message']} in line #{error['line']}"
    end

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        errors = statement.errors
        errors.each { |error| texts << ("ERROR: " + error + " in line #{line_number}") }

        errors = statement.program_errors
        errors.each { |error| texts << ("ERROR: " + error + " in line #{line_number}") }
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
      (statements[stmt].executable != :run ||
      statements[stmt].part_of_user_function != part_of_user_function)

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
        (statements[stmt].executable != :run ||
        statements[stmt].part_of_user_function != part_of_user_function)

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

  def find_next_exec_line_stmt_mod(current_line_stmt_mod)
    # find next index with current statement
    line_number = current_line_stmt_mod.line_number
    line = @lines[line_number]

    statements = line.statements
    stmt = current_line_stmt_mod.statement
    statement = statements[stmt]

    mod = current_line_stmt_mod.index

    if mod < statement.last_index
      mod += 1
      return LineStmtMod.new(line_number, stmt, mod)
    end

    return statement.autonext_line_stmt
  end

  def find_exec_line_stmt_mod(current_line_stmt_mod)
    # find next index with current statement
    line_number = current_line_stmt_mod.line_number
    line = @lines[line_number]

    statements = line.statements
    stmt = current_line_stmt_mod.statement
    statement = statements[stmt]

    if statement.executable == :run
      return current_line_stmt_mod
    end

    part_of_user_function = statement.part_of_user_function
    part_of_user_function = nil if statement.singledef?

    mod = current_line_stmt_mod.index

    # find next statement within the current line
    stmt += 1

    stmt += 1 while
      stmt < statements.size &&
      statements[stmt].part_of_user_function != part_of_user_function &&
      statements[stmt].executable != :run

    if stmt < statements.size
      start_mod = statements[stmt].start_index

      line_stmt_mod = LineStmtMod.new(line_number, stmt, start_mod)
      return line_stmt_mod
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

        line_stmt_mod = LineStmtMod.new(line_number, stmt, start_mod)
        return line_stmt_mod
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
        texts << "ERROR: #{error['message']} in line #{error['line']}"
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

    set_unreachable_code

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

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]

      # pretty-print the line with complexity statistics
      number = line_number.to_s

      texts += line.analyze_pretty(number)

      # print origins to this line
      line_origins = line.origins
      line_origins = [] if line_origins.nil?
      origs = line_origins.sort.uniq.map(&:to_s).join(', ')
      texts << ("  Origs: #{origs}")

      # print destinations from this line
      line_dests = line.destinations
      line_dests = [] if line_dests.nil?
      dests = line_dests.sort.uniq.map(&:to_s).join(', ')
      texts << ("  Dests: #{dests}")
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
    @lines.each { |_line_number, line| line.reset_profile_metrics }
  end

  def add_statement_origin(dest_line_number, dest_stmt, xfer)
    dest_line = @lines[dest_line_number]

    dest_line&.add_statement_origin(dest_stmt, xfer)
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
      next unless token.class.to_s == 'NumericConstantToken'

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

    raise(BASICCommandError, 'Invalid renumber step') if step.zero?

    [start, step]
  end

  def find_first_statement
    line_numbers = @lines.keys.sort
    index = 0
    line_number = line_numbers[index]
    part_of_user_function = nil

    until line_number.nil?
      line = @lines[line_number]

      statements = line.statements
      stmt = 0

      stmt += 1 while
        stmt < statements.size &&
        (statements[stmt].executable != :run ||
        statements[stmt].part_of_user_function != part_of_user_function)

      if stmt < statements.size
        start_mod = statements[stmt].start_index

        return LineStmtMod.new(line_number, stmt, start_mod)
      end

      index += 1
      line_number = line_numbers[index]
    end

    # no executable line found
    # try lines that are not executable
    
    index = 0
    line_number = line_numbers[index]
    part_of_user_function = nil

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

  def code_statistics
    lines = []

    lines << ("Number of lines: #{@lines.size}")
    lines << ("Number of valid statements: #{number_valid_statements}")
    lines << ("Number of comments: #{number_comments}")
    lines << ("Number of executable statements: #{number_exec_statements}")
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
    volume = length * Math.log(vocabulary) if vocabulary.positive?
    difficulty = 0
    difficulty = (n1.to_f / 2) * (nn2.to_f / n2) if n2.positive?
    effort = difficulty * volume
    language_level = 0
    language_level = volume / (difficulty**2) if difficulty.positive?
    intelligence = 0
    intelligence = volume / difficulty if difficulty.positive?
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
    @lines.each do |line_number, line|
      line.build_origins(line_number)
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

  def set_unreachable_code
    # assume statements are dead until connected to a live statement
    @lines.each { |_, line| line.reset_reachable }

    # first line is live
    first_line_number = @first_line_number_stmt_mod.line_number
    first_line = @lines[first_line_number]
    first_stmt = @first_line_number_stmt_mod.statement
    first_line.set_reachable(first_stmt)

    # walk the entire program and mark lines as live
    # repeat until no changes
    any_changes = true
    while any_changes
      any_changes = false

      @lines.each do |line_number, _line|
        statements = @lines[line_number].statements

        statements.each do |statement|
          # only reachable lines can reach other lines
          next unless statement.reachable

          # a reachable line updates its targets to 'reachable'
          xfers = statement.transfers + statement.transfers_auto

          xfers.each do |xfer|
            dest_line_number = xfer.line_number
            dest_line = @lines[dest_line_number]
            unless dest_line.nil?
              dest_stmt = xfer.statement
              any_changes |= dest_line.set_reachable(dest_stmt)
            end
          end
        end
      end
    end
  end

  def unreachable_code
    # build list of lines that are not reachable
    lines = []
    @lines.each do |line_number, line|
      statements = line.statements
      statements.each_with_index do |statement, stmt|
        next unless statement.executable == :run && !statement.reachable

        text = statement.pretty
        line_number_stmt = LineStmt.new(line_number, stmt)
        lines << "#{line_number_stmt}: #{text}" unless text.empty?
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
    density = num_comm.to_f / num_valid if num_valid.positive?
    lines << ("Comment density: #{'%.3f' % density}")

    lines << ("Comprehension effort: #{comprehension_effort}")

    lines << ("McCabe complexity: #{mccabe_complexity}")

    lines << 'Halstead complexity:'
    length, vocabulary, volume, difficulty, effort, language, intelligence, time = halstead
    lines << (" length: #{length}")
    lines << (" volume: #{'%.3f' % volume}")
    lines << (" difficulty: #{'%.3f' % difficulty}")
    lines << (" effort: #{'%.3f' % effort}")
    lines << (" language: #{'%.3f' % language}")
    lines << (" intelligence: #{'%.3f' % intelligence}")
    lines << (" time: #{'%.3f' % time}")
  end

  public

  def errors?
    any_errors = !@errors.empty?

    @lines.each do |_line_number, line|
      statements = line.statements
      statements.each { |statement| any_errors |= statement.errors? }
    end

    any_errors
  end

  def pessimize
    @errors = []

    line_numbers = @lines.keys.sort

    pessimize_statements(line_numbers)
  end

  def optimize(interpreter)
    line_numbers = @lines.keys.sort

    optimize_statements(interpreter, line_numbers)
    set_endfunc_lines(line_numbers)
    @user_function_start_lines = {}
    assign_singleline_function_markers(line_numbers)
    assign_multiline_function_markers(line_numbers)
    @first_line_number_stmt_mod = find_first_statement
    assign_autonext(line_numbers)
    set_transfers
    transfers_to_origins
    set_transfers_auto
    assign_sub_markers(line_numbers)
    assign_on_error_markers(line_numbers)
    assign_fornext_markers(line_numbers)
    check_lines(line_numbers)
    check_program(line_numbers)
    check_function_markers(line_numbers)
  end

  def pessimize_statements(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        line_number_stmt = LineStmt.new(line_number, stmt)
        statement.pessimize
      end
    end
  end

  def optimize_statements(interpreter, line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        line_stmt = LineStmt.new(line_number, stmt)
        statement.optimize(interpreter, line_stmt, self)
      end
    end
  end

  def set_endfunc_lines(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        line_stmt = LineStmt.new(line_number, stmt)
        statement.set_endfunc_lines(line_stmt, self)
      end
    end
  end

  def assign_sub_markers(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        statement.assign_sub_markers(self)
      end
    end
  end

  def assign_on_error_markers(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        statement.assign_on_error_markers(self)
      end
    end
  end

  def assign_fornext_markers(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        statement.assign_fornext_markers(self)
      end
    end
  end

  def get_statement(line_number, stmt)
    statement = nil

    line = @lines[line_number]

    unless line.nil?
      statements = line.statements
      statement = statements[stmt]
    end

    statement
  end

  def assign_singleline_function_markers(line_numbers)
    part_of_user_function = nil

    line_numbers.each do |line_number|
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

  def assign_multiline_function_markers(line_numbers)
    part_of_user_function = nil

    line_numbers.each do |line_number|
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

  def assign_autonext(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        statement.set_autonext_line_stmt(nil)

        next unless statement.autonext

        start_mod = statement.start_index
        line_stmt = LineStmt.new(line_number, stmt)

        # get statement at start of next line
        next_line_number_stmt_mod = find_next_line(line_stmt)

        statement.set_autonext_line(next_line_number_stmt_mod) unless
          next_line_number_stmt_mod.nil?

        # get next statement (may be on same line)
        next_line_stmt = find_next_line_stmt(line_stmt)

        next if next_line_stmt.nil?

        next_line_number = next_line_stmt.line_number
        next_stmt = next_line_stmt.statement
        next_line = @lines[next_line_number]

        next if next_line.nil?

        next_statements = next_line.statements

        next_statement = next_statements[next_stmt]

        next if next_statement.nil?

        next_mod = next_statement.start_index
        next_line_stmt_mod = LineStmtMod.new(next_line_number,
                                             next_stmt, next_mod)
        statement.set_autonext_line_stmt(next_line_stmt_mod)
      end
    end
  end

  def set_transfers
    @lines.each { |_, line| line.clear_origins }

    # add marker for entry point (first active line)
    line_number = @first_line_number_stmt_mod.line_number
    line = @lines[line_number]
    unless line.nil?
      empty_line_number = LineNumber.new(nil)
      xfer = TransferRefLine.new(empty_line_number, :start)
      stmt = 0
      line.add_statement_origin(stmt, xfer)
    end

    @lines.each do |_, line|
      line.set_transfers(@user_function_start_lines)
    end
  end

  def transfers_to_origins
    @lines.each do |line_number, line|
      line.transfers_to_origins(self, line_number)
    end
  end

  def set_transfers_auto
    @lines.each do |line_number, line|
      line.set_transfers_auto(self, line_number)
    end
  end

  def init_data(interpreter)
    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        if statement.executable == :def_fn
          line_number_stmt = LineStmt.new(line_number, stmt)
          # add trace output
          statement.print_trace_info(interpreter.trace_out, line_number_stmt)
          statement.define_user_functions(interpreter)
        end
      end
    end

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        if statement.executable == :load_data
          line_number_stmt = LineStmt.new(line_number, stmt)
          # add trace output
          statement.print_trace_info(interpreter.trace_out, line_number_stmt)
          statement.load_data(interpreter)
        end
      end
    end

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each_with_index do |statement, stmt|
        if statement.executable == :files
          line_number_stmt = LineStmt.new(line_number, stmt)
          # add trace output
          statement.print_trace_info(interpreter.trace_out, line_number_stmt)
          statement.load_file_names(interpreter)
        end
      end
    end
  end

  def check_lines(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      line.check_statements(self, line_number)
    end
  end

  def check_program(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      line.check_program(self, line_number)
    end
  end

  def check_function_markers(line_numbers)
    part_of_user_function = nil

    line_numbers.each do |line_number|
      line = @lines[line_number]
      statements = line.statements

      statements.each do |statement|
        if !part_of_user_function.nil? && statement.multidef?
          @errors <<
            {
              'message' => 'Missing FNEND before DEF',
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

        raise(BASICSyntaxError, "Cannot find NEXT for #{control}") if
          for_level.negative?

        if stmt_control == control ||
           (stmt_control.empty? && for_level.zero?)
          return LineStmt.new(line_number, stmt)
        end
      end

      walk_line_stmt = find_next_line_stmt(walk_line_stmt)
    end

    # if none found, error
    raise(BASICSyntaxError, "Cannot find NEXT for #{control}")
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
    raise BASICSyntaxError.new("No ENDFUNCTION for function #{name}")
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
      lines << (line_number.to_s + line.list)
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

      texts << ("#{token}:#{spaces}#{line_refs}")
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

        texts << ("#{token}:#{spaces}#{line_refs}")
      else
        n_spaces = 5
        spaces = ' ' * n_spaces

        texts << ("#{token}:")
        texts << (spaces + line_refs)
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
      texts << ("Assigned but not used: #{unused.join(', ')}")
    end

    unless unassigned.empty?
      texts << ''
      texts << ("Used but not assigned: #{unassigned.join(', ')}")
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
      texts << (line_number.to_s + line.list)

      line.warnings.each { |warning| texts << (" WARNING: #{warning}") }

      statements = line.statements

      # print the errors
      statements.each do |statement|
        statement.errors.each { |error| texts << (" ERROR: #{error}") }
        statement.program_errors.each { |error| texts << (" ERROR: #{error}") }
      end

      # print the warnings
      statements.each do |statement|
        statement.warnings.each { |warning| texts << (" WARNING: #{warning}") }
        statement.program_warnings.each { |warning| texts << (" WARNING: #{warning}") }
      end

      next unless list_tokens

      tokens = line.tokens
      text_tokens = tokens.map(&:to_s)

      texts << ("TOKENS: #{text_tokens}")
    end

    texts
  end

  def parse_lines_errors(line_numbers)
    texts = []

    line_numbers.each do |line_number|
      line = @lines[line_number]

      # print the line
      texts << (line_number.to_s + line.list)

      line.warnings.each { |warning| texts << (" WARNING: #{warning}") }

      statements = line.statements

      # print the errors
      statements.each do |statement|
        statement.errors.each { |error| texts << (" ERROR: #{error}") }
        statement.program_errors.each { |error| texts << (" ERROR: #{error}") }
      end

      # print the warnings
      statements.each do |statement|
        statement.warnings.each { |warning| texts << (" WARNING: #{warning}") }
        statement.program_warnings.each { |warning| texts << (" WARNING: #{warning}") }
      end

      # print the line components
      statements.each do |statement|
        parses = statement.dump
        parses.each { |text| texts << (" #{text}") }
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
        texts << (number + pretty_line)
        number = ' ' * number.size
      end

      line.warnings.each { |warning| texts << (" WARNING: #{warning}") }

      statements = line.statements

      # print the errors
      statements.each do |statement|
        statement.errors.each { |error| texts << (" ERROR: #{error}") }
        statement.program_errors.each { |error| texts << (" ERROR: #{error}") }
      end

      # print the warnings
      statements.each do |statement|
        statement.warnings.each { |warning| texts << (" WARNING: #{warning}") }
        statement.program_warnings.each { |warning| texts << (" WARNING: #{warning}") }
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
