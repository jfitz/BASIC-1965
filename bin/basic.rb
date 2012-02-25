#!/usr/bin/ruby

class NumericValue
  def initialize(text)
    case
    when text =~ /^[+-]?\d+$/: @value = text.to_i
    when text =~ /^[+-]?\d+\.\d*$/: @value = text.to_f
    else raise "Not a number" 
    end
  end

  def value
    @value
  end
  
  def to_s
    @value.to_s
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
end

class AbstractLine
  def initialize(keyword)
    @keyword = keyword
    @errors = Array.new
  end
  
  def errors
    @errors
  end
end

class Unknown < AbstractLine
  def initialize(line)
    super('')
    @line = line
    @errors << "Unknown command #{@line}"
  end
  
  def to_s
    @line
  end
  
  def execute(interpreter)
    print "unsupported operation\n"
  end
end

class Remark < AbstractLine
  def initialize(line)
    super('REM')
    @contents = line
  end
  
  def to_s
    @keyword + @contents
  end

  def execute(interpreter)
    0
  end
end

class Dim < AbstractLine
  def initialize(line)
    super('DIM')
    # todo: allow 2 dimensions
    @variable_list = line.gsub(/ /, '').split(',')
    # variable name, parens, number, close-parens [comma, variable name, parens, number, close-parens]...
    @variable_list.each do | text_item |
      if text_item !~ /^[A-Z][0-9]?\(\d\d?\)$/ then
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  def execute(interpreter)
    print "unsupported operation #{@keyword}\n"
  end
end

class Let < AbstractLine
  def initialize(line)
    super('LET')
  end
  
  def to_s
    @keyword
  end
  
  def execute(interpreter)
    print "unsupported operation #{@keyword}\n"
  end
end

class Input < AbstractLine
  def initialize(line)
    super('INPUT')
    # todo: allow subscripted variables
    # todo: allow text prompt (?)
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      if text_item !~ /^[A-Z][0-9]?$/ then
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  def execute(interpreter)
    print "unsupported operation #{@keyword}\n"
  end
end

class If < AbstractLine
  def initialize(line)
    super('IF')
  end
  
  def to_s
    @keyword
  end
  
  def execute(interpreter)
    print "unsupported operation #{@keyword}\n"
  end
end

class Print < AbstractLine
  def initialize(line)
    super('PRINT')
    # todo: allow semicolon as separator
    # todo: keep separators for spacing
    # todo: allow quoted text
    # todo: allow subscripted variables
    # todo: allow expressions
    @variable_list = line.gsub(/ /, '').split(',')
    # variable/constant, [separator, variable/constant]... [separator]
    @variable_list.each do | text_item |
      if text_item !~ /^[A-Z][0-9]?$/ then
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  def execute(interpreter)
    # todo: track columns
    # todo: handle comma separators
    printer = interpreter.print_handler
    @variable_list.each do | variable_name |
      variable_value = interpreter.get_value(variable_name)
      if variable_value != nil then
        printer.print_item variable_value.to_s
      else
        print "Unknown variable #{variable_name}"
      end
      printer.tab
    end
    printer.newline
  end
end

class Goto < AbstractLine
  def initialize(line)
    super('GO TO')
    @destination = line.sub(/ /, '')
    if @destination !~ /^\d+$/ then
      @errors << "Invalid line number #{@destination}"
    end
  end
  
  def to_s
    @keyword
  end
  
  def execute(interpreter)
    interpreter.set_next_line(@destination)
  end
end

class Read < AbstractLine
  def initialize(line)
    super('READ')
    # todo: allow subscripted variable
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      if text_item !~ /^[A-Z][0-9]?$/ then
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  def execute(interpreter)
    @variable_list.each do | text_item |
      if text_item =~ /^[A-Z][0-9]?$/ then
        interpreter.set_value(text_item, interpreter.read_data)
      end
    end
  end
end

class DataLine < AbstractLine
  def initialize(line)
    super('DATA')
    @data_list = line.gsub(/ /, '').split(',')
    # number [comma, number]...
    @data_list.each do | text_item |
      begin
        NumericValue.new(text_item)
      rescue
        @errors << "Invalid value #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' '+ @data_list.join(', ')
  end
  
  def execute(interpreter)
    @data_list.each do | text_item |
      begin
        interpreter.store_data(NumericValue.new(text_item))
      rescue
        puts "Invalid value #{text_item} ignored"
      end
    end
  end
end

