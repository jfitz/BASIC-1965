# abstract token
class AbstractToken
  def initialize
    @is_keyword = false
    @is_operator = false
    @is_function = false
    @is_text_constant = false
    @is_numeric_constant = false
    @is_boolean_constant = false
    @is_user_function = false
    @is_variable = false
  end

  def keyword?
    @is_keyword
  end

  def operator?
    @is_operator
  end

  def function?
    @is_function
  end

  def text_constant?
    @is_text_constant
  end

  def numeric_constant?
    @is_numeric_constant
  end

  def boolean_constant?
    @is_boolean_constant
  end

  def user_function?
    @is_user_function
  end

  def variable?
    @is_variable
  end

  def operand?
    @is_function || @is_text_constant || @is_numeric_constant ||
      @is_boolean_constant || @is_user_function || @is_variable
  end
end

# invalid token
class InvalidToken < AbstractToken
  attr_reader :text

  def initialize(text)
    @text = text
  end

  def to_s
    @text
  end
end

# keyword token
class KeywordToken < AbstractToken
  attr_reader :keyword

  def initialize(text)
    @is_keyword = true
    @keyword = text
  end

  def to?
    @keyword == 'TO'
  end

  def step?
    @keyword == 'STEP'
  end

  def isthen?
    @keyword == 'THEN'
  end

  def to_s
    @keyword
  end
end

# operator token
class OperatorToken < AbstractToken
  attr_reader :operator

  def initialize(text)
    @is_operator = true
    @operator = text
  end

  def equals?
    @operator == '='
  end

  def separator?
    @operator == ',' || @operator == ';'
  end

  def open?
    @operator == '('
  end

  def close?
    @operator == ')'
  end

  def comparison?
    @operator == '<' || @operator == '<=' ||
      @operator == '>' || @operator == '>=' ||
      @operator == '=' || @operator == '<>'
  end

  def to_s
    @operator
  end
end

# function token
class FunctionToken < AbstractToken
  attr_reader :function

  def initialize(text)
    @is_function = true
    @function = text
  end

  def to_s
    @function
  end
end

# text constant token
class TextConstantToken < AbstractToken
  attr_reader :text_constant

  def initialize(text)
    @is_text_constant = true
    @text_constant = text
  end

  def to_s
    @text_constant
  end
end

# numeric constant token
class NumericConstantToken < AbstractToken
  attr_reader :numeric_constant

  def initialize(text)
    @is_numeric_constant = true
    @numeric_constant = text
  end

  def to_i
    @numeric_constant.to_f.to_i
  end

  def to_s
    @numeric_constant.to_s
  end
end

# boolean constant token
class BooleanConstantToken < AbstractToken
  attr_reader :boolean_constant

  def initialize(text)
    @is_boolean_constant = true
    @boolean_constant = text
  end

  def to_s
    @boolean_constant.to_s
  end
end

# user function token
class UserFunctionToken < AbstractToken
  attr_reader :user_function

  def initialize(text)
    @is_user_function = true
    @user_function = text
  end

  def to_s
    @user_function.to_s
  end
end

# variable token
class VariableToken < AbstractToken
  attr_reader :variable

  def initialize(text)
    @is_variable = true
    @variable = text
  end

  def hash
    @variable.hash
  end

  def to_s
    @variable
  end
end

# accept any characters
class InvalidTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    @token += text.empty? ? '' : text[0]
  end

  def count
    @token.size
  end
end

# accept characters to match item in list
class ListTokenizer
  attr_reader :token

  def initialize(legals)
    @legals = legals
  end

  def try(text)
    @token = ''
    @legals.each do |legal|
      @token = legal if text.start_with?(legal) && legal.size > @token.size
    end
  end

  def count
    @token.size
  end
end

# token reader for text constants
class TextTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    /\A".*?"/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end
end

# token reader for numeric constants
class NumberTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    /\A\d+(\.\d+)?(E[+-]?\d+)?/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end
end

# token reader for variables
class VariableTokenizer
  attr_reader :token

  def initialize
  end

  def try(text)
    @token = ''
    /\A[A-Z]/.match(text) { |m| @token = m[0] }
    /\A[A-Z]\d/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end
end
