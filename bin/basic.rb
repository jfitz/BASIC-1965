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

# option class
class Option
  attr_reader :type
  attr_reader :value

  def initialize(type, value)
    @type = type
    check_value(value)
    @value = value
  end

  def set(value)
    check_value(value)
    @value = value
  end

  private

  def check_value(value)
    case @type
    when :bool
      legals = %w(TrueClass FalseClass)

      raise(BASICRuntimeError, 'Invalid value') unless
        legals.include?(value.class.to_s)
    when :int
      legals = %w(Fixnum)

      raise(BASICRuntimeError, 'Invalid value') unless
        legals.include?(value.class.to_s)
    else
      raise(BASICRuntimeError, 'Unknown value type')
    end
  end
end

# interactive shell
class Shell
  def initialize(console_io, interpreter, program, action_options, tokenbuilders)
    @console_io = console_io
    @interpreter = interpreter
    @program = program
    @action_options = action_options
    @tokenbuilders = tokenbuilders
    @invalid_tokenbuilder = InvalidTokenBuilder.new
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

  def process_line(line)
    # starts with a number, so maybe it is a program line
    return @program.store_program_line(line, true) if /\A\d/ =~ line

    # immediate command -- tokenize and execute
    tokenizer = Tokenizer.new(@tokenbuilders, @invalid_tokenbuilder)
    tokens = tokenizer.tokenize(line)
    tokens.delete_if(&:whitespace?)

    process_command(tokens, line)
  end

  def process_command(tokens, line)
    return false if tokens.empty?

    keyword = tokens[0]
    args = tokens[1..-1]

    if keyword.keyword?
      execute_command(keyword, args)
    else
      @console_io.print_line("Unknown command '#{line}'")
      @console_io.newline
    end
  end

  def option_command(args)
    if args.empty?
      @action_options.each do |option|
        name = option[0].upcase
        value = option[1].value.to_s.upcase
        @console_io.print_line(name + ' ' + value)
      end
    elsif args.size == 1 && args[0].keyword?
      kwd = args[0].to_s
      kwd_d = kwd.downcase

      if @action_options.key?(kwd_d)
        value = @action_options[kwd_d].value.to_s.upcase
        @console_io.print_line("#{kwd} #{value}")
      else
        @console_io.print_line("Unknown option #{kwd}")
        @console_io.newline
      end
    elsif args.size == 2 && args[0].keyword?
      kwd = args[0].to_s
      kwd_d = kwd.downcase

      if @action_options.key?(kwd_d)
        begin
          if args[1].boolean_constant?
            boolean = BooleanConstant.new(args[1])
            @action_options[kwd_d].set(boolean.to_v)
          else
            @console_io.print_line('Incorrect value type')
          end
        rescue BASICRuntimeError => e
          @console_io.print_line(e)
        end
        value = @action_options[kwd_d].value.to_s.upcase
        @console_io.print_line("#{kwd} #{value}")
      else
        @console_io.print_line("Unknown option #{kwd}")
        @console_io.newline
      end
    else
      @console_io.print_line('Syntax error')
      @console_io.newline
    end
  end

  def execute_command(keyword, args)
    need_prompt = true

    case keyword.to_s
    when 'EXIT'
      @done = true
    when 'NEW'
      @program.cmd_new
      @interpreter.clear_variables
      @interpreter.clear_breakpoints
    when 'RUN'
      if @program.check
        timing = Benchmark.measure {
          @program.run(@interpreter, @action_options)
        }
        print_timing(timing, @console_io) if @action_options['timing'].value
      end
    when 'BREAK'
      @interpreter.set_breakpoints(args)
    when 'LOAD'
      @interpreter.clear_breakpoints
      @program.load(args)
    when 'SAVE'
      @program.save(args)
    when 'LIST'
      @program.list(args, false)
    when 'PRETTY'
      @program.pretty(args)
    when 'DELETE'
      @program.delete(args)
    when 'PROFILE'
      @program.profile(args)
    when 'RENUMBER'
      if @program.check
        renumber_map = @program.renumber
        @interpreter.renumber_breakpoints(renumber_map)
      end
    when 'CROSSREF'
      @program.crossref if @program.check
    when 'DIMS'
      @interpreter.dump_dims
    when 'PARSE'
      @program.parse(args)
    when 'TOKENS'
      @program.list(args, true)
    when 'UDFS'
      @interpreter.dump_user_functions
    when 'VARS'
      @interpreter.dump_vars
    when 'OPTION'
      option_command(args)
    else
      @console_io.print_line("Unknown command #{keyword}")
      @console_io.newline
    end

    need_prompt
  rescue BASICCommandError => e
    @console_io.print_line(e.to_s)
    @console_io.newline
    true
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

  tokenbuilders <<
    ListTokenBuilder.new(FunctionFactory.user_function_names, UserFunctionToken)

  tokenbuilders << TextTokenBuilder.new
  tokenbuilders << NumberTokenBuilder.new
  tokenbuilders << VariableTokenBuilder.new
  tokenbuilders << ListTokenBuilder.new(%w(TRUE FALSE), BooleanConstantToken)
  tokenbuilders << WhitespaceTokenBuilder.new
end

