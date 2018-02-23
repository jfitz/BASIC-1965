#!/usr/bin/ruby

require 'benchmark'
require 'optparse'
require 'singleton'

require_relative 'exceptions'
require_relative 'tokens'
require_relative 'tokenbuilders'
require_relative 'tokenizers'
require_relative 'constants'
require_relative 'operators'
require_relative 'functions'
require_relative 'expressions'
require_relative 'io'
require_relative 'statements'
require_relative 'interpreter'
require_relative 'program'

# Contain line numbers
class LineNumber
  attr_reader :line_number

  def self.init?(text)
    /\A\d+\z/.match(text)
  end

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

# interactive shell
class Shell
  def initialize(console_io, interpreter, program)
    @console_io = console_io
    @interpreter = interpreter
    @program = program
    @tokenbuilders = make_command_tokenbuilders
  end

  def run
    need_prompt = true
    @done = false
    until @done
      @console_io.print_line('READY') if need_prompt
      cmd = @console_io.read_line
      need_prompt = process_line(cmd)
    end
  end

  private

  def process_line(cmd)
    if /\A\d/ =~ cmd
      # starts with a number, so maybe it is a program line
      need_prompt = @program.store_program_line(cmd, true)
    else
      # immediate command -- execute
      # tokenize
      invalid_tokenbuilder = InvalidTokenBuilder.new
      tokenizer = Tokenizer.new(@tokenbuilders, invalid_tokenbuilder)
      tokens = tokenizer.tokenize(cmd)
      tokens.delete_if(&:whitespace?)

      if tokens.empty?
        need_prompt = false
      else
        need_prompt = true
        process_command(tokens)
      end
    end
    need_prompt
  end

  def process_command(tokens)
    keyword = tokens[0]
    args = tokens[1..-1]

    if keyword.keyword?
      execute_command(keyword, args)
    else
      print "Unknown command '#{keyword}'\n"
    end
  end

  def execute_command(keyword, args)
    case keyword.to_s
    when 'EXIT'
      @done = true
    when 'NEW'
      @program.cmd_new
      @interpreter.clear_variables
      @interpreter.clear_breakpoints
    when 'RUN'
      @interpreter.run(@program, false, true, false) if @program.check
    when 'BREAK'
      @interpreter.set_breakpoints(args)
    when 'TRACE'
      @interpreter.run(@program, true, false, false) if @program.check
    when '.VARS'
      @interpreter.dump_vars
    when '.UDFS'
      @interpreter.dump_user_functions
    when '.DIMS'
      @interpreter.dump_dims
    when 'LOAD'
      @interpreter.clear_breakpoints
      @program.load(args)
    when 'SAVE'
      @program.save(args)
    when 'LIST'
      line_number_range = @program.line_list_spec(args)
      @program.list(line_number_range, false)
    when 'TOKENS'
      line_number_range = @program.line_list_spec(args)
      @program.list(line_number_range, true)
    when 'PRETTY'
      line_number_range = @program.line_list_spec(args)
      @program.pretty(line_number_range)
    when 'DELETE'
      line_number_range = @program.line_list_spec(args)
      @program.delete(line_number_range)
    when 'PROFILE'
      line_number_range = @program.line_list_spec(args)
      @program.profile(line_number_range)
    when 'RENUMBER'
      if @program.check
        renumber_map = @program.renumber
        @interpreter.renumber_breakpoints(renumber_map)
      end
    when 'CROSSREF'
      @program.crossref if @program.check
    else
      print "Unknown command #{keyword}\n"
    end
  rescue BASICCommandError => e
    @console_io.print_line(e.to_s)
  end
end

def make_interpreter_tokenbuilders
  tokenbuilders = []

  tokenbuilders << CommentTokenBuilder.new
  tokenbuilders << RemarkTokenBuilder.new

  statement_factory = StatementFactory.instance
  keywords = statement_factory.keywords_definitions
  tokenbuilders << ListTokenBuilder.new(keywords, KeywordToken)

  un_ops = UnaryOperator.operators
  bi_ops = BinaryOperator.operators
  operators = (un_ops + bi_ops).uniq
  tokenbuilders << ListTokenBuilder.new(operators, OperatorToken)

  tokenbuilders << BreakTokenBuilder.new

  tokenbuilders << ListTokenBuilder.new(['(', '['], GroupStartToken)
  tokenbuilders << ListTokenBuilder.new([')', ']'], GroupEndToken)
  tokenbuilders << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)

  tokenbuilders <<
    ListTokenBuilder.new(FunctionFactory.function_names, FunctionToken)

  function_names = ('FNA'..'FNZ').to_a
  tokenbuilders << ListTokenBuilder.new(function_names, UserFunctionToken)

  tokenbuilders << TextTokenBuilder.new
  tokenbuilders << NumberTokenBuilder.new
  tokenbuilders << VariableTokenBuilder.new
  tokenbuilders << ListTokenBuilder.new(%w(TRUE FALSE), BooleanConstantToken)
  tokenbuilders << WhitespaceTokenBuilder.new
end

