# Common routines for readers
module Reader
  def ascii_printables(text)
    ascii_text = ''
    text.each_char do |c|
      ascii_text += c if c >= ' ' && c <= '~'
    end
    ascii_text
  end

  def make_tokenbuilders
    tokenbuilders = []
    tokenbuilders << InputNumberTokenBuilder.new
    tokenbuilders << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)
    tokenbuilders << WhitespaceTokenBuilder.new
  end

  def verify_tokens(tokens)
    evens = tokens.values_at(* tokens.each_index.select(&:even?))
    evens.each do |token|
      raise(BASICRuntimeError, 'Invalid input') unless token.numeric_constant?
    end

    odds = tokens.values_at(* tokens.each_index.select(&:odd?))
    odds.each do |token|
      raise(BASICRuntimeError, 'Invalid input') unless token.separator?
    end
  end
end

# Handle tab stops and carriage control
class ConsoleIo
  def initialize(output_flags)
    @max_width = output_flags['print_width']
    @zone_width = output_flags['zone_width']
    @print_rate = output_flags['speed']
    @newline_rate = output_flags['newline_speed']
    @implied_semicolon = output_flags['implied_semicolon']
    @default_prompt = output_flags['default_prompt']
    @echo_input = output_flags['echo']
    @qmark_after_prompt = output_flags['qmark_after_prompt']

    @column = 0
    @last_was_numeric = false
  end

  include Reader

  def read_line
    input_text = gets
    raise(BASICRuntimeError, 'End of file') if input_text.nil?
    ascii_text = ascii_printables(input_text)
    puts(ascii_text) if @echo_input
    ascii_text
  end

  def prompt(text)
    if text.nil?
      print @default_prompt.value
    else
      print text.value
      print @default_prompt.value if @qmark_after_prompt
    end
  end

  def input(interpreter)
    input_text = read_line

    tokenbuilders = make_tokenbuilders
    tokenizer = Tokenizer.new(tokenbuilders, nil)
    tokens = tokenizer.tokenize(input_text)

    # drop whitespace
    tokens.delete_if(&:whitespace?)

    # verify all even-index tokens are numeric
    # verify all odd-index tokens are separators
    verify_tokens(tokens)

    # convert from tokens to values
    expressions = ValueScalarExpression.new(tokens)
    expressions.evaluate(interpreter, false)
  end

  def print_item(text)
    text.each_char do |c|
      print_out(c)
      @column += 1
      newline if @max_width > 0 && @column >= @max_width
    end
    @last_was_numeric = false
  end

  def print_line(text)
    print_item(text)
    newline
  end

  def last_was_numeric
    @last_was_numeric = true
  end

  def tab
    space_after_numeric if @last_was_numeric
    if @zone_width > 0
      print_item(' ') while @column > 0 && @column % @zone_width != 0
    end
    @last_was_numeric = false
  end

  def semicolon
    if @last_was_numeric
      space_after_numeric
      print_item(' ') while @column % 3 != 0
    end
    @last_was_numeric = false
  end

  def implied
    semicolon if @implied_semicolon
    # nothing else otherwise
  end

  def trace_output(s)
    newline_when_needed
    print_out(s)
    newline
  end

  private

  def space_after_numeric
    count = 3
    while @column > 0 && count > 0
      print_item(' ')
      count -= 1
    end
  end

  public

  def newline
    puts
    newline_delay
    @column = 0
    @last_was_numeric = false
  end

  def newline_when_needed
    newline if @column > 0
  end

  def implied_newline
    @column = 0
  end

  def print_out(text)
    return if text.nil?

    text.each_char do |c|
      print(c)
      delay
    end
  end

  def delay
    sleep(1.0 / @print_rate) if @print_rate > 0
  end

  def newline_delay
    sleep(1.0 / @print_rate) if @print_rate > 0 && @newline_rate.zero?
    sleep(1.0 / @newline_rate) if @newline_rate > 0
  end
end

# Null output used when we are not tracing
class NullOut
  def print_item(_) end

  def print_line(_) end

  def last_was_numeric
    false
  end

  def tab; end

  def semicolon; end

  def implied; end

  def trace_output(_) end

  def newline; end

  def newline_when_needed; end

  def implied_newline; end

  def print_out(_) end

  def delay; end

  def newline_delay; end
end

# stores values from DATA statement
class DataStore
  def initialize
    @data_store = []
    @data_index = 0
  end

  def store(values)
    @data_store += values
  end

  def read
    raise BASICRuntimeError, 'Out of data' if @data_index >= @data_store.size
    @data_index += 1
    @data_store[@data_index - 1]
  end

  def reset
    @data_index = 0
  end
end

# reads values from file and writes values to file
class FileHandler
  def initialize(file_name)
    @file_name = file_name
    @mode = nil
    @file = nil
    @data_store = []
  end

  include Reader

  def set_mode(mode)
    if @mode.nil?
      case mode
      when :print
        @file = File.new(@file_name, 'wt')
      when :read
        @file = File.new(@file_name, 'rt')
      else
        raise(BASICRuntimeError, 'Invalid file mode')
      end
      @mode = mode
    else
      raise(BASICRuntimeError, 'Inconsistent file operation') unless @mode == mode
    end
  end

  def close
    @file.close unless @file.nil?
  end

  def to_s
    @file_name
  end

  def read_line
    input_text = @file.gets
    raise(BASICRuntimeError, 'End of file') if input_text.nil?
    input_text = input_text.chomp
    ascii_printables(input_text)
  end

  def input(interpreter)
    set_mode(:read)
    input_text = read_line

    tokenbuilders = make_tokenbuilders
    tokenizer = Tokenizer.new(tokenbuilders, nil)
    tokens = tokenizer.tokenize(input_text)

    # drop whitespace
    tokens.delete_if(&:whitespace?)

    # verify all even-index tokens are numeric
    # verify all odd-index tokens are separators
    verify_tokens(tokens)

    # convert from tokens to values
    expressions = ValueScalarExpression.new(tokens)
    expressions.evaluate(interpreter, false)
  end

  def print_item(text)
    set_mode(:print)
    @file.print text
  end

  def last_was_numeric
    # for a file, this function does nothing
    set_mode(:print)
  end

  def newline
    set_mode(:print)
    @file.puts
  end

  def implied_newline
    # for a file, this function does nothing
    set_mode(:print)
  end

  def tab
    set_mode(:print)
    @file.putc ' '
  end

  def semicolon
    set_mode(:print)
    @file.putc ' '
  end

  def implied
    set_mode(:print)
    @file.putc ' '
  end

  def read
    set_mode(:read)
    tokenbuilders = make_tokenbuilders
    tokenizer = Tokenizer.new(tokenbuilders, InvalidTokenBuilder.new)
    @data_store = refill(@data_store, @file, tokenizer)
    @data_store.shift
  end

  private

  def refill(data_store, file, tokenizer)
    while data_store.empty?
      line = file.gets
      raise(BASICRuntimeError, 'End of file') if line.nil?
      line = line.chomp

      tokens = tokenizer.tokenize(line)

      # drop whitespace and separators
      tokens.delete_if { |token| token.separator? || token.whitespace? }

      # convert to values
      converted = read_convert(tokens)

      data_store += converted
    end

    data_store
  end

  def read_convert(tokens)
    converted = []

    tokens.each do |token|
      t = NumericConstant.new(token)
      converted << t
    end

    converted
  end
end
