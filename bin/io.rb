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
      raise BASICRuntimeError.new('Invalid input', :te_inp_no_num_text) unless
        token.numeric_constant?
    end

    odds = tokens.values_at(* tokens.each_index.select(&:odd?))

    odds.each do |token|
      raise BASICRuntimeError.new('Invalid input', :te_exp_sep) unless token.separator?
    end
  end
end

# Common routines for input
module Inputter
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
    expressions = ValueExpression.new(tokens, :scalar)
    expressions.evaluate(interpreter)
  end
end

# Handle tab stops and carriage control
class ConsoleIo
  def initialize
    @column = 0
    @last_was_numeric = false
    @last_was_tab = false
  end

  include Reader
  include Inputter

  def read_line
    input_text = gets

    raise BASICRuntimeError.new('End of file', :te_eof) if input_text.nil?

    ascii_text = ascii_printables(input_text)

    puts(ascii_text) if $options['echo'].value

    ascii_text
  end

  def prompt(text, remaining)
    if text.nil?
      print_item("(#{remaining})") if
        $options['prompt_count'].value

      print_item($options['default_prompt'].value)
    else
      print_item(text.value)

      print_item("(#{remaining})") if
        $options['prompt_count'].value

      print_item($options['default_prompt'].value) if
        $options['qmark_after_prompt'].value
    end
  end

  def print_item(text)
    text.each_char do |c|
      print_out(c)
      @column += 1
      newline if $options['print_width'].value > 0 &&
                 @column >= $options['print_width'].value
    end

    @last_was_numeric = false
    @last_was_tab = false
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
    print_item(' ') if @last_was_tab

    zone_width = $options['zone_width'].value

    if zone_width > 0
      print_item(' ') while @column % zone_width != 0
    end

    @last_was_numeric = false
    @last_was_tab = true
  end

  def semicolon
    space_after_numeric if @last_was_numeric

    zone_width = $options['semicolon_zone_width'].value

    if zone_width > 0
      print_item(' ') while @column % zone_width != 0
    end

    @last_was_numeric = false
    @last_was_tab = false
  end

  def implied
    semicolon if $options['implied_semicolon'].value
    # nothing else otherwise
  end

  def trace_output(s)
    newline_when_needed
    print_out(s)
    newline
  end

  private

  def space_after_numeric
    count = 1

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
    @last_was_tab = true
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
    sleep(1.0 / $options['print_speed'].value) if
      $options['print_speed'].value > 0
  end

  def newline_delay
    sleep(1.0 / $options['print_speed'].value) if
      $options['print_speed'].value > 0 &&
      $options['newline_speed'].value.zero?

    sleep(1.0 / $options['newline_speed'].value) if
      $options['newline_speed'].value > 0
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
    raise BASICRuntimeError.new('Out of data', :te_out_of_data) if
      @data_index >= @data_store.size

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
    raise BASICRuntimeError.new('No file name', :te_fname_no) if file_name.nil?

    @file_name = file_name
    @mode = nil
    @file = nil
    @data_store = []
  end

  include Reader
  include Inputter

  def set_mode(mode)
    if @mode.nil?
      case mode
      when :print
        @file = File.new(@file_name, 'wt')
      when :read
        @file = File.new(@file_name, 'rt')
      else
        raise BASICRuntimeError.new('Invalid file mode', :te_mode_inv)
      end

      @mode = mode
    else
      raise BASICRuntimeError.new('Inconsistent file operation', :te_op_inc) unless
        @mode == mode
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

    raise BASICRuntimeError.new('End of file', :te_eof) if input_text.nil?

    input_text = input_text.chomp
    ascii_printables(input_text)
  end

  def print_item(text)
    set_mode(:print)
    @file.print text
  end

  def last_was_numeric
    set_mode(:print)
    # for a file, this function does nothing
  end

  def newline
    set_mode(:print)
    @file.puts
  end

  def implied_newline
    set_mode(:print)
    # for a file, this function does nothing
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

      raise BASICRuntimeError.new('End of file', :te_eof) if line.nil?

      line = line.chomp

      tokens = tokenizer.tokenize(line)
      tokens.delete_if { |token| token.separator? || token.whitespace? }

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
