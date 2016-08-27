# abstract token
class AbstractToken
  def initialize
    @is_keyword = false
    @is_operator = false
    @is_separator = false
    @is_function = false
    @is_text_constant = false
    @is_numeric_constant = false
    @is_boolean_constant = false
    @is_user_function = false
    @is_variable = false
    @is_groupstart = false
    @is_groupend = false
  end

  def keyword?
    @is_keyword
  end

  def operator?
    @is_operator
  end

  def separator?
    @is_separator
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

  def groupstart?
    @is_groupstart
  end

  def groupend?
    @is_groupend
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

  def comparison?
    @operator == '<' || @operator == '<=' ||
      @operator == '>' || @operator == '>=' ||
      @operator == '=' || @operator == '<>'
  end

  def to_s
    @operator
  end
end

# group start token
class GroupStartToken < AbstractToken
  attr_reader :start

  def initialize(text)
    @is_groupstart = true
    @start = text
  end

  def to_s
    @start
  end
end

# group end token
class GroupEndToken < AbstractToken
  attr_reader :ender

  def initialize(text)
    @is_groupend = true
    @ender = text
  end

  def to_s
    @ender
  end
end

# parameter separator token
class ParamSeparatorToken < AbstractToken
  attr_reader :separator

  def initialize(text)
    @is_separator = true
    @separator = text
  end

  def to_s
    @separator
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

  def value
    @text_constant[1..-2]
  end
end

# numeric constant token
class NumericConstantToken < AbstractToken
  attr_reader :numeric_constant

  def initialize(text)
    @is_numeric_constant = true
    @numeric_constant = text
  end

  def to_f
    @numeric_constant.to_f
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

  def eql?(other)
    @variable == other.variable
  end

  def ==(other)
    @variable == other.variable
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
  def initialize
  end

  def try(text)
    @token = ''
    @token += text.empty? ? '' : text[0]
  end

  def count
    @token.size
  end

  def token
    [InvalidToken.new(@token)]
  end
end

# accept characters to match item in list
class ListTokenizer
  def initialize(legals, class_name)
    @legals = legals
    @class = class_name
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

  def token
    [@class.new(@token)]
  end
end

# token reader for text constants
class TextTokenizer
  def try(text)
    @token = ''
    /\A".*?"/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [TextConstantToken.new(@token)]
  end
end

# token reader for numeric constants
class NumberTokenizer
  def try(text)
    @token = ''
    /\A\d+/.match(text) { |m| @token = m[0] }
    /\A\d+\./.match(text) { |m| @token = m[0] }
    /\A\d+E[+-]?\d+/.match(text) { |m| @token = m[0] }
    /\A\d+\.E[+-]?\d+/.match(text) { |m| @token = m[0] }
    /\A\d+\.\d+(E[+-]?\d+)?/.match(text) { |m| @token = m[0] }
    /\A\.\d+(E[+-]?\d+)?/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [NumericConstantToken.new(@token)]
  end
end

# token reader for variables
class VariableTokenizer
  def try(text)
    @token = ''
    /\A[A-Z]/.match(text) { |m| @token = m[0] }
    /\A[A-Z]\d/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [VariableToken.new(@token)]
  end
end

# token reader for numeric constants
class InputNumberTokenizer
  def try(text)
    @token = ''
    /\A *([+-]?\d+) *,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.) *,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+E[+-]?) *\d+,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.E[+-]?\d+) *,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.\d+) *,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.\d+E[+-]?\d+) *,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\.\d+) *,/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\.\d+E[+-]?\d+) *,/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [NumericConstantToken.new(@token[0..-2]), ParamSeparatorToken.new(',')]
  end
end

# token reader for numeric constants
class InputENumberTokenizer
  def try(text)
    @token = ''
    /\A *([+-]?\d+) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+E[+-]?\d+) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.E[+-]?\d+) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.\d+) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\d+\.\d+E[+-]?\d+) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\.\d+) *\z/.match(text) { |m| @token = m[0] }
    /\A *([+-]?\.\d+E[+-]?\d+) *\z/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [NumericConstantToken.new(@token)]
  end
end

# token reader for empty entries
class InputEmptyTokenizer
  def try(text)
    @token = ''
    /\A *,/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [TextConstantToken.new('"' + @token[0..-2] + '"'), ParamSeparatorToken.new(',')]
  end
end

# token reader for empty entries
class InputEEmptyTokenizer
  def try(text)
    @token = ''
    /\A *\z/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [TextConstantToken.new('"' + @token + '"')]
  end
end
