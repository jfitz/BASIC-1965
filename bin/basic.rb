#!/usr/bin/ruby

class Node
  def initialize(token)
    @token = token
    @parent = nil
  end
  
  def token
    @token
  end
  
  def precedence
    10
  end
  
  def parent
    @parent
  end
  
  def set_parent(node)
    @parent = node
  end

  def topmost
    @parent != nil ? @parent.topmost : self
  end
  
  def set_left(node)
    node.set_parent(self) if node != nil
  end
  
  def left
    nil
  end
  
  def set_right(node)
    node.set_parent(self) if node != nil
  end
  
  def right
    nil
  end
  
  def infix_string
    @token
  end
end

class LeafNode < Node
  def initialize(token)
    super
  end
end

class BinaryNode < Node
  def initialize(token)
    super
    @precedence = 0
    @left = nil
    @right = nil
  end
  
  def precedence
    @precedence
  end

  def set_left(node)
    node.set_parent(self) if node != nil
    @left = node
  end
  
  def left
    @left
  end
  
  def set_right(node)
    node.set_parent(self)
    node.set_left(@right)
    @right = node
  end
  
  def right
    @right
  end
  
  def infix_string
    result = ''
    result += @left.infix_string if @left != nil
    result += @token
    result += @right.infix_string if @right != nil
    result
  end
end

class LineNumber
  def initialize(number)
    raise "'#{number}' is not a line number" if /^\d+$/ !~ number
    @line_number = number.to_i
  end
  
  def to_i
    @line_number
  end
  
  def to_s
    @line_number.to_s
  end
end

class NumericConstant < LeafNode
  def initialize(text)
    super
    case
    when text.class.to_s == 'Fixnum': @value = text
    when text =~ /^[+-]?\d+$/: @value = text.to_i
    when text.class.to_s == 'Float': @value = text
    when text =~ /^[+-]?\d+\.\d*$/: @value = text.to_f
    else raise "'#{text}' is not a number" 
    end
  end

  def value(interpreter)
    @value
  end
  
  def to_s
    @value.to_s
  end
  
  def to_formatted_s(interpreter)
    if @value < 0 then
      @value.to_s
    else
      ' ' + @value.to_s
    end
  end
end

class TextConstant
  def initialize(text)
    case
    when text =~ /^".*"$/: @value = text[1..-2]
    else raise "'#{text}' is not a text constant" 
    end
  end

  def value
    @value
  end
  
  def to_s
    "\"#{@value}\""
  end
  
  def to_formatted_s(interpreter)
    @value
  end
end

class ArithmeticOperator < BinaryNode
  @@operators = { '+' => 1, '-' => 1, '*' => 2, '/' => 2 }
  def initialize(text)
    super
    raise "'#{text}' is not an operator" if !@@operators.has_key?(text)
    @op = text
    @precedence = @@operators[@op]
  end
  
  def evaluate(a, b, interpreter)
    case
    when @op == '+': add(a.value(interpreter), b.value(interpreter))
    when @op == '-': subtract(a.value(interpreter), b.value(interpreter))
    when @op == '*': multiply(a.value(interpreter), b.value(interpreter))
    when @op == '/': divide(a.value(interpreter), b.value(interpreter))
    end
  end

  def add(a, b)
    f = NumericConstant.new(a.to_f + b.to_f)
    i = NumericConstant.new((a + b).to_i)
    (f.value(nil) - i.value(nil)) < 1e-8 ? i : f
  end
  
  def subtract(a, b)
    f = NumericConstant.new(a.to_f - b.to_f)
    i = NumericConstant.new((a - b).to_i)
    (f.value(nil) - i.value(nil)) < 1e-8 ? i : f
  end
  
  def multiply(a, b)
    f = NumericConstant.new(a.to_f * b.to_f)
    i = NumericConstant.new((a * b).to_i)
    (f.value(nil) - i.value(nil)) < 1e-8 ? i : f
  end
  
  def divide(a, b)
    f = NumericConstant.new(a.to_f / b.to_f)
    i = NumericConstant.new((a / b).to_i)
    (f.value(nil) - i.value(nil)) < 1e-8 ? i : f
  end
  
  def to_s
    @op
  end
end