def make_command_tokenbuilders
  tokenbuilders = []

  keywords = %w(
    BREAK CROSSREF DELETE DIMS EXIT HEADING LIST LOAD NEW OPTION PARSE PRETTY
    PROFILE PROVENENCE RENUMBER RUN SAVE TIMING TRACE TOKENS UDFS VARS
  )
  tokenbuilders << ListTokenBuilder.new(keywords, KeywordToken)

  un_ops = UnaryOperator.operators
  bi_ops = BinaryOperator.operators
  operators = (un_ops + bi_ops).uniq
  tokenbuilders << ListTokenBuilder.new(operators, OperatorToken)

  tokenbuilders << ListTokenBuilder.new([',', ';'], ParamSeparatorToken)

  tokenbuilders << TextTokenBuilder.new
  tokenbuilders << NumberTokenBuilder.new

  tokenbuilders << ListTokenBuilder.new(%w(TRUE FALSE), BooleanConstantToken)
  tokenbuilders << WhitespaceTokenBuilder.new
end

def print_timing(timing, console_io)
  user_time = timing.utime + timing.cutime
  sys_time = timing.stime + timing.cstime
  console_io.newline
  console_io.print_line('CPU time:')
  console_io.print_line(" user: #{user_time.round(2)}")
  console_io.print_line(" system: #{sys_time.round(2)}")
  console_io.newline
end

options = {}
OptionParser.new do |opt|
  opt.on('-l', '--list SOURCE') { |o| options[:list_name] = o }
  opt.on('--tokens') { |o| options[:tokens] = o }
  opt.on('-p', '--pretty SOURCE') { |o| options[:pretty_name] = o }
  opt.on('-r', '--run SOURCE') { |o| options[:run_name] = o }
  opt.on('--profile') { |o| options[:profile] = o }
  opt.on('-c', '--crossref SOURCE') { |o| options[:cref_name] = o }
  opt.on('--parse SOURCE') { |o| options[:parse_name] = o }
  opt.on('--no-heading') { |o| options[:no_heading] = o }
  opt.on('--echo-input') { |o| options[:echo_input] = o }
  opt.on('--trace') { |o| options[:trace] = o }
  opt.on('--provenence') { |o| options[:provenence] = o }
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
parse_filename = options[:parse_name]
run_filename = options[:run_name]
cref_filename = options[:cref_name]
show_profile = options.key?(:profile)

action_options = {}
action_options['heading'] = Option.new(:bool, !options.key?(:no_heading))
action_options['provenence'] = Option.new(:bool, options.key?(:provenence))
action_options['timing'] = Option.new(:bool, !options.key?(:no_timing))
action_options['trace'] = Option.new(:bool, options.key?(:trace))

output_flags = {}
output_flags['echo'] = options.key?(:echo_input)
output_flags['speed'] = 0
output_flags['speed'] = 10 if options.key?(:tty)
output_flags['newline_speed'] = 0
output_flags['newline_speed'] = 10 if options.key?(:tty_lf)
output_flags['print_width'] = 72
output_flags['print_width'] = options[:print_width].to_i if
  options.key?(:print_width)
output_flags['zone_width'] = 16
output_flags['zone_width'] = options[:zone_width].to_i if
  options.key?(:zone_width)
output_flags['implied_semicolon'] = options.key?(:implied_semicolon)
output_flags['qmark_after_prompt'] = options.key?(:qmark_after_prompt)
output_flags['default_prompt'] = TextConstantToken.new('"? "')

interpreter_options = {}

interpreter_options['ignore_rnd_arg'] =
  Option.new(:bool, options.key?(:ignore_rnd_arg))

interpreter_options['int_floor'] = Option.new(:bool, options.key?(:int_floor))

interpreter_options['lock_fornext'] =
  Option.new(:bool, options.key?(:lock_fornext))

interpreter_options['randomize'] = Option.new(:bool, options.key?(:randomize))

console_io = ConsoleIo.new(output_flags)

tokenbuilders = make_interpreter_tokenbuilders

if action_options['heading'].value
  console_io.print_line('BASIC-1965 interpreter version -1')
  console_io.newline
end

program = Program.new(console_io, tokenbuilders)
if !run_filename.nil?
  token = TextConstantToken.new('"' + run_filename + '"')
  nametokens = [TextConstant.new(token)]
  if program.load(nametokens) && program.check
    interpreter = Interpreter.new(console_io, interpreter_options)
    interpreter.set_default_args('RND', NumericConstant.new(1))

    timing = Benchmark.measure {
      program.run(interpreter, action_options)
    }

    print_timing(timing, console_io) if action_options['timing'].value
    program.profile('') if show_profile
  end
elsif !list_filename.nil?
  token = TextConstantToken.new('"' + list_filename + '"')
  nametokens = [TextConstant.new(token)]
  program.list('', list_tokens) if program.load(nametokens)
elsif !parse_filename.nil?
  token = TextConstantToken.new('"' + parse_filename + '"')
  nametokens = [TextConstant.new(token)]
  program.parse('') if program.load(nametokens)
elsif !pretty_filename.nil?
  token = TextConstantToken.new('"' + pretty_filename + '"')
  nametokens = [TextConstant.new(token)]
  program.pretty('') if program.load(nametokens)
elsif !cref_filename.nil?
  token = TextConstantToken.new('"' + cref_filename + '"')
  nametokens = [TextConstant.new(token)]
  program.crossref if program.load(nametokens)
else
  interpreter = Interpreter.new(console_io, interpreter_options)
  interpreter.set_default_args('RND', NumericConstant.new(1))
  tokenbuilders = make_command_tokenbuilders

  shell =
    Shell.new(console_io, interpreter, program, action_options, tokenbuilders)

  shell.run
end

if action_options['heading'].value
  console_io.newline
  console_io.print_line('BASIC-1965 ended')
end
