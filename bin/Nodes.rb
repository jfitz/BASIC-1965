class Node
  @@counter = 1
  
  def initialize(token)
    @token = token
    @parent = nil
    @precedence = 10
    @right = nil
    @id = @@counter
    @@counter += 1
  end
  
  def token
    @token
  end
  
  def precedence
    @precedence
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
  
  def rightmost
    @right != nil ? @right.rightmost : self
  end
  
  def left
    nil
  end
  
  def set_right(node)
    node.set_parent(self) if node != nil
    @right = node
  end
  
  def right
    @right
  end
  
  def id
    @id
  end

  def infix_string
    to_s
  end
    
  def to_s
    @token
  end
  
  def find_place(node)
    current_node = rightmost
    while current_node.parent != nil && current_node.parent.precedence >= node.precedence
      current_node = current_node.parent
    end
    current_node
  end
  
  def insert_node(tree)
    @parent = tree
    @right = @parent.right
    @right.set_parent(self) if @right != nil
    @parent.set_right(self)
  end
  
  def dump
    result = Array.new
    result << @id.to_s + ':' + self.class.name + ' Value:' + @token + ' Precedence:' + @precedence.to_s + ' Right:' + (@right != nil ? @right.id.to_s : 'nil')
    result.concat(@right.dump) if @right != nil
    result
  end
end

class RootNode < Node
  def initialize
    super('root')
    @precedence = -2
  end
  
  def evaluate(interpreter)
    @right.evaluate(interpreter)
  end
  
  def infix_string
    result = ''
    result += @right.infix_string if @right != nil
    result
  end
end

class LeafNode < Node
  def initialize(token)
    super
    @list = Array.new
  end
  
  def list_count
    @list.size
  end
end

class UnaryNode < Node
  def initialize(token)
    super
    @precedence = 0
  end
  
  def infix_string
    result = ''
    result += @token
    result += @right.infix_string if @right != nil
    result
  end
end

class ListNode < LeafNode
  def initialize
    super('(')
    @precedence = 8
  end
  
  def infix_string
    text_vals = @list.map { | item | item.infix_string }
    result = ''
    result += '('
    result += text_vals.join(',')
    result += ')'
    result
  end

  def insert_node(tree)
    super
    @precedence = -1
  end
  
  def push
    @list.push(@right) if @right != nil
    @right = nil
  end
  
  def seal
    @precedence = 8
  end
  
  def dump
    result = Array.new
    result << @id.to_s + ':' + self.class.name + ' Value:' + @token + ' Precedence:' + @precedence.to_s + ' List:' + (@list.map { | item | item.id.to_s }).join(',')
    @list.each do | item |
      result.concat(item.dump)
    end
    result
  end
end

class ListEndNode < LeafNode
  def initialize
    super(')')
    @precedence = 8
  end
  
  def insert_node(tree)
    # find opening parens
    current_node = tree.rightmost
    current_node = current_node.parent while current_node.parent != nil && current_node.precedence != -1
    if current_node.precedence == -1 then
      current_node.push
      current_node.seal
    else
      raise BASICException, "unmatched parens", caller
    end
  end
end

class BinaryNode < Node
  def initialize(token)
    super
    @precedence = 0
    @left = nil
  end
  
  def left
    @left
  end
  
  def infix_string
    result = ''
    result += @left.infix_string if @left != nil
    result += ' '
    result += @token
    result += ' '
    result += @right.infix_string if @right != nil
    result
  end
  
  def insert_node(tree)
    @parent = tree.parent
    @left = tree
    @left.set_parent(self)
    @parent.set_right(self)
  end
  
  def dump
    result = Array.new
    result << @id.to_s + ':' + self.class.name + ' Value:' + @token + ' Precedence:' + @precedence.to_s + ' Right:' + (@right != nil ? @right.id.to_s : 'nil') + ' Left:' + (@left != nil ? @left.id.to_s : 'nil')
    result.concat(@left.dump) if @left != nil
    result.concat(@right.dump) if @right != nil
    result
  end
end

