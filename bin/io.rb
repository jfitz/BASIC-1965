# Handle tab stops and carriage control
class ConsoleIo
  def initialize(max_width, zone_width, print_rate, implied_semicolon,
                 echo_input)
    @column = 0
    @max_width = max_width
    @zone_width = zone_width
    @print_rate = print_rate
    @implied_semicolon = implied_semicolon
    @last_was_numeric = false
    @echo_input = echo_input
  end

  def ascii_printables(text)
    ascii_text = ''
    text.each_char do |c|
      ascii_text += c if c >= ' ' && c <= '~'
    end
    ascii_text
  end

  def read_line
    input_text = ascii_printables(gets)
    puts(input_text) if @echo_input
    input_text
  end

  def print_item(text)
    text.each_char do |c|
      print_out(c)
      @column += 1
      newline if @column >= @max_width
    end
    @last_was_numeric = false
  end

  def last_was_numeric
    @last_was_numeric = true
  end

  def tab
    space_after_numeric if @last_was_numeric
    print_item(' ') while @column > 0 && @column % @zone_width != 0
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
    delay
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
    unless text.nil?
      text.each_char do |c|
        print(c)
        delay
      end
    end
  end

  def delay
    sleep(1.0 / @print_rate) if @print_rate > 0
  end
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
    raise BASICException, 'Out of data' if @data_index >= @data_store.size
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

  def set_mode(mode)
    if @mode.nil?
      case mode
      when :print
        @file = File.new(@file_name, 'wt')
      when :read
        @file = File.new(@file_name, 'rt')
      else
        raise(Exception, 'Invalid file mode')
      end
      @mode = mode
    else
      raise(BASICException, 'Inconsistent file operation') unless @mode == mode
    end
  end

  def close
    @file.close unless @file.nil?
  end

  def print_item(text)
    set_mode(:print)
    @file.print text
  end

  def last_was_numeric
    set_mode(:print)
  end

  def newline
    set_mode(:print)
    @file.puts
  end

  def implied_newline
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
    while @data_store.empty?
      line = @file.gets
      raise(BASICException, 'End of file') if line.nil?
      line = line.chomp

      tokenizers = []
      tokenizers << InputNumberTokenBuilder.new
      tokenizers << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)
      tokenizers << WhitespaceTokenBuilder.new

      tokenizer = Tokenizer.new(tokenizers, InvalidTokenBuilder.new)

      tokens = tokenizer.tokenize(line)
      tokens.delete_if { |token| token.separator? || token.whitespace? }
      tokens.each do |token|
        t = NumericConstant.new(token)
        @data_store << t
      end
    end
    @data_store.shift
  end
end
