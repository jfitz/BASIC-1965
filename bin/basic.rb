#!/usr/bin/ruby

require 'benchmark'
require 'BASICException'
require 'Constants'
require 'Operators'
require 'Expressions'
require 'Statements'

$randomizer = Random.new

class LineNumber
  def initialize(line_number)
    if line_number.class.to_s == 'String'
      regex = Regexp.new('\A\d+\z')
      fail(BASICException, "'#{line_number}' is not a line number") if regex !~ line_number
      @line_number = line_number.to_i
    elsif line_number.class.to_s == 'Fixnum'
      @line_number = line_number
    else
      fail BASICException, 'Invalid line number'
    end
  end

  def line_number
    @line_number
  end
  
  def eql?(rhs)
    @line_number == rhs.line_number
  end

  def ==(rhs)
    @line_number == rhs.line_number
  end

  def hash
    @line_number.hash
  end

  def succ
    LineNumber.new(@line_number + 1)
  end

  def <=>(rhs)
    @line_number <=> rhs.line_number
  end

  def >(rhs)
    @line_number > rhs.line_number
  end
  
  def >=(rhs)
    @line_number >= rhs.line_number
  end
  
  def <(rhs)
    @line_number < rhs.line_number
  end
  
  def <=(rhs)
    @line_number <= rhs.line_number
  end
  
  def to_s
    @line_number.to_s
  end
end

class LineNumberRange
  def initialize(text, program_line_numbers)
    @line_numbers = Array.new
    @range_type = :empty
    if text == ''
      @line_numbers = program_line_numbers
      @range_type = :all
    else
      begin
        line_number = LineNumber.new(text)
        @line_numbers << line_number if program_line_numbers.include?(line_number)
        @range_type = :single
      rescue BASICException
        begin
          @line_numbers = line_range(text, program_line_numbers)
        rescue BASICException
          @line_numbers = line_list(text, program_line_numbers)
        end
        @range_type = :range
      end
    end
  end

  def line_numbers
    @line_numbers
  end

  def is_single
    @range_type == :single
  end

  def is_range
    @range_type == :range
  end

  def is_all
    @range_type == :all
  end

  private
  def line_range(spec, program_line_numbers)
    list = Array.new
    spec = spec.sub(/^\s+/, '').sub(/\s+$/, '')
    regex = Regexp.new('^\d+-\d+$')
    fail(BASICException, "Invalid list specification") if regex !~ spec
    parts = spec.split('-')
    start_val = LineNumber.new(parts[0])
    end_val = LineNumber.new(parts[1])
    fail(BASICException, "Invalid list specification") if end_val < start_val
    program_line_numbers.each do | line_number |
      list << line_number if line_number >= start_val and line_number <= end_val
    end
    list
  end

  private
  def line_list(spec, program_line_numbers)
    list = Array.new
    spec = spec.sub(/^\s+/, '').sub(/\s+$/, '')
    two_regex = Regexp.new('\A\d+\+\d+\z')
    one_regex = Regexp.new('\A\d+\+\z')
    if two_regex =~ spec
      parts = spec.split('+')
      start_val = LineNumber.new(parts[0])
      count = parts[1].to_i
    elsif one_regex =~ spec
      parts = spec.split('+')
      start_val = LineNumber.new(parts[0])
      count = 20
    else
      fail(BASICException, "Invalid list specification")
    end
    program_line_numbers.each { | line_number |
      if line_number >= start_val and count >= 0
        list << line_number
        count -= 1
      end
    }
    list
  end
end

class PrintHandler
  def initialize(max_width)
    @column = 0
    @max_width = max_width
  end
  
  def print_item(text)
    if (@column + text.length) < @max_width
      print text
      @column += text.size
    else
      overflow = @column + text.length - @max_width
      first_count = text.length - overflow
      print text[0..first_count]
      newline
      print text[first_count..text.length]
      @column = overflow
    end
  end
  
  def tab
    new_column = ((@column / 14) + 1) * 14
    spaces = ' ' * (new_column - @column)
    print_item(spaces)
  end
  
  def halftab
    new_column = ((@column / 6) + 1) * 6
    spaces = ' ' * (new_column - @column)
    print_item(spaces)
  end
  
  def newline
    puts
    @column = 0
  end
  
  def newline_when_needed
    newline if @column > 0
  end

  def implied_newline
    @column = 0
  end
end