class BooleanOperator
  @@valid_operators = [ '=', '<', '>', '>=', '<=', '<>' ]
  def initialize(text)
    raise "'#{text}' is not a valid boolean operator" if !@@valid_operators.include?(text)
    @value = text
  end
  
  def to_s
    @value
  end
end

class VariableName < LeafNode
  def initialize(text)
    super
    raise "'#{text}' is not a variable name" if text !~ /^[A-Z][0-9]?$/
    @var_name = text
  end
  
  def to_s
    @var_name
  end
end

class NumericExpression < LeafNode
  def initialize(text)
    super
    @variable = nil
    @value = nil
    begin
      @variable = VariableName.new(text)
    rescue Exception => message
      @value = NumericConstant.new(text)
    end
  end
  
  def value(interpreter)
    if !@variable.nil? then
      interpreter.get_value(@variable)
    else
      @value.value(interpreter)
    end
  end
  
  def to_s
    if !@variable.nil? then
      @variable.to_s
    else
      @value.to_s
    end
  end
  
  def to_formatted_s(interpreter)
    if !@variable.nil? then
      ' ' + interpreter.get_value(@variable).to_s
    else
      @value.value
    end
  end
end

class ArithmeticExpression
  private
  def split_args(text)
    args = Array.new
    current_arg = String.new
    (0..text.size-1).each do | i |
      c = text[i,1]
      if [',', ';'].include?(c) then
        args << current_arg
        current_arg = String.new
        args << c
      else
        current_arg += c
      end
    end
    args << current_arg if current_arg.size > 0
    
    args
  end
  
  public
  def initialize(text)
    # parse into items and arith operators
    tokens = text.split(/([\+\-\*\/])/)
    # convert from list of tokens into a tree
    
    list = Array.new
    tokens.each do | token |
      begin
        list << NumericExpression.new(token)
      rescue
        begin
          list << ArithmeticOperator.new(token)
        rescue
          raise "'#{token}' is not a value or operator"
        end
      end
    end

    level = 0

    list.each do | token |
      case
      when token.class.to_s == 'NumericExpression': level += 1
      when token.class.to_s == 'ArithmeticOperator': level -= 1
      end
    end

    level -= 1 if list.size > 0

    if level != 0 then
      puts "LIST ' #{list.join('-')} ' ERROR"
    end
    
    current_node = nil
    stack = Array.new

    list.each do | token |
      case
      when token.class.to_s == 'NumericExpression':
        child = token
        if (current_node == nil) then
          current_node = child
        else
          if child.precedence >= current_node.precedence then
            current_node.set_right(child)
#            current_node = child
        else
            puts "DBG:"
            current_node = current_node.parent while current_node.parent != nil && current_node.parent.precedence > child.precedence
            child.set_left(current_node)
            current_node = child
          end
        end
      when token.class.to_s == 'ArithmeticOperator':
        child = token
        if (current_node == nil) then
          current_node = child
        else
          if child.precedence >= current_node.precedence then
            current_node.set_right(child)
            current_node = child
          else
            current_node = current_node.parent while current_node.parent != nil && current_node.parent.precedence > child.precedence
            child.set_left(current_node)
            current_node = child
          end
        end
      end
    end
    @root_node = current_node.topmost
  end
  
  private
  def evaluate(current_node, interpreter)
    result = case
      when current_node.class.to_s == 'ArithmeticOperator':
        a = evaluate(current_node.left, interpreter)
        b = evaluate(current_node.right, interpreter)
        current_node.evaluate(a, b, interpreter)
      when current_node.class.to_s == 'NumericExpression': current_node
      else NumericConstant.new(0)
    end
  end

  def postfix_string(current_node)
    result = ''
    result += postfix_string(current_node.left) + ' ' if current_node.left != nil
    result += postfix_string(current_node.right) + ' ' if current_node.right != nil
    result += current_node.token.to_s

    result
  end

  public
  def value(interpreter)
    x = evaluate(@root_node, interpreter)
    rv = case
    when x.class.to_s == 'FixNum': x
    when x.class.to_s == 'NumericConstant': x.value(interpreter)
    when x.class.to_s == 'NumericExpression': x.value(interpreter)
    else throw "Unknown data type #{x.class}"
    end
    rv
  end
  
  def to_s
    @root_node.infix_string
  end

  def to_postfix_s
    postfix_string(@root_node)
  end

  def postfix_string(current_node)
    result = ''
    result += postfix_string(current_node.left) + ' ' if current_node.left != nil
    result += postfix_string(current_node.right) + ' ' if current_node.right != nil
    result += current_node.token.to_s
    result
  end