def make_command_tokenbuilders
  tokenbuilders = []

  keywords = %w(
    BREAK CROSSREF DELETE EXIT LIST LOAD NEW PRETTY PROFILE RENUMBER RUN SAVE
    TOKENS TRACE .DIMS .UDFS .VARS
  )
  tokenbuilders << ListTokenBuilder.new(keywords, KeywordToken)

  un_ops = UnaryOperator.operators
  bi_ops = BinaryOperator.operators
  operators = (un_ops + bi_ops).uniq
  tokenbuilders << ListTokenBuilder.new(operators, OperatorToken)

  tokenbuilders << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)

  tokenbuilders << TextTokenBuilder.new
  tokenbuilders << NumberTokenBuilder.new

  tokenbuilders << WhitespaceTokenBuilder.new
end

options = {}
OptionParser.new do |opt|
  opt.on('-l', '--list SOURCE') { |o| options[:list_name] = o }
  opt.on('--tokens') { |o| options[:tokens] = o }
  opt.on('-p', '--pretty SOURCE') { |o| options[:pretty_name] = o }
  opt.on('-r', '--run SOURCE') { |o| options[:run_name] = o }
  opt.on('-c', '--crossref SOURCE') { |o| options[:cref_name] = o }
  opt.on('--profile') { |o| options[:profile] = o }
  opt.on('--no-heading') { |o| options[:no_heading] = o }
  opt.on('--echo-input') { |o| options[:echo_input] = o }
  opt.on('--trace') { |o| options[:trace] = o }
  opt.on('--no-timing') { |o| options[:no_timing] = o }
  opt.on('--tty') { |o| options[:tty] = o }
  opt.on('--tty-lf') { |o| options[:tty_lf] = o }
  opt.on('--print-width WIDTH') { |o| options[:print_width] = o }
  opt.on('--zone-width WIDTH') { |o| options[:zone_width] = o }
  opt.on('--int-floor') { |o| options[:int_floor] = o }
  opt.on('--ignore-rnd-arg') { |o| options[:ignore_rnd_arg] = o }
  opt.on('--implied-semicolon') { |o| options[:implied_semicolon] = o }
  opt.on('--qmark-after-prompt') { |o| options[:qmark_after_prompt] = o }
  opt.on('--randomize') { |o| options[:randomize] = o }
  opt.on('--lock-fornext') { |o| options[:lock_fornext] = o }
end.parse!

list_filename = options[:list_name]
list_tokens = options.key?(:tokens)
pretty_filename = options[:pretty_name]
run_filename = options[:run_name]
cref_filename = options[:cref_name]
show_profile = options.key?(:profile)
show_heading = !options.key?(:no_heading)
echo_input = options.key?(:echo_input)
trace_flag = options.key?(:trace)
show_timing = !options.key?(:no_timing)
output_speed = 0
output_speed = 10 if options.key?(:tty)
newline_speed = 0
newline_speed = 10 if options.key?(:tty_lf)
print_width = 72
print_width = options[:print_width].to_i if options.key?(:print_width)
zone_width = 16
zone_width = options[:zone_width].to_i if options.key?(:zone_width)
int_floor = options.key?(:int_floor)
ignore_rnd_arg = options.key?(:ignore_rnd_arg)
implied_semicolon = options.key?(:implied_semicolon)
qmark_after_prompt = options.key?(:qmark_after_prompt)
randomize = options.key?(:randomize)
lock_fornext = options.key?(:lock_fornext)

default_prompt = TextConstantToken.new('"? "')
console_io =
  ConsoleIo.new(print_width, zone_width, output_speed, newline_speed,
                implied_semicolon, default_prompt, qmark_after_prompt,
                echo_input)

tokenbuilders = make_interpreter_tokenbuilders

if show_heading
  console_io.print_line('BASIC-1965 interpreter version -1')
  console_io.newline
end

program = Program.new(console_io, tokenbuilders)
if !run_filename.nil?
  token = TextConstantToken.new('"' + run_filename + '"')
  nametokens = [TextConstant.new(token)]
  if program.load(nametokens) && program.check
    interpreter =
      Interpreter.new(console_io, int_floor, ignore_rnd_arg, randomize,
                      lock_fornext)
    interpreter.run(program, trace_flag, show_timing, show_profile)
  end
elsif !list_filename.nil?
  token = TextConstantToken.new('"' + list_filename + '"')
  nametokens = [TextConstant.new(token)]
  if program.load(nametokens)
    line_list_spec = program.line_list_spec('')
    program.list(line_list_spec, list_tokens)
  end
elsif !pretty_filename.nil?
  token = TextConstantToken.new('"' + pretty_filename + '"')
  nametokens = [TextConstant.new(token)]
  if program.load(nametokens)
    line_list_spec = program.line_list_spec('')
    program.pretty(line_list_spec)
  end
elsif !cref_filename.nil?
  token = TextConstantToken.new('"' + cref_filename + '"')
  nametokens = [TextConstant.new(token)]
  if program.load(nametokens)
    program.crossref
  end
else
  interpreter =
    Interpreter.new(console_io, int_floor, ignore_rnd_arg, randomize,
                    lock_fornext)
  shell = Shell.new(console_io, interpreter, program)
  shell.run
end

if show_heading
  console_io.newline
  console_io.print_line('BASIC-1965 ended')
end
