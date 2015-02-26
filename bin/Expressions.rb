class VariableRef < LeafNode
  def initialize(text)
    super
    regex = Regexp.new('^[A-Z]\d?$')
    # regex = Regexp.new('^[A-Z]\d?(\(\d{1,2}\))?$')
    raise(BASICException, "'#{text}' is not a variable name", caller) if regex !~ text
    @var_name = text
    @precedence = 9
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
      @variable = VariableRef.new(text)
    rescue BASICException => message
      @value = NumericConstant.new(text)
    end
  end
  
  def evaluate(interpreter)
    if !@variable.nil? then
      interpreter.get_value(@variable)
    else
      @value.evaluate(interpreter)
    end
  end
  
  def to_s
    @variable.nil? ? @value.to_s : @variable.to_s
  end
  
  def six_digits(value)
    decimals = 5 - (value != 0 ? Math.log(value.abs,10).to_i : 0)
    value.round(decimals)
  end
  
  def to_formatted_s(interpreter)
    vvalue = interpreter.get_value(@variable)
    formatted = vvalue.class.to_s == 'Float' ? six_digits(vvalue).to_s : vvalue.to_s
    @variable.nil? ? @value.value : ' ' + formatted
  end
end

class Function < LeafNode
  @@valid_names = [ 'INT', 'RND', 'EXP', 'LOG' ]
  def initialize(text)
    raise(BASICException, "'#{text}' is not a valid function", caller) if !@@valid_names.include?(text)
    super
    @name = text
    @precedence = 9
  end

  def evaluate(interpreter)
    case @name
    when 'INT'
      if @right.list_count == 1 then
        (@right.evaluate_n(interpreter,0)).to_i
      else
        raise(BASICException, "Wrong number of arguments", caller)
      end
    when 'RND'
      if @right.list_count == 1 then
        upper_bound = (@right.evaluate_n(interpreter,0)).truncate.to_f
        upper_bound = 1 if upper_bound <= 0
        $randomizer.rand(upper_bound)
      else
        raise(BASICException, "Wrong number of arguments", caller)
      end
    when 'EXP'
      if @right.list_count == 1 then
        Math.exp(@right.evaluate_n(interpreter,0))
      else
        raise(BASICException, "Wrong number of arguments", caller)
      end
    when 'LOG'
      if @right.list_count == 1 then
        vvalue = @right.evaluate_n(interpreter,0)
        vvalue > 0 ? Math.log(vvalue) : 0
      else
        raise(BASICException, "Wrong number of arguments", caller)
      end
    end
  end

  def to_s
    @name + @right.to_s
  end
  
  def to_formatted_s(interpreter)
    @name + @right.to_formatted_s(interpreter)
  end
end

class ArithmeticExpression
  def initialize(text)
    # parse into items and arith operators
    tokens = text.split(/([\+\-\*\/\(\)\^])/)
    # puts "DBG: tokens=#{tokens.join(', ')}"
    
    # convert from list of tokens into a tree
    list = Array.new
    last_was_operand = false
    tokens.each do | token |
      # puts "DBG: token=#{token}"
      if token.size > 0 then
        begin
          list << Function.new(token)
          rescue BASICException
          begin
            list << NumericExpression.new(token)
            last_was_operand = true
          rescue BASICException
            begin
              if last_was_operand then
                list << BinaryOperator.new(token)
              else
                list << UnaryOperator.new(token)
              end
              last_was_operand = false
            rescue BASICException
              begin
                list << ListOperator.new(token)
                last_was_operand = false
              rescue BASICException
                begin
                  list << ListEndOperator.new(token)
                  last_was_operand = true
                rescue
                  raise BASICException, "'#{token}' is not a value or operator", caller
                end
              end
            end
          end
        end
      end
    end

    node_tree = RootNode.new
    list.each do | new_node |
      # puts "DBG: #{infix_string(node_tree)}"
      place_node = node_tree.find_place(new_node)
      new_node.insert_node(place_node)
    end
    @root_node = node_tree.topmost
  end

  private
  def postfix_string(current_node)
    result = ''
    result += postfix_string(current_node.left) + ' ' if current_node.left != nil
    result += postfix_string(current_node.right) + ' ' if current_node.right != nil
    result += current_node.to_s
  end
  
  def infix_string(current_node)
    result = ''
    result += infix_string(current_node.left) if current_node.left != nil
    result += current_node.to_s
    result += infix_string(current_node.right) if current_node.right != nil
    result
  end
  
  public
  def dump
    puts infix_string(@root_node)
    puts @root_node.dump
  end
  
  public
  def evaluate(interpreter)
    x = @root_node.evaluate(interpreter)
    case x.class.to_s
    when 'Fixnum'
        x
    when 'Float'
        x
    when 'NumericConstant'
        x.evaluate(interpreter)
    when 'NumericExpression'
        x.evaluate(interpreter)
    else throw "Unknown data type #{x.class}"
    end
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
  end
end

class PrintableExpression
  def initialize(text)
    @numeric_expression = nil
    @text_constant = nil
    begin
      @text_constant = TextConstant.new(text)
    rescue BASICException => message
      @numeric_expression = ArithmeticExpression.new(text)
    end
  end
  
  def to_s
    if @numeric_expression.nil? then
      @text_constant.to_s
    else
      @numeric_expression.to_s
    end
  end
  
  def six_digits(value)
    decimals = 5 - (value != 0 ? Math.log(value.abs,10).to_i : 0)
    value.round(decimals)
  end
  
  def to_formatted_s(interpreter)
    if @numeric_expression.nil? then
      @text_constant.to_formatted_s(interpreter)
    else
      vvalue = @numeric_expression.evaluate(interpreter)
      formatted = vvalue.class.to_s == 'Float' ? six_digits(vvalue).to_s : vvalue.to_s
      vvalue < 0 ? formatted : ' ' + formatted
    end
  end
end

class BooleanExpression
  def initialize(text)
    parts = text.split(/\s*([=<>]+)\s*/)
    raise(BASICException, "'#{text}' is not a boolean expression", caller) if parts.size != 3
    @a = ArithmeticExpression.new(parts[0])
    @operator = BooleanOperator.new(parts[1])
    @b = ArithmeticExpression.new(parts[2])
  end
  
  def evaluate(interpreter)
    case @operator.to_s
    when '='
        @a.evaluate(interpreter) == @b.evaluate(interpreter)
    when '<>'
        @a.evaluate(interpreter) != @b.evaluate(interpreter)
    when '<'
        @a.evaluate(interpreter) < @b.evaluate(interpreter)
    when '>'
        @a.evaluate(interpreter) > @b.evaluate(interpreter)
    when '<='
        @a.evaluate(interpreter) <= @b.evaluate(interpreter)
    when '>='
        @a.evaluate(interpreter) >= @b.evaluate(interpreter)
    end
  end
  
  def to_s
    @a.to_s + ' ' + @operator.to_s + ' ' + @b.to_s
  end
end

class Assignment
  def initialize(text)
    # parse into variable, '=', expression
    parts = text.split('=', 2)
    raise(BASICException, "'#{text}' is not a valid assignment", caller) if parts.size != 2
    @target = VariableRef.new(parts[0])
    @expression = ArithmeticExpression.new(parts[1])
  end

  def target
    @target
  end
  
  def value(interpreter)
    @expression.evaluate(interpreter)
  end
  
  def to_s
    @target.to_s + ' = ' + @expression.to_s
  end

  def to_postfix_s
    @expression.to_postfix_s
  end
  
  def dump
    @expression.dump
  end
end