end

class PrintableExpression
  def initialize(text)
    @numeric_expression = nil
    @text_constant = nil
    begin
      @text_constant = TextConstant.new(text)
    rescue Exception => message
      @numeric_expression = NumericExpression.new(text)
    end
  end
  
  def to_s
    if !@numeric_expression.nil? then
      @numeric_expression.to_s
    else
      @text_constant.to_s
    end
  end
  
  def to_formatted_s(interpreter)
    if !@numeric_expression.nil? then
      @numeric_expression.to_formatted_s(interpreter)
    else
      @text_constant.to_formatted_s(interpreter)
    end
  end
end

class Assignment
  def initialize(text)
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    raise "'#{text}' is not a valid assignment" if parts.size != 2
    @target = VariableName.new(parts[0])
    @expression = ArithmeticExpression.new(parts[1])
    #@expression = NumericExpression.new(parts[1])
  end

  def target
    @target
  end
  
  def value(interpreter)
    @expression.value(interpreter)
  end
  
  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end

  def to_postfix_s
    @expression.to_postfix_s
  end
end

class BooleanExpression
  def initialize(text)
    parts = text.split(/\s*([=<>]+)\s*/)
    raise "'#{text}' is not a boolean expression" if parts.size != 3
    @a = NumericExpression.new(parts[0])
    @operator = BooleanOperator.new(parts[1])
    @b = NumericExpression.new(parts[2])
  end
  
  def value(interpreter)
    case
    when @operator.to_s == '=': @a.value(interpreter) == @b.value(interpreter)
    when @operator.to_s == '<>': @a.value(interpreter) != @b.value(interpreter)
    when @operator.to_s == '<': @a.value(interpreter) < @b.value(interpreter)
    when @operator.to_s == '>': @a.value(interpreter) > @b.value(interpreter)
    when @operator.to_s == '<=': @a.value(interpreter) <= @b.value(interpreter)
    when @operator.to_s == '>=': @a.value(interpreter) >= @b.value(interpreter)
    end
  end
  
  def to_s
    @a.to_s + ' ' + @operator.to_s + ' ' + @b.to_s
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

class AbstractLine
  def initialize(keyword)
    @keyword = keyword
    @errors = Array.new
  end
  
  def errors
    @errors
  end
  
  def execute(interpreter)
    if (@errors.size == 0) then
      execute_cmd(interpreter)
    else
      @errors.each { | error | puts "line #{interpreter.current_line_number}: #{error}" }
    end
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
  
  def execute_cmd(interpreter)
    0
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

  def execute_cmd(interpreter)
    0
  end
end

class Let < AbstractLine
  def initialize(line)
    super('LET')
    begin
      @expression = Assignment.new(line.gsub(/ /, ''))
    rescue Exception => message
      @errors << message
      @expression = line
    end
  end
  
  def to_s
    @keyword + ' ' + @expression.to_s
  end
  
  def execute_cmd(interpreter)
    interpreter.set_value(@expression.target, @expression.value(interpreter))
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
      begin
        var_name = VariableName.new(text_item)
      rescue
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  private
  def zip(names, values)
    raise "Unequal lists" if names.size != values.size
    results = Array.new
    (0...names.size).each do | i |
      results << { 'name' => names[i], 'value' => values[i] }
    end    
    results
  end
  
  public
  def execute_cmd(interpreter)
    values = Array.new
    while values.size < @variable_list.size do
      print '?'
      input_line = gets
      input_line.chomp!
      text_values = input_line.split(/,/)
      text_values.each do | value |
        begin
          var_value = NumericConstant.new(value)
          values << var_value.value
        rescue
          puts "Invalid value #{value}"
        end
      end
    end
    name_value_pairs = zip(@variable_list, values)
    name_value_pairs.each do | hash |
      interpreter.set_value(hash['name'], hash['value'])
    end
  end
