# frozen_string_literal: true

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
    tokenbuilders << InputNumberTokenBuilder.new(true, [])
    tokenbuilders << ListTokenBuilder.new(true, [], [',', ';'], ParamSeparatorToken)
    tokenbuilders << WhitespaceTokenBuilder.new(true, [])
  end

  def insert_empty_string(tokens)
    new_tokens = []

    prev_was_sep = true

    tokens.each do |token|
      # if previous item was a separator, add a blank value
      if token.separator? && prev_was_sep
        new_tokens << NumericLiteralToken.new('0')
      end

      prev_was_sep = token.separator?

      new_tokens << token
    end

    # if last item was a separator, add a blank value
    if prev_was_sep && !new_tokens.empty?
      new_tokens << NumericLiteralToken.new('0')
    end

    new_tokens
  end

  def verify_tokens(tokens)
    state = :want_value
    tokens.each do |token|
      case state
      when :want_value
        raise BASICRuntimeError.new(:te_inp_no_num_text, token.to_s) unless
          token.numeric_constant?

        state = :want_sep
      when :want_sep
        raise BASICRuntimeError.new(:te_exp_sep, token.to_s) unless
          token.separator?

        state = :want_value
      end
    end
  end
end

# Common routines for input
module Inputter
  def input(interpreter)
    line = read_line

    tokenbuilders = make_tokenbuilders
    invalid_tokenbuilder = InvalidTokenBuilder.new(true, [])
    tokenizer = Tokenizer.new(tokenbuilders, invalid_tokenbuilder)
    tokens = tokenizer.tokenize_line(line)

    # drop whitespace
    tokens.delete_if(&:whitespace?)

    # insert empty string tokens between separator tokens
    tokens = insert_empty_string(tokens)

    # verify values between separators
    verify_tokens(tokens)

    # convert from tokens to values
    expressions = ValueExpressionSet.new(tokens, :scalar)
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

    raise BASICRuntimeError, :te_eof if input_text.nil?

    ascii_text = ascii_printables(input_text)

    puts(ascii_text) unless STDIN.tty?

    ascii_text
  end

  def prompt(text, remaining)
    if text.nil?
      print_item("(#{remaining})") if $options['prompt_count'].value

      print_item($options['default_prompt'].value)
    else
      print_item(text.value)

      print_item("(#{remaining})") if $options['prompt_count'].value

      print_item($options['default_prompt'].value) if
        $options['qmark_after_prompt'].value
    end
  end

  def print_item(text)
    text.each_char do |c|
      print_out(c)
      @column += 1

      newline if $options['print_width'].value.positive? &&
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

    print_item(' ') while @column % zone_width != 0 if zone_width.positive?

    @last_was_numeric = false
    @last_was_tab = true
  end

  def semicolon
    space_after_numeric if @last_was_numeric

    zone_width = $options['semicolon_zone_width'].value

    print_item(' ') while @column % zone_width != 0 if zone_width.positive?

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

    while @column.positive? && count.positive?
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
    newline if @column.positive?
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
      $options['print_speed'].value.positive?
  end

  def newline_delay
    sleep(1.0 / $options['print_speed'].value) if
      $options['print_speed'].value.positive? &&
      $options['newline_speed'].value.zero?

    sleep(1.0 / $options['newline_speed'].value) if
      $options['newline_speed'].value.positive?
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
    raise BASICRuntimeError, :te_out_of_data if
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
    raise BASICRuntimeError, :te_fname_no if file_name.nil?

    @file_name = file_name
    @mode = nil
    @file = nil
    @data_store = []
    @record = ''
    @records = []
    @rec_number = -1
  end

  include Reader
  include Inputter

  def set_mode(mode)
    if @mode.nil?
      case mode
      when :print
        @record = ''
        @records = []
        @rec_number = 0
      when :read
        @record = ''
        @records = read_file(@file_name)
        @rec_number = 0
      else
        raise BASICRuntimeError, :te_mode_inv
      end

      @mode = mode
    else
      raise BASICRuntimeError, :te_op_inc unless @mode == mode
    end
  end

  def close
    if @mode == :memory || @mode == :print
      unless @record.empty?
        @records << '' while @records.size <= @rec_number
        @records[@rec_number] = @record
        @record = ''
      end

      write_file(@file_name, @records)
      @records = []
      @rec_number = -1
    end

    @file&.close
  end

  def to_s
    @file_name
  end

  def read_line
    raise BASICRuntimeError, :te_eof if @rec_number >= @records.size

    input_text = @records[@rec_number]
    @rec_number += 1
    ascii_printables(input_text)
  end

  def print_item(text)
    set_mode(:print)

    @record += text
  end

  def last_was_numeric
    set_mode(:print)

    # for a file, this function does nothing
  end

  def newline
    set_mode(:print)

    @records << '' while @records.size <= @rec_number
    @records[@rec_number] = @record
    @record = ''
    @rec_number += 1
  end

  def implied_newline
    set_mode(:print)

    # for a file, this function does nothing
  end

  def tab
    set_mode(:print)

    @record += ' '
  end

  def semicolon
    set_mode(:print)

    @record += ' '
  end

  def implied
    set_mode(:print)

    @record += ' '
  end

  def read
    set_mode(:read)

    tokenbuilders = make_tokenbuilders
    invalid_tokenbuilder = InvalidTokenBuilder.new(true, [])
    tokenizer = Tokenizer.new(tokenbuilders, invalid_tokenbuilder)
    @data_store = refill(@data_store, tokenizer)
    @data_store.shift
  end

  private

  def refill(data_store, tokenizer)
    while data_store.empty?
      raise BASICRuntimeError, :te_eof if @rec_number >= @records.size

      line = @records[@rec_number]
      @rec_number += 1

      line = line.strip

      tokens = tokenizer.tokenize_line(line)
      tokens.delete_if { |token| token.whitespace? }

      # insert empty string tokens between separator tokens
      tokens = insert_empty_string(tokens)

      tokens.delete_if { |token| token.separator? }

      elements = read_convert(tokens)

      data_store += elements
    end

    data_store
  end

  def read_convert(tokens)
    elements = []

    tokens.each do |token|
      elements << NumericValue.new(token) if token.numeric_constant?
    end

    elements
  end

  def read_file(file_name)
    lines = []
    file = File.open(file_name, 'rt')
    file.each_line { |line| lines << line.strip }
    file.close
  rescue Exception
    raise BASICRuntimeError.new(:te_file_no_read, file_name)
  else
    lines
  end

  def write_file(file_name, lines)
    file = File.open(file_name, 'wt')
    lines.each { |line| file.puts(line) }
    file.close
  rescue Exception
    raise BASICRuntimeError.new(:te_file_no_write, file_name)
  end
end
