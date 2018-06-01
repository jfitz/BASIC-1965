# Contain line numbers
class LineNumber
  attr_reader :line_number

  def initialize(line_number)
    raise BASICError, "Invalid line number '#{line_number}'" unless
      line_number.class.to_s == 'NumericConstantToken'
    @line_number = line_number.to_i
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
    @line_number <=> other.line_number
  end

  def >(other)
    @line_number > other.line_number
  end

  def >=(other)
    @line_number >= other.line_number
  end

  def <(other)
    @line_number < other.line_number
  end

  def <=(other)
    @line_number <= other.line_number
  end

  def dump
    self.class.to_s + ':' + @line_number.to_s
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

# Line class to hold a line of code
class Line
  attr_reader :statement
  attr_reader :tokens

  def initialize(text, statement, tokens, comment)
    @text = text
    @statement = statement
    @tokens = tokens
    @comment = comment
  end

  def list
    @text
  end

  def pretty
    text = AbstractToken.pretty_tokens([], @tokens)

    unless @comment.nil?
      space = @text.size - (text.size + @comment.to_s.size)
      space = 5 if space < 5
      text += ' ' * space
      text += @comment.to_s
    end

    text
  end

  def parse
    texts = []
    @statements.each { |statement| texts << statement.dump }
  end

  def profile
    @statement.profile
  end

  def renumber(renumber_map)
    @statement.renumber(renumber_map)
    keywords = @statement.keywords
    tokens = @statement.tokens
    text = AbstractToken.pretty_tokens(keywords, tokens)
    Line.new(text, @statement, keywords + tokens, @comment)
  end

  def check(program, console_io, line_number)
    @statement.program_check(program, console_io, line_number)
  end
end

# line reference for cross reference
class LineRef
  def initialize(line_num, assignment)
    @line_num = line_num
    @assignment = assignment
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
    line_number = LineNumber.new(token)
    @line_numbers << line_number if
      program_line_numbers.include?(line_number)
    @range_type = :single
  end

  def make_range(tokens, program_line_numbers)
    start = LineNumber.new(tokens[0])
    endline = LineNumber.new(tokens[2])
    range = LineNumberRange.new(start, endline, program_line_numbers)
    @line_numbers = range.list
    @range_type = :range
  end

  def make_count_range(tokens, program_line_numbers)
    start = LineNumber.new(tokens[0])
    count = 20
    count = NumericConstant.new(tokens[2]).to_i if tokens.size > 2
    range = LineNumberCountRange.new(start, count, program_line_numbers)
    @line_numbers = range.list
    @range_type = :range
  end
end

