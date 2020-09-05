# Contain line numbers
class LineNumber
  attr_reader :line_number

  def initialize(line_number)
    raise BASICSyntaxError, "Invalid line number object '#{line_number}:#{line_number}'" unless
      %w[NumericConstantToken NumericConstant].include?(line_number.class.to_s)

    @line_number = line_number.to_i

    raise BASICSyntaxError, "Invalid line number '#{@line_number}'" unless
      @line_number >= $options['min_line_num']
    
    raise BASICSyntaxError, "Invalid line number '#{@line_number}'" unless
      @line_number <= $options['max_line_num']
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

  def profile(show_profile)
    @statement.profile(show_profile)
  end

  def renumber(renumber_map)
    @statement.renumber(renumber_map)
    keywords = @statement.keywords
    tokens = @statement.tokens
    text = AbstractToken.pretty_tokens(keywords, tokens)
    Line.new(text, @statement, keywords + tokens, @comment)
  end

  def okay(program, console_io, line_number)
    @statement.okay(program, console_io, line_number)
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
  attr_reader :lines
  attr_reader :errors

  def initialize(console_io, tokenbuilders)
    @console_io = console_io
    @lines = {}
    @errors = []
    @statement_factory = StatementFactory.instance
    @statement_factory.tokenbuilders = tokenbuilders
  end

  def clear
    @lines = {}
  end

  def empty?
    @lines.empty?
  end

  def check
    @errors = check_program
  end

  def okay
    result = true

    @lines.keys.sort.each do |line_number|
      r = @lines[line_number].okay(self, @console_io, line_number)
      result &&= r
    end

    result
  end

  def find_next_line_number(line_number)
    line_numbers = @lines.keys.sort
    index = line_numbers.index(line_number)
    line_numbers[index + 1]
  end

  def line_number?(line_number)
    @lines.key?(line_number)
  end

  def first_line_number
    @lines.min[0]
  end

  private

  def check_program
    []
  end

  def line_list_spec(tokens)
    line_numbers = @lines.keys.sort
    LineListSpec.new(tokens, line_numbers)
  end

  def renumber_spec(tokens)
    start = 10
    step = 10

    i = 0
    tokens.each do |token|
      if token.class.to_s == 'NumericConstantToken'
        case i
        when 0
          # first number is step
          step = token.to_i
          start = token.to_i
          i += 1
        when 1
          # second number is start
          start = token.to_i
          i += 1
        end
      end
    end

    raise(BASICSyntaxError, 'Invalid renumber step') if step.zero?
    
    [start, step]
  end

  public

  def cmd_new
    @lines = {}
    @errors = check_program
    @console_io.newline
  end

  def list(args, list_tokens)
    line_number_range = line_list_spec(args)

    if !@lines.empty?
      line_numbers = line_number_range.line_numbers
      list_lines_errors(line_numbers, list_tokens)
      @errors.each { |error| @console_io.print_line(error) }
    else
      @console_io.print_line('No program loaded')
    end

    @console_io.newline
  end

  def parse(args)
    line_number_range = line_list_spec(args)

    if !@lines.empty?
      line_numbers = line_number_range.line_numbers
      parse_lines_errors(line_numbers)
    else
      @console_io.print_line('No program loaded')
    end

    @console_io.newline
  end

  def analyze
    if !@lines.empty?
      # report statistics
      @console_io.print_line('Statistics:')
      @console_io.newline
      lines = code_statistics
      lines.each { |line| @console_io.print_line(line) }
      @console_io.newline

      # report complexity
      @console_io.print_line('Complexity:')
      @console_io.newline
      lines = code_complexity
      lines.each { |line| @console_io.print_line(line) }
      @console_io.newline

      # report unreachable lines
      @console_io.print_line('Unreachable code:')
      @console_io.newline
      lines = unreachable_code
      lines.each { |line| @console_io.print_line(line) }
      @console_io.newline
    else
      @console_io.print_line('No program loaded')
    end

    @console_io.newline
  end

  def pretty(args)
    line_number_range = line_list_spec(args)

    if !@lines.empty?
      line_numbers = line_number_range.line_numbers
      pretty_lines_errors(line_numbers)
      @errors.each { |error| @console_io.print_line(error) }
    else
      @console_io.print_line('No program loaded')
    end

    @console_io.newline
  end

  def reset_profile_metrics
    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      statement.reset_profile_metrics
    end
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

    @lines.each do |_, line|
      statement = line.statement
      num += 1 if statement.valid
    end

    num
  end

  def number_exec_statements
    num = 0

    @lines.each do |_, line|
      statement = line.statement
      num += 1 if statement.executable
    end

    num
  end

  def number_comments
    num = 0

    @lines.each do |_, line|
      statement = line.statement
      num += 1 if statement.comment
    end

    num
  end

  def comprehension_effort
    num = 0

    @lines.each do |_, line|
      statement = line.statement
      num += statement.comprehension_effort
    end

    num
  end

  def mccabe_complexity
    num = 1

    @lines.each do |_, line|
      statement = line.statement
      num += statement.mccabe
    end

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
      statement = line.statement

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

  def unreachable_code
    # build list of "gotos"
    gotos = {}
    @lines.keys.each do |line_number|
      statement = @lines[line_number].statement
      statement_gotos = statement.gotos

      autonext = statement.autonext
      if autonext
        next_line_number = find_next_line_number(line_number)
        statement_gotos << next_line_number unless next_line_number.nil?
      end

      gotos[line_number] = statement_gotos
    end

    # assume statements are dead until connected to a live statement
    reachable = {}
    @lines.keys.each { |line_number| reachable[line_number] = false }

    # first line is live
    first_line_number = @lines.keys.min
    reachable[first_line_number] = true

    # walk the entire tree and mark lines as live
    # repeat until no changes
    any_changes = true
    while any_changes
      any_changes = false

      @lines.keys.each do |line_number|
        # only reachable lines can reach other lines
        next unless reachable[line_number]

        # a reachable line updates its targets to 'reachable'
        statement_gotos = gotos[line_number]
        statement_gotos.each do |goto_number|
          unless reachable[goto_number]
            reachable[goto_number] = true
            any_changes = true
          end
        end
      end
    end

    # build list of lines that are not reachable
    lines = []
    reachable.keys.each do |line_number|
      statement = @lines[line_number].statement
      lines << "#{line_number}:#{statement.pretty}" if
        statement.executable && !reachable[line_number]
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

  def preexecute_loop(interpreter)
    okay = true

    @lines.keys.sort.each do |line_number|
      @line_number = line_number
      line = @lines[line_number]
      statement = line.statement
      begin
        okay &=
          statement.preexecute_a_statement(line_number,
                                           interpreter,
                                           @console_io)
      rescue BASICPreexecuteError => e
        @console_io.print_line("Error #{e.code} #{e.message}")
        okay = false
      end
    end

    okay
  end

  def find_closing_next(control, current_line_number)
    # starting with @next_line_number
    line_numbers = @lines.keys.sort
    forward_line_numbers =
      line_numbers.select { |line_number| line_number > current_line_number }

    # find a NEXT statement with matching control variable
    forward_line_numbers.each do |line_number|
      line = @lines[line_number]
      statement = line.statement

      return line_number if
        statement.class.to_s == 'NextStatement' &&
        statement.control == control
    end

    # if none found, error
    raise(BASICSyntaxError, 'FOR without NEXT')
  end

  def profile(args, show_timing)
    line_number_range = line_list_spec(args)

    if @lines.empty?
      @console_io.print_line('No program loaded')
      return
    end

    line_numbers = line_number_range.line_numbers
    profile_lines_errors(line_numbers, show_timing)
  end

  private

  def save_file(filename)
    line_numbers = @lines.keys.sort

    begin
      File.open(filename, 'w') do |file|
        line_numbers.each do |line_num|
          line = @lines[line_num]
          file.puts line_num.to_s + line.list
        end
        file.close
      end
    rescue Errno::ENOENT
      @console_io.print_line("File '#{filename}' not opened")
    end
  end

  public

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

    if @lines.empty?
      @console_io.print_line('No program loaded')
      return false
    end

    save_file(filename)
  end

  def delete(args)
    line_number_range = line_list_spec(args)

    raise(BASICCommandError, 'No program loaded') if
      @lines.empty?

    raise(BASICCommandError, 'Type NEW to delete an entire program') if
      line_number_range.range_type == :all

    line_numbers = line_number_range.line_numbers
    delete_specific_lines(line_numbers)
    @errors = check_program
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
    start, step = renumber_spec(args)
    renumber_map = {}
    new_number = start

    @lines.keys.sort.each do |line_number|
      number_token = NumericConstantToken.new(new_number)
      new_line_number = LineNumber.new(number_token)
      renumber_map[line_number] = new_line_number
      new_number += step
    end

    # assign new line numbers
    new_lines = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      new_line_number = renumber_map[line_number]
      new_lines[new_line_number] = line.renumber(renumber_map)
    end

    @lines = new_lines
    @errors = check_program
    renumber_map
  end

  private

  def numeric_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.numerics
    end

    refs
  end

  def strings_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.strings
    end

    refs
  end

  def function_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.functions
    end

    refs
  end

  def user_function_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.userfuncs
    end

    refs
  end

  def variables_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.variables
    end

    refs
  end

  def operators_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.operators
    end

    refs
  end

  def linenums_refs
    refs = {}

    @lines.keys.sort.each do |line_number|
      line = @lines[line_number]
      statement = line.statement
      refs[line_number] = statement.linenums
    end

    refs
  end

  def print_numeric_refs(title, refs)
    @console_io.print_line(title)

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
      line_refs = lines.map(&:to_s).uniq.join(', ')
      line = token + ":" + spaces + line_refs

      @console_io.print_line(line)
    end

    @console_io.newline
  end

  def print_object_refs(title, refs)
    @console_io.print_line(title)

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
      line_refs = lines.map(&:to_s).uniq.join(', ')

      if token.size < 41
        n_spaces = num_spaces - token.size + 2
        spaces = ' ' * n_spaces
        line = token + ":" + spaces + line_refs
        @console_io.print_line(line)
      else
        n_spaces = 5
        spaces = ' ' * n_spaces

        line = token + ":"
        @console_io.print_line(line)

        line = spaces + line_refs
        @console_io.print_line(line)
      end
    end

    @console_io.newline
  end

  def print_unused(variables)
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
      @console_io.print_line('Assigned but not used: ' + unused.join(', '))
      @console_io.newline()
    end

    unless unassigned.empty?
      @console_io.print_line('Used but not assigned: ' + unassigned.join(', '))
      @console_io.newline()
    end
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
    @console_io.print_line('Cross reference')
    @console_io.newline

    nums_list = numeric_refs
    numerics = make_summary(nums_list)
    print_numeric_refs('Numeric constants:', numerics)

    strs_list = strings_refs
    strings = make_summary(strs_list)
    print_object_refs('String constants:', strings)

    funcs_list = function_refs
    functions = make_summary(funcs_list)
    print_object_refs('Functions:', functions)

    udfs_list = user_function_refs
    userfuncs = make_summary(udfs_list)
    print_object_refs('User-defined functions:', userfuncs)

    vars_list = variables_refs
    variables = make_summary(vars_list)
    print_object_refs('Variables:', variables)
    print_unused(variables)

    opers_list = operators_refs
    operators = make_summary(opers_list)
    print_object_refs('Operators:', operators)

    lines_list = linenums_refs
    linenums = make_summary(lines_list)
    print_object_refs('Line numbers:', linenums)
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
      @lines.key?(line_num) && !print_errors
  end

  def check_line_sequence(line_num, print_errors)
    # warn about lines out of sequence
    # but not when typing
    @console_io.print_line("Line #{line_num} is out of sequence") if
      !@lines.empty? &&
      line_num < @lines.max[0] &&
      !print_errors
  end

  public

  def store_line(cmd, print_errors)
    line_num, line = parse_line(cmd)

    if !line_num.nil? && !line.nil?
      check_line_duplicate(line_num, print_errors)
      check_line_sequence(line_num, print_errors)
      @lines[line_num] = line
      statement = line.statement
      statement.errors.each { |error| @console_io.print_line(error) } if
        print_errors

      !statement.errors.empty?
    else
      true
    end
  end

  private

  def list_lines_errors(line_numbers, list_tokens)
    line_numbers.each do |line_number|
      line = @lines[line_number]

      # print the line
      @console_io.print_line(line_number.to_s + line.list)

      # print the errors
      statement = line.statement
      statement.errors.each { |error| @console_io.print_line(' ' + error) }

      next unless list_tokens

      tokens = line.tokens
      text_tokens = tokens.map(&:to_s)
      @console_io.print_line('TOKENS: ' + text_tokens.to_s)
    end
  end

  def parse_lines_errors(line_numbers)
    line_numbers.each do |line_number|
      line = @lines[line_number]

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
      line = @lines[line_number]
      number = line_number.to_s

      # print the line
      pretty = line.pretty
      @console_io.print_line(number + pretty)

      # print the errors
      statement = line.statement
      statement.errors.each { |error| @console_io.print_line(' ' + error) }
    end
  end

  def profile_lines_errors(line_numbers, show_timing)
    line_numbers.each do |line_number|
      line = @lines[line_number]
      number = line_number.to_s

      # print the line
      profile = line.profile(show_timing)
      @console_io.print_line(number + profile)

      # print the errors
      statement = line.statement
      statement.errors.each { |error| @console_io.print_line(' ' + error) }
    end
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