class Stop < AbstractLine
  def initialize
    super('STOP')
  end
  
  def to_s
    @keyword
  end
  
  def execute(interpreter)
    interpreter.stop
  end
end

class End < AbstractLine
  def initialize
    super('END')
  end
  
  def to_s
    @keyword
  end
  
  def execute(interpreter)
    interpreter.stop
  end
end

class Interpreter
  def initialize
    @running = false
    @variables = Hash.new
    ('A'..'Z').each do | name |
      @variables[name] = 0
      ('0'..'9').each { | number | @variables["#{name}#{number}"] = 0 }
    end
    @data_store = Array.new
    @data_index = 0
    @printer = PrintHandler.new
  end
  
  def parse_line(line)
    line =~ /^\d+/
    # convert to int for a sortable key
    line_num = $&.to_i
    # strip leading blanks
    line_text = $'.sub(/^ +/, '')
    # pick out the keyword
    object = Unknown.new(line_text)
    case
      #todo: GOSUB
      #todo: RETURN
      #todo: RESTORE
    when line_text[0..2] == 'REM': object = Remark.new(line_text[3..-1])
    when line_text[0..2] == 'DIM': object = Dim.new(line_text[3..-1])
    when line_text[0..2] == 'LET': object = Let.new(line_text[3..-1])
    when line_text[0..4] == 'INPUT': object = Input.new(line_text[5..-1])
    when line_text[0..1] == 'IF': object = If.new(line_text[2..-1])
    when line_text[0..4] == 'PRINT': object = Print.new(line_text[5..-1])
    when line_text[0..4] == 'GO TO': object = Goto.new(line_text[5..-1])
    when line_text[0..3] == 'GOTO': object = Goto.new(line_text[4..-1])
    when line_text[0..3] == 'READ': object = Read.new(line_text[4..-1])
    when line_text[0..3] == 'DATA': object = DataLine.new(line_text[4..-1])
    when line_text[0..3] == 'STOP': object = Stop.new
    when line_text[0..2] == 'END': object = End.new
    end
    [line_num, object]
  end

  def cmd_list
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      line_numbers.each { | line_num | puts "#{line_num} #{@program_lines[line_num]}" }
    else
      puts 'No program loaded'
    end
  end

  def cmd_run
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      # start with the first line number
      @current_line_number = line_numbers[0]
      @running = true
      while @running
        # pick the next line number
        index = line_numbers.index(@current_line_number) + 1
        @next_line_number = line_numbers[index]
        @program_lines[@current_line_number].execute(self)
        # go to the next line number (which may have been changed by execute() )
        if @next_line_number != nil then
          if line_numbers.index(@next_line_number) then
            @current_line_number = @next_line_number
          else
	    puts "Line number #{@next_line_number} not found"
          end
	else
          @running = false
        end
      end
    else
      puts 'No program loaded'
    end
  end

  def cmd_load(filename)
    filename.sub!(/^\s+/, '')
    if filename.size > 0 then
      begin
        File.open(filename, 'r') do | file |
          program_lines = Hash.new
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
      rescue Errno::ENOENT
        puts "File '#{filename}' not found"
      end
    else
      puts "Filename not specified"
    end
  end

  def cmd_save(filename)
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      filename.sub!(/^\s+/, '')
      if filename.size > 0 then
        begin
          File.open(filename, 'w') do | file |
            line_numbers.each { | line_num | file.puts "#{line_num} #{@program_lines[line_num]}" }
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
  
  def stop
    @running = false
    puts "STOP in line #{@current_line_number}"
  end
  
  def set_next_line(number)
    @next_line_number = number.to_i
  end
  
  def get_value(name)
    @variables[name]
  end
  
  def set_value(name, value)
    if @variables.has_key?(name) then
      @variables[name] = value
    else
      print "Unknown variable #{name} in line #{@current_line_number}\n"
    end
  end
  
  def print_handler
    @printer
  end
  
  def store_data(value)
    @data_store << value
  end
  
  def read_data
    if @data_index < @data_store.size then
      @data_index += 1
      @data_store[@data_index - 1]
    else
      nil
    end
  end

  def go
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
        case 
        when cmd == 'LIST': cmd_list
        when cmd == 'RUN': cmd_run
        when cmd[0..3] == 'LOAD': cmd_load(cmd[4..-1])
        when cmd[0..3] == 'SAVE': cmd_save(cmd[4..-1])
        when cmd == 'EXIT': done = true
        else print "Unknown command #{cmd}\n"
        end
        need_prompt = true
      end
    end
  end
end

interpreter = Interpreter.new
interpreter.go