end

class If < AbstractLine
  def initialize(line)
    super('IF')
    parts = line.gsub(/ /, '').split(/\s*THEN\s*/)
    begin
      @boolean_expression = BooleanExpression.new(parts[0])
    rescue Exception => message
      @errors << message
      @boolean_expression = parts[0]
    end
    @destination = LineNumber.new(parts[1])
  end
  
  def to_s
    @keyword + ' ' + @boolean_expression.to_s + ' THEN ' + @destination.to_s
  end
  
  def execute_cmd(interpreter)
    interpreter.set_next_line(@destination.to_i) if @boolean_expression.value(interpreter)
  end
end

class Print < AbstractLine
  private
  def split_args(text)
    args = Array.new
    current_arg = String.new
    (0..text.size-1).each do | i |
      c = text[i,1]
      if [',', ';'].include?(c) then
        args << current_arg
        current_arg = String.new
        args << c
      else
        current_arg += c
      end
    end
    args << current_arg if current_arg.size > 0
    
    args
  end
  
  public
  def initialize(line)
    super('PRINT')
    # todo: allow semicolon as separator
    # todo: keep separators for spacing
    # todo: allow quoted text
    # todo: allow subscripted variables
    # todo: allow expressions
    item_list = split_args(line.sub(/^ +/, ''))
    # variable/constant, [separator, variable/constant]... [separator]
    @print_item_list = Array.new
    var_name = nil
    item_list.each do | print_item |
      if print_item =~ /[,;]/ then
        @print_item_list << { 'variable' => var_name, 'carriage' => print_item }
        var_name = nil
      else
        begin
          print_item.sub!(/^ +/, '')
          print_item.sub!(/ +$/, '')
          var_name = PrintableExpression.new(print_item)
        rescue
          @errors << "Invalid expression #{print_item}"
          var_name = VariableName.new('')
        end
      end
    end
    @print_item_list << { 'variable' => var_name, 'carriage' => '' }
  end
  
  def to_s
    varnames = Array.new
    @print_item_list.each { | print_item | varnames << print_item['variable'] }
    @keyword + ' ' + varnames.join(', ')
  end
  
  def execute_cmd(interpreter)
    printer = interpreter.print_handler
    @print_item_list.each do | print_item |
      name = print_item['variable']
      printer.print_item name.to_formatted_s(interpreter)
      separator = print_item['carriage']
      case
      when separator == ';': printer.null
      when separator == ',': printer.tab
      else printer.newline
      end
    end
  end
end

class Goto < AbstractLine
  def initialize(line)
    super('GO TO')
    destination = line.sub(/ /, '')
    begin
      @destination = LineNumber.new(destination)
    rescue
      @errors << "Invalid line number #{destination}"
    end
  end
  
  def to_s
    @keyword + ' ' + @destination.to_s
  end
  
  def execute_cmd(interpreter)
    next_line_number = @destination.to_i
    interpreter.set_next_line(next_line_number)
  end
end

class Gosub < AbstractLine
  def initialize(line)
    super('GOSUB')
    destination = line.sub(/ /, '')
    begin
      @destination = LineNumber.new(destination)
    rescue
      @errors << "Invalid line number #{destination}"
    end
  end
  
  def to_s
    @keyword + ' ' + @destination.to_s
  end
  
  def execute_cmd(interpreter)
    interpreter.push_return(interpreter.get_next_line)
    next_line_number = @destination.to_i
    interpreter.set_next_line(next_line_number)
  end
end

class Return < AbstractLine
  def initialize
    super('RETURN')
  end
  
  def to_s
    @keyword
  end
  
  def execute_cmd(interpreter)
    interpreter.set_next_line(interpreter.pop_return)
  end
end

class ForNextControl
  def initialize(control_variable_name, loop_start_number, start_value, end_value, step_value)
    @control_variable_name = control_variable_name
    @loop_start_number = loop_start_number
    @start_value = start_value
    @end_value = end_value
    @step_value = step_value
    @current_value = start_value
  end
  
  def bump_control_variable(interpreter)
    @current_value = @current_value + @step_value
    interpreter.set_value(@control_variable_name, @current_value)
  end
  
  def control_variable_name
    @control_variable_name
  end
  
  def end_value
    @end_value
  end
  
  def loop_start_number
    @loop_start_number
  end
  
  def terminated?(interpreter)
    case
    when @step_value > 0: (interpreter.get_value(@control_variable_name) >= end_value)
    when @step_value < 0: (interpreter.get_value(@control_variable_name) <= end_value)
    else true
    end
  end