# program container
class Program
  def initialize(console_io, tokenbuilders)
    @console_io = console_io
    @program_lines = {}
    @statement_factory = StatementFactory.instance
    @statement_factory.tokenbuilders = tokenbuilders
  end

  def empty?
    @program_lines.empty?
  end

  def line_number?(line_number)
    @program_lines.key?(line_number)
  end

  def lines
    @program_lines
  end

  def cmd_new
    @program_lines = {}
  end

  def line_list_spec(tokens)
    line_numbers = @program_lines.keys.sort
    LineListSpec.new(tokens, line_numbers)
  end

  def list(line_number_range, list_tokens)
    if !@program_lines.empty?
      line_numbers = line_number_range.line_numbers
      list_lines_errors(line_numbers, list_tokens)
    else
      @console_io.print_line('No program loaded')
    end
  end

  def parse(line_number_range)
    if !@program_lines.empty?
      line_numbers = line_number_range.line_numbers
      parse_lines_errors(line_numbers)
    else
      @console_io.print_line('No program loaded')
    end
  end

  def pretty(line_number_range)
    if !@program_lines.empty?
      line_numbers = line_number_range.line_numbers
      pretty_lines_errors(line_numbers)
    else
      @console_io.print_line('No program loaded')
    end
  end

  def profile(line_number_range)
    if !@program_lines.empty?
      line_numbers = line_number_range.line_numbers
      profile_lines_errors(line_numbers)
    else
      @console_io.print_line('No program loaded')
    end
  end

  def load(tokens)
    if tokens.empty?
      @console_io.print_line('Filename not specified')
      return false
    end

    if tokens.size > 1
      @console_io.print_line('Too many items specified')
      return false
    end

    token = tokens[0]

    unless token.text_constant?
      @console_io.print_line('File name must be quoted literal')
      return false
    end

    filename = token.value.strip
    if filename.empty?
      @console_io.print_line('Filename not specified')
      return false
    end

    load_file(filename)
  end

  def load_file(filename)
    File.open(filename, 'r') do |file|
      @program_lines = {}
      file.each_line do |line|
        line = @console_io.ascii_printables(line)
        store_program_line(line, false)
      end
      true
    end
  rescue Errno::ENOENT
    @console_io.print_line("File '#{filename}' not found")
    false
  end

  def save(tokens)
    if tokens.empty?
      @console_io.print_line('Filename not specified')
      return false
    end

    if tokens.size > 1
      @console_io.print_line('Too many items specified')
      return false
    end

    token = tokens[0]

    unless token.text_constant?
      @console_io.print_line('File name must be text')
      return false
    end

    filename = token.value.strip
    if filename.empty?
      @console_io.print_line('Filename not specified')
      return false
    end

    if @program_lines.empty?
      @console_io.print_line('No program loaded')
      return false
    end

    save_file(filename)
  end

  def save_file(filename)
    line_numbers = @program_lines.keys.sort
    begin
      File.open(filename, 'w') do |file|
        line_numbers.each do |line_num|
          line = @program_lines[line_num]
          file.puts line_num.to_s + ' ' + line.list
        end
        file.close
      end
    rescue Errno::ENOENT
      @console_io.print_line("File '#{filename}' not opened")
    end
  end

  def print_profile
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      number = line_number.to_s
      profile = line.profile
      text = number + profile
      puts text
    end
  end

  def delete(line_number_range)
    raise(BASICCommandError, 'No program loaded') if
      @program_lines.empty?

    raise(BASICCommandError, 'Type NEW to delete an entire program') if
      line_number_range.range_type == :all

    line_numbers = line_number_range.line_numbers
    delete_specific_lines(line_numbers)
  end

  def enblank(line_number_range)
    raise(BASICCommandError, 'No program loaded') if
      @program_lines.empty?

    raise(BASICCommandError, 'You cannot delete an entire program') if
      line_number_range.range_type == :all

    line_numbers = line_number_range.line_numbers
    enblank_specific_lines(line_numbers)
  end

  # generate new line numbers
  def renumber
    renumber_map = {}
    new_number = 10
    @program_lines.keys.sort.each do |line_number|
      number_token = NumericConstantToken.new(new_number)
      new_line_number = LineNumber.new(number_token)
      renumber_map[line_number] = new_line_number
      new_number += 10
    end
    # assign new line numbers
    new_program_lines = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      new_line_number = renumber_map[line_number]
      new_program_lines[new_line_number] = line.renumber(renumber_map)
    end

    @program_lines = new_program_lines
    renumber_map
  end

  def numeric_refs
    refs = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement

      num_refs = statement.numerics
      refs[line_number] = num_refs
    end
    refs
  end

  def strings_refs
    refs = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement

      strs = statement.strings
      refs[line_number] = strs
    end
    refs
  end

  def function_refs
    refs = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement

      funcs = statement.functions
      refs[line_number] = funcs
    end
    refs
  end

  def user_function_refs
    refs = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement

      udfs = statement.userfuncs
      refs[line_number] = udfs
    end
    refs
  end

  def variables_refs
    refs = {}
    @program_lines.keys.sort.each do |line_number|
      line = @program_lines[line_number]
      statement = line.statement

      vars = statement.variables
      refs[line_number] = vars
    end
    refs
  end

  def print_refs(title, refs)
    puts title
    refs.keys.sort.each do |ref|
      lines = refs[ref]
      puts ref + ":\t" + lines.map(&:to_s).uniq.join(', ')
    end
    puts ''
  end

  def print_num_refs(title, refs)
    puts title
    refs.keys.sort.each do |ref|
      lines = refs[ref]
      puts ref.to_s + ":\t" + lines.map(&:to_s).uniq.join(', ')
    end
    puts ''
  end

  # generate cross-reference list
  def crossref
    puts 'Cross reference'
    puts ''

    nums_list = numeric_refs
    numerics = make_summary(nums_list)
    print_num_refs('Numeric constants', numerics)

    strs_list = strings_refs
    strings = make_summary(strs_list)
    print_num_refs('String constants', strings)

    funcs_list = function_refs
    functions = make_summary(funcs_list)
    print_refs('Functions', functions)

    udfs_list = user_function_refs
    userfuncs = make_summary(udfs_list)
    print_refs('User-defined functions', userfuncs)

    vars_list = variables_refs
    variables = make_summary(vars_list)
    print_refs('Variables', variables)
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

  def store_program_line(cmd, print_errors)
    line_num, line = parse_line(cmd)
    if !line_num.nil? && !line.nil?
      check_line_duplicate(line_num, print_errors)
      check_line_sequence(line_num, print_errors)
      @program_lines[line_num] = line
      statement = line.statement
      statement.errors.each { |error| puts error } if print_errors
      !statement.errors.empty?
    else
      true
    end
  end

  def parse_line(line)
    @statement_factory.parse(line)
  rescue BASICError => e
    @console_io.print_line("Syntax error: #{e.message}")
  end

  def check_line_duplicate(line_num, print_errors)
    # warn about duplicate lines when loading
    # but not when typing
    @console_io.print_line("Duplicate line number #{line_num}") if
      @program_lines.key?(line_num) && !print_errors
  end

  def check_line_sequence(line_num, print_errors)
    # warn about lines out of sequence
    # but not when typing
    @console_io.print_line("Line #{line_num} is out of sequence") if
      !@program_lines.empty? &&
      line_num < @program_lines.max[0] &&
      !print_errors
  end

  def list_lines_errors(line_numbers, list_tokens)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]

      # print the line
      @console_io.print_line(line_number.to_s + line.list)

      # print the errors
      statement = line.statement
      statement.errors.each { |error| puts ' ' + error }

      next unless list_tokens

      tokens = line.tokens
      text_tokens = tokens.map(&:to_s)
      @console_io.print_line('TOKENS: ' + text_tokens.to_s)
    end
  end

  def parse_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]

      # print the line
      @console_io.print_line(line_number.to_s + line.list)
      statement = line.statement

      # print the errors
      statement.errors.each { |error| @console_io.print_line(' ' + error) }

      # print the line components
      texts = statement.dump
      texts.each { |text| @console_io.print_line(' ' + text) }
    end
  end

  def pretty_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      number = line_number.to_s
      pretty = line.pretty
      @console_io.print_line(number + pretty)
      statement = line.statement
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def profile_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      number = line_number.to_s
      profile = line.profile
      @console_io.print_line(number + profile)
      statement = line.statement
      statement.errors.each { |error| puts ' ' + error }
    end
  end

  def list_lines(line_numbers)
    line_numbers.each do |line_number|
      line = @program_lines[line_number]
      text = line.list
      @console_io.print_line(line_number.to_s + text)
    end
  end

  def delete_specific_lines(line_numbers)
    line_numbers.each { |line_number| @program_lines.delete(line_number) }
  end

  def enblank_specific_lines(line_numbers)
    line_numbers.each do |line_number|
      blank_line = line_number.to_s
      line_num, line = @statement_factory.parse(blank_line)
      @program_lines[line_num] = line
    end
  end

  def list_and_delete_lines(line_numbers)
    list_lines(line_numbers)
    print 'DELETE THESE LINES? '
    answer = @console_io.read_line
    delete_specific_lines(line_numbers) if answer == 'YES'
  end

  def check
    result = true
    @program_lines.keys.sort.each do |line_number|
      r = @program_lines[line_number].check(self, @console_io, line_number)
      result &&= r
    end
    result
  end

  def find_next_line_number(line_number)
    line_numbers = @program_lines.keys.sort
    index = line_numbers.index(line_number)
    line_numbers[index + 1]
  end
end