class Interpreter
  def initialize
    @running = false
    @data_store = Array.new
    @data_index = 0
    @printer = PrintHandler.new(66)
    @return_stack = Array.new
    @fornexts = Hash.new
    @dimensions = Hash.new
    @user_functions = Hash.new
    @user_var_names = Hash.new
    @user_var_values = Array.new
  end
  
  def parse_line(line)
    m = /^\d+/.match(line)
    line_num = LineNumber.new(m[0])
    # strip leading and trailing blanks (SPACEs and TABs)
    line_text = m.post_match.sub(/^\s+/, '').sub(/\s+$/, '')
    # pick out the keyword
    statement = UnknownStatement.new(line_text)
    begin
      if line_text == '' then statement = EmptyStatement.new()
      elsif line_text[0..2] == 'REM' then statement = RemarkStatement.new(line_text[3..-1])
      elsif line_text[0..2] == 'DIM' then statement = DimStatement.new(line_text[3..-1])
      elsif line_text[0..2] == 'DEF' then statement = DefineFunctionStatement.new(line_text[3..-1])
      elsif line_text[0..2] == 'LET' then statement = LetStatement.new(line_text[3..-1])
      elsif line_text[0..4] == 'INPUT' then statement = InputStatement.new(line_text[5..-1])
      elsif line_text[0..1] == 'IF' then statement = IfStatement.new(line_text[2..-1])
      elsif line_text[0..4] == 'PRINT' then statement = PrintStatement.new(line_text[5..-1])
      elsif line_text[0..4] == 'GO TO' then statement = GotoStatement.new(line_text[5..-1])
      elsif line_text[0..3] == 'GOTO' then statement = GotoStatement.new(line_text[4..-1])
      elsif line_text[0..4] == 'GOSUB' then statement = GosubStatement.new(line_text[5..-1])
      elsif line_text[0..2] == 'FOR' then statement = ForStatement.new(line_text[3..-1])
      elsif line_text[0..3] == 'NEXT' then statement = NextStatement.new(line_text[4..-1])
      elsif line_text == 'RETURN' then statement = ReturnStatement.new
      elsif line_text[0..3] == 'READ' then statement = ReadStatement.new(line_text[4..-1])
      elsif line_text[0..3] == 'DATA' then statement = DataStatement.new(line_text[4..-1])
      #todo: RESTORE
      elsif line_text == 'STOP' then statement = StopStatement.new
      elsif line_text == 'END' then statement = EndStatement.new
      elsif line_text[0..4] == 'TRACE' then statement = TraceStatement.new(line_text[5..-1])
      end
    rescue BASICException
      puts "Syntax error"
    end
    [line_num, statement]
  end

  def cmd_list(linespec)
    linespec = linespec.sub(/^\s+/, '').sub(/\s+$/, '')
    if @program_lines.size > 0
      begin
        line_number_range = LineNumberRange.new(linespec, @program_lines.keys.sort)
        line_numbers = line_number_range.line_numbers
        line_numbers.each do | line_number |
          puts "#{line_number.to_s} #{@program_lines[line_number]}"
        end
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end
  
  def cmd_delete(linespec)
    linespec = linespec.sub(/^\s+/, '').sub(/\s+$/, '')
    if @program_lines.size > 0
      begin
        line_number_range = LineNumberRange.new(linespec, @program_lines.keys.sort)
        line_numbers = line_number_range.line_numbers
        if line_number_range.is_single
          line_numbers.each do | line_number |
            @program_lines.delete(line_number)
          end
        elsif line_number_range.is_range
          line_numbers.each do | line_number |
            puts "#{line_number.to_s} #{@program_lines[line_number]}"
          end
          print "DELETE THESE LINES? "
          answer = gets.chomp
          if answer == "YES"
            line_numbers.each do | line_number |
              @program_lines.delete(line_number)
            end
          end
        elsif line_number_range.is_all
          puts "Type NEW to delete an entire program"
        end
      rescue BASICException => e
        puts e
      end
    else
      puts 'No program loaded'
    end
  end
  
  private
  def verify_next_line_number(line_numbers, next_line_number)
    if next_line_number.nil?
      fail BASICException, "Program terminated without END"
    end
    if !line_numbers.include?(next_line_number)
      fail BASICException, "Line number #{next_line_number} not found"
    end
    next_line_number
  end
  
  public
  def cmd_run(trace_flag)
    @variables = Hash.new
    @tron_flag = false
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0
      # phase 1: do all initialization (store values in DATA lines)
      line_numbers.each do | line_number |
        line = @program_lines[line_number]
        line.pre_execute(self)
      end
      # phase 2: run each command
      # start with the first line number
      @current_line_number = line_numbers[0]
      @running = true
      while @running
        # pick the next line number
        @next_line_number = line_numbers[line_numbers.index(@current_line_number) + 1]
        begin
          line = @program_lines[@current_line_number]
          puts "#{@current_line_number}: #{line.to_s}" if trace_flag or @tron_flag
          line.execute(self)
          if @running
            # set the next line number (which may have been changed by execute() )
            @current_line_number = verify_next_line_number(line_numbers, @next_line_number)
          else
            @current_line_number = nil
          end
        rescue BASICException => message
          puts "#{message} in line #{current_line_number}"
          @running = false
        end
      end
    else
      puts 'No program loaded'
    end
  end

  def trace(tron_flag)
    @tron_flag = tron_flag
  end

  def cmd_new
    @program_lines = Hash.new
    @variables = Hash.new
  end
  
  def cmd_load(filename)
    filename = filename.sub(/^\s+/, '').sub(/\s+$/, '')
    if filename.size > 0
      begin
        File.open(filename, 'r') do | file |
          @program_lines = Hash.new
          file.each_line do | line |
            line.chomp!
            if line =~ /^\d+/
              line_parts = parse_line(line)
              line_num = line_parts[0]
              line_text = line_parts[1]
              @program_lines[line_num] = line_text
              if line_text.errors.size > 0
                line_text.errors.each { | error | puts error }
              end
            else
              # warn about line that does not begin with line number
            end
          end
        end
        true
      rescue Errno::ENOENT
        puts "File '#{filename}' not found"
        false
      end
    else
      puts "Filename not specified"
      false
    end
  end

  def cmd_save(filename)
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0
      filename.sub!(/^\s+/, '')
      if filename.size > 0
        begin
          File.open(filename, 'w') do | file |
            line_numbers.each { | line_num | file.puts "#{line_num.to_s} #{@program_lines[line_num]}" }
            file.close
          end
        rescue Errno::ENOENT
          puts "File '#{filename}' not opened"
        end
      else
        puts "Filename not specified"
      end
    else
      puts 'No program loaded'
    end
  end

  def dump_vars
    @variables.each do | key, value |
      puts "#{key}: #{value}"
    end
  end

  def dump_user_functions
    @user_functions.each do | name, expression |
      puts "#{name}: #{expression}"
    end
  end
  
  def stop
    @running = false
    puts "STOP in line #{@current_line_number}"
  end

  def current_line_number
    @current_line_number
  end

  def get_next_line
    @next_line_number
  end
  
  def set_next_line(line_number)
    @next_line_number = line_number
  end

  def set_dimensions(variable, subscripts)
    @dimensions[variable] = subscripts
  end

  def set_user_function(name, variable_names, expressions)
    @user_var_names[name] = variable_names
    @user_functions[name] = expressions
  end

  def get_user_function(name)
    @user_functions[name]
  end

  def get_user_var_names(name)
    @user_var_names[name]
  end

  def set_user_var_values(user_var_values)
    @user_var_values.push(user_var_values)
  end

  def clear_user_var_values
    @user_var_values.pop
  end

  def check_subscripts(variable, subscripts)
    if @dimensions.has_key?(variable)
      dimensions = @dimensions[variable]
    else
      dimensions = Array.new
      dimensions << 10
    end
    if subscripts.size != dimensions.size
      fail BASICException, "Incorrect number of subscripts"
    end
    subscripts.zip(dimensions).each do | pair |
      if pair[0] > pair[1]
        fail BASICException, "Subscript #{pair[0]} out of range #{pair[1]}"
      end
    end
  end
  
  def get_value(variable)
    x = nil
    v = variable.to_s
    begin
      # first look in user function values stack
      length = @user_var_values.length
      if length > 0
        names_and_values = @user_var_values[-1]
        if names_and_values.has_key?(variable)
          x = names_and_values[variable]
        end
      end
      # then look in general table
      if x.nil?
        if not @variables.has_key?(v)
          @variables[v] = 0
        end
        x = @variables[v]
      end
      case x.class.to_s
      when 'Fixnum'
        NumericConstant.new(x)
      when 'Float'
        NumericConstant.new(x)
      when 'NumericConstant'
        x
      else
        fail Exception, "Invalid variable value type #{x}"
      end
    rescue
      raise BASICException, "Unknown variable #{variable}", caller
    end
  end
  
  def set_value(variable, value)
    c = value.class.to_s
    if c != 'Fixnum' and c != 'Float' and c!= 'NumericConstant'
      fail Exception, "Bad variable value type #{c}"
    end
    subscripts = variable.subscripts
    begin
      v = variable.to_s
      if c == 'NumericConstant'
        @variables[v] = value.to_v
      else
        @variables[v] = value
      end
    rescue
      raise BASICException, "Unknown variable #{variable}", caller
    end
  end

  def print_handler
    @printer
  end
  
  def push_return(destination)
    @return_stack.push(destination)
  end
  
  def pop_return
    fail(BASICException, "RETURN without GOSUB") if @return_stack.size == 0
    @return_stack.pop
  end
  
  def set_fornext(fornext_control)
    control_variable = fornext_control.control_variable
    control_variable_name = control_variable.to_s
    @fornexts[control_variable_name] = fornext_control
  end
  
  def get_fornext(control_variable)
    fornext = @fornexts[control_variable.to_s]
    fail(BASICException, "NEXT without FOR") if fornext.nil?
    fornext
  end
  
  def store_data(values)
    @data_store += values
  end
  
  def read_data
    if @data_index < @data_store.size
      @data_index += 1
      @data_store[@data_index - 1]
    else
      fail BASICException, "Out of data"
    end
  end

  def go
    puts "BASIC-1965 interpreter version -1"
    puts
    @program_lines = Hash.new
    need_prompt = true
    done = false
    while !done do
      # display prompt
      print "READY\n" if need_prompt

      # read input
      cmd = gets.chomp
      
      # process command
      if cmd =~ /^\d/
        # program line -- store
        line_parts = parse_line(cmd)
        line_num = line_parts[0]
        line_text = line_parts[1]
        @program_lines[line_num] = line_text
        need_prompt = false
        if line_text.errors.size > 0
          line_text.errors.each { | error | puts error }
          need_prompt = true
        end
      else
        # immediate command -- execute
        if cmd == '' then x = 0
        elsif cmd[0..3] == 'LIST' then cmd_list(cmd[4..-1])
        elsif cmd[0..5] == 'DELETE' then cmd_delete(cmd[6..-1])
        elsif cmd == 'RUN'
          timing = Benchmark.measure { cmd_run(false) }
          user_time = timing.utime + timing.cutime
          sys_time = timing.stime + timing.cstime
          puts
          puts "CPU time:"
          puts " user: #{user_time.round(2)}"
          puts " system: #{sys_time.round(2)}"
          puts
        elsif cmd == 'TRACE' then cmd_run(true)
        elsif cmd == 'NEW' then cmd_new
        elsif cmd[0..3] == 'LOAD' then cmd_load(cmd[4..-1])
        elsif cmd[0..3] == 'SAVE' then cmd_save(cmd[4..-1])
        elsif cmd == 'EXIT' then done = true
        elsif cmd == '.VARS' then dump_vars
        elsif cmd == '.UDFS' then dump_user_functions
        else print "Unknown command #{cmd}\n"
        end
        need_prompt = true
      end
    end
    puts
    puts "BASIC-1965 ended"
  end
  
  def load_and_run(filename, trace_flag, timing_flag)
    puts "BASIC-1965 interpreter version -1"
    puts
    @program_lines = Hash.new
    timing = Benchmark.measure { cmd_run(trace_flag) if cmd_load(filename) }
    user_time = timing.utime + timing.cutime
    sys_time = timing.stime + timing.cstime
    puts
    puts "BASIC-1965 ended"
    if timing_flag
      puts "CPU time:"
      puts " user: #{user_time.round(2)}"
      puts " system: #{sys_time.round(2)}"
    end
  end
end

interpreter = Interpreter.new
if ARGV.size > 0
  filename = ''
  timing_flag = true
  trace_flag = false
  ARGV.each do | arg |
    if arg[0] == '-'
      trace_flag = true if arg == '-trace'
      timing_flag = false if arg == '-notiming'
    else
      filename = arg if filename == '' #take only the first filename
    end
  end
  ARGV.clear
  # set_trace_func proc { | event, file, line, id, binding, classname |
  #  puts "#{classname}.#{id} #{file}:#{line} #{event}" if !['IO', 'Kernel', 'Module', 'Fixnum',  'NameError', 'Exception', 'NoMethodError', 'Symbol', 'String', 'NilClass', 'Hash'].include?(classname.to_s)
  # }
  interpreter.load_and_run(filename, trace_flag, timing_flag)
else
  interpreter.go
end