end

class ForLine < AbstractLine
  def initialize(line)
    super('FOR')
    # parse control variable, "=", numeric_expression, "TO", numeric_expression, "STEP", numeric_expression
    parts = line.gsub(/ /, '').split('=', 2)
    raise "Syntax error" if parts.size != 2
    begin
      @control_variable = VariableName.new(parts[0])
    rescue Exception => message
      @errors << message
    end
    parts = parts[1].split('TO', 2)
    raise "Syntax error" if parts.size != 2
    @start_value = NumericExpression.new(parts[0])
    parts = parts[1].split('STEP', 2)
    @end_value = NumericExpression.new(parts[0])
    @step_value = parts.size > 1 ? NumericExpression.new(parts[1]) : NumericConstant.new(1)
  end
  
  def to_s
    @keyword + ' ' + @control_variable.to_s + ' = ' + @start_value.to_s + ' TO ' + @end_value.to_s
  end
  
  def execute_cmd(interpreter)
    from_value = @start_value.value(interpreter)
    interpreter.set_value(@control_variable, from_value)
    to_value = @end_value.value(interpreter)
    step_value = @step_value.value(interpreter)
    interpreter.push_fornext(ForNextControl.new(@control_variable.to_s, interpreter.get_next_line, from_value, to_value, step_value))
  end
end

class NextLine < AbstractLine
  def initialize(line)
    super('NEXT')
    # parse control variable
    @control_variable = nil
    begin
      @control_variable = VariableName.new(line.gsub(/ /, ''))
    rescue Exception => message
      @errors << message
      @boolean_expression = line
    end
  end
  
  def to_s
    @keyword + ' ' + @control_variable.to_s
  end
  
  def execute_cmd(interpreter)
    fornext_control = interpreter.pop_fornext #may raise "NEXT without FOR"
    # verify top item matches control variable
    x = fornext_control.control_variable_name
    if x != @control_variable.to_s then
      raise "NEXT #{@control_variable} does not match FOR #{x}"
    end
    # check control variable value
    # if matches end value, stop here
    return if fornext_control.terminated?(interpreter)
    # set next line from top item
    interpreter.set_next_line(fornext_control.loop_start_number)
    # change control variable value
    fornext_control.bump_control_variable(interpreter)
    interpreter.push_fornext(fornext_control)
  end
end

class Read < AbstractLine
  def initialize(line)
    super('READ')
    # todo: allow subscripted variable
    @variable_list = line.gsub(/ /, '').split(',')
    # variable [comma, variable]...
    @variable_list.each do | text_item |
      begin
        var_name = VariableName.new(text_item)
      rescue
        @errors << "Invalid variable #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' ' + @variable_list.join(', ')
  end
  
  def execute_cmd(interpreter)
    @variable_list.each do | text_item |
      var_name = VariableName.new(text_item)
      interpreter.set_value(var_name, interpreter.read_data)
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
        NumericConstant.new(text_item)
      rescue
        @errors << "Invalid value #{text_item}"
      end
    end
  end
  
  def to_s
    @keyword + ' '+ @data_list.join(', ')
  end
  
  def execute_cmd(interpreter)
    @data_list.each do | text_item |
      x = NumericConstant.new(text_item)
      interpreter.store_data(x.value(interpreter))
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
  
  def execute_cmd(interpreter)
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
  
  def execute_cmd(interpreter)
    interpreter.stop
  end
end

