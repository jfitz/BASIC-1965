#!/usr/bin/ruby

require 'benchmark'
require 'BASICException'
require 'Constants'
require 'Operators'
require 'Expressions'
require 'Statements'

$randomizer = Random.new

class LineNumber
  def initialize(number)
    regex = Regexp.new('^\d+$')
    raise(BASICException, "'#{number}' is not a line number", caller) if regex !~ number
    @line_number = number.to_i
  end
  
  def to_i
    @line_number
  end
  
  def to_s
    @line_number.to_s
  end
end

class PrintHandler
  def initialize
    @column = 0
  end
  
  def print_item(text)
    print text
    @column += text.size
  end
  
  def tab
    new_column = ((@column / 14) + 1) * 14
    (new_column - @column).times { | i | print ' ' }
    @column = new_column
  end
  
  def newline
    print "\n"
    @column = 0
  end
  
  def null
  end
end

class Interpreter
  def initialize
    @running = false
    @data_store = Array.new
    @data_index = 0
    @printer = PrintHandler.new
    @return_stack = Array.new
    @fornexts = Hash.new
  end
  
  def parse_line(line)
    m = /^\d+/.match(line)
    # convert to int for a sortable key
    line_num = m[0].to_i
    # strip leading blanks
    line_text = m.post_match.sub(/^ +/, '')
    # pick out the keyword
    object = UnknownStatement.new(line_text)
      #todo: RESTORE
    if line_text[0..2] == 'REM' then object = RemarkStatement.new(line_text[3..-1])
    elsif line_text[0..2] == 'LET' then object = LetStatement.new(line_text[3..-1])
    elsif line_text[0..4] == 'INPUT' then object = InputStatement.new(line_text[5..-1])
    elsif line_text[0..1] == 'IF' then object = IfStatement.new(line_text[2..-1])
    elsif line_text[0..4] == 'PRINT' then object = PrintStatement.new(line_text[5..-1])
    elsif line_text[0..4] == 'GO TO' then object = GotoStatement.new(line_text[5..-1])
    elsif line_text[0..3] == 'GOTO' then object = GotoStatement.new(line_text[4..-1])
    elsif line_text[0..4] == 'GOSUB' then object = GosubStatement.new(line_text[5..-1])
    elsif line_text[0..2] == 'FOR' then object = ForStatement.new(line_text[3..-1])
    elsif line_text[0..3] == 'NEXT' then object = NextStatement.new(line_text[4..-1])
    elsif line_text == 'RETURN' then object = ReturnStatement.new
    elsif line_text[0..3] == 'READ' then object = ReadStatement.new(line_text[4..-1])
    elsif line_text[0..3] == 'DATA' then object = DataStatement.new(line_text[4..-1])
    elsif line_text == 'STOP' then object = StopStatement.new
    elsif line_text == 'END' then object = EndStatement.new
    elsif line_text[0..4] == 'TRACE' then object = TraceStatement.new(line_text[5..-1])
    end
    [line_num, object]
  end

  def cmd_list
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      line_numbers.each { | line_num | puts "#{line_num.to_s} #{@program_lines[line_num]}" }
    else
      puts 'No program loaded'
    end
  end
  
  private
  def verify_next_line_number(line_numbers, next_line_number)
    if next_line_number == nil then
      raise BASICException, "Program terminated without END", caller
    end
    if !line_numbers.include?(next_line_number) then
      raise BASICException, "Line number #{next_line_number} not found", caller
    end
    next_line_number
  end
  
  public
  def cmd_run(trace_flag)
    @variables = Hash.new
    @tron_flag = false
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
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
          if @running then
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
    filename = filename.sub(/^\s+/, '')
    if filename.size > 0 then
      begin
        File.open(filename, 'r') do | file |
          @program_lines = Hash.new
          file.each_line do | line |
            line.chomp!
            if line =~ /^\d+/ then
              line_parts = parse_line(line)
              line_num = line_parts[0]
              line_text = line_parts[1]
              @program_lines[line_num] = line_text
              if line_text.errors.size > 0 then
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
    if line_numbers.size > 0 then
      filename.sub!(/^\s+/, '')
      if filename.size > 0 then
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
    puts @variables
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
  
  def get_value(variable)
    begin
      v = variable.to_s
      if !@variables.has_key?(v) then
        @variables[v] = 0
      end
      x = @variables[v]
      case x.class.to_s
      when 'Fixnum'
        NumericConstant.new(x)
      when 'Float'
        NumericConstant.new(x)
      else
        raise Exception, "Invalid variable value type #{x}", caller
      end
    rescue
      raise BASICException, "Unknown variable #{variable}", caller
    end
  end
  
  def set_value(variable, value)
    c = value.class.to_s
    if c != 'Fixnum' and c != 'Float' and c!= 'NumericConstant' then
      raise Exception, "Bad variable value type #{c}", caller
    end
    ## puts "SET: #{variable} = #{value}"
    begin
      v = variable.to_s
      if c == 'NumericConstant' then
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
    raise(BASICException, "RETURN without GOSUB", caller) if @return_stack.size == 0
    @return_stack.pop
  end
  
  def set_fornext(fornext_control)
    control_variable = fornext_control.control_variable_name
    @fornexts[control_variable] = fornext_control
  end
  
  def get_fornext(control_variable)
    fornext = @fornexts[control_variable.to_s]
    raise(BASICException, "NEXT without FOR", caller) if fornext == nil
    fornext
  end
  
  def store_data(value)
    @data_store << value
  end
  
  def read_data
    if @data_index < @data_store.size then
      @data_index += 1
      @data_store[@data_index - 1]
    else
      raise(BASICException, "Out of data", caller)
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
      cmd = gets
      cmd.chomp!
      
      # process command
      if cmd =~ /^\d+/ then
        # program line -- store
        line_parts = parse_line(cmd)
        line_num = line_parts[0]
        line_text = line_parts[1]
        @program_lines[line_num] = line_text
        need_prompt = false
        if line_text.errors.size > 0 then
          line_text.errors.each { | error | puts error }
          need_prompt = true
        end
      else
        # immediate command -- execute
        if cmd == '' then x = 0
        elsif cmd == 'LIST' then cmd_list
        elsif cmd == 'RUN' then
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
    if timing_flag then
      puts "CPU time:"
      puts " user: #{user_time.round(2)}"
      puts " system: #{sys_time.round(2)}"
    end
  end
end

interpreter = Interpreter.new
if ARGV.size > 0 then
  filename = ''
  timing_flag = true
  trace_flag = false
  ARGV.each do | arg |
    if arg[0] == '-' then
      trace_flag = true if arg == '-trace'
      timing_flag = false if arg == '-notiming'
    else
      filename = arg if filename == '' #take only the first filename
    end
  end
  # set_trace_func proc { | event, file, line, id, binding, classname |
  #  puts "#{classname}.#{id} #{file}:#{line} #{event}" if !['IO', 'Kernel', 'Module', 'Fixnum',  'NameError', 'Exception', 'NoMethodError', 'Symbol', 'String', 'NilClass', 'Hash'].include?(classname.to_s)
  # }
  interpreter.load_and_run(filename, trace_flag, timing_flag)
else
  interpreter.go
end