class Interpreter
  def initialize
    @running = false
    @variables = Hash.new
    ('A'..'Z').each do | name |
      @variables[name] = NumericConstant.new('0')
      #('0'..'9').each { | number | @variables["#{name}#{number}"] = 0 }
    end
    @data_store = Array.new
    @data_index = 0
    @printer = PrintHandler.new
    @return_stack = Array.new
    @fornext_stack = Array.new
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
    when line_text[0..2] == 'LET': object = Let.new(line_text[3..-1])
    when line_text[0..4] == 'INPUT': object = Input.new(line_text[5..-1])
    when line_text[0..1] == 'IF': object = If.new(line_text[2..-1])
    when line_text[0..4] == 'PRINT': object = Print.new(line_text[5..-1])
    when line_text[0..4] == 'GO TO': object = Goto.new(line_text[5..-1])
    when line_text[0..3] == 'GOTO': object = Goto.new(line_text[4..-1])
    when line_text[0..4] == 'GOSUB': object = Gosub.new(line_text[5..-1])
    when line_text[0..2] == 'FOR': object = ForLine.new(line_text[3..-1])
    when line_text[0..3] == 'NEXT': object = NextLine.new(line_text[4..-1])
    when line_text[0..5] == 'RETURN': object = Return.new
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
      line_numbers.each { | line_num | puts "#{line_num.to_s} #{@program_lines[line_num]}" }
    else
      puts 'No program loaded'
    end
  end
  
  private
  def verify_next_line_number(line_numbers, next_line_number)
    if next_line_number == nil then
      raise "Program terminated without END"
    end
    if !line_numbers.include?(next_line_number) then
      raise "Line number #{next_line_number} not found"
    end
    next_line_number
  end
  
  public
  def cmd_run
    line_numbers = @program_lines.keys.sort
    if line_numbers.size > 0 then
      # start with the first line number
      @current_line_number = line_numbers[0]
      @running = true
      while @running
        # pick the next line number
        @next_line_number = line_numbers[line_numbers.index(@current_line_number) + 1]
        begin
          @program_lines[@current_line_number].execute(self)
          # set the next line number (which may have been changed by execute() )
          @current_line_number = verify_next_line_number(line_numbers, @next_line_number)
        rescue Exception => message
          puts "#{message} in line #{current_line_number}"
          @running = false
        end
      end
    else
      puts 'No program loaded'
    end
  end

  def cmd_new
    @program_lines = Hash.new
  end
  
  def cmd_load(filename)
    filename.sub!(/^\s+/, '')
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
    @variables[variable.to_s]
  end
  
  def set_value(variable, value)
    if @variables.has_key?(variable.to_s) then
      @variables[variable.to_s] = value
    else
      print "Unknown variable #{variable} in line #{@current_line_number}\n"
    end
  end
  
  def print_handler
    @printer
  end
  
  def push_return(destination)
    @return_stack.push(destination)
  end
  
  def pop_return
    raise "RETURN without GOSUB" if @return_stack.size == 0
    @return_stack.pop
  end
  
  def push_fornext(fornext)
    @fornext_stack.push(fornext)
  end
  
  def pop_fornext
    raise "NEXT without FOR" if @fornext_stack.size == 0
    @fornext_stack.pop
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
        # todo: add PRINT, LET
        case 
        when cmd == 'LIST': cmd_list
        when cmd == 'RUN': cmd_run
        when cmd == 'NEW': cmd_new
        when cmd[0..3] == 'LOAD': cmd_load(cmd[4..-1])
        when cmd[0..3] == 'SAVE': cmd_save(cmd[4..-1])
        when cmd == 'EXIT': done = true
        else print "Unknown command #{cmd}\n"
        end
        need_prompt = true
      end
    end
    puts
    puts "BASIC-1965 ended"
  end
  
  def load_and_run(filename)
    puts "BASIC-1965 interpreter version -1"
    puts
    @program_lines = Hash.new
    if cmd_load(filename) then
      cmd_run
    end
    puts
    puts "BASIC-1965 ended"
  end
end

interpreter = Interpreter.new
if ARGV.size > 0 then
  filename = ARGV[0]
  until ARGV.empty? do ARGV.shift end
  # set_trace_func proc { | event, file, line, id, binding, classname |
  #  puts "#{classname}.#{id} #{file}:#{line} #{event}" if !['IO', 'Kernel', 'Module', 'Fixnum',  'NameError', 'Exception', 'NoMethodError', 'Symbol', 'String', 'NilClass', 'Hash'].include? (classname.to_s)
  # }
  interpreter.load_and_run(filename)
else
  interpreter.go
end
