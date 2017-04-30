# abstract token
class AbstractToken
  def self.pretty_tokens(keywords, tokens)
    pretty_tokens = []

    keywords.each do |token|
      pretty_tokens << WhitespaceToken.new(' ')
      pretty_tokens << token
    end
    
    prev_open_parens = false
    prev_operand = false
    prev_operator = false
    prev_variable = false
    prev_2_operand = false
    tokens.each do |token|
      pretty_tokens << WhitespaceToken.new(' ') unless
        token.separator? ||
        (token.groupstart? && prev_variable) ||
        token.groupend? ||
        prev_open_parens ||
        (prev_operator && !prev_2_operand)
      pretty_tokens << token
      prev_open_parens = token.groupstart?
      prev_variable = token.variable? || token.function? ||
                      token.user_function?
      prev_2_operand = prev_operand
      prev_operand = token.operand? || token.groupend?
      prev_operator = token.operator?
    end

    pretty_tokens.map(&:to_s).join
  end

  def initialize(text)
    @text = text
    @is_break = false
    @is_whitespace = false
    @is_comment = false
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

  def eql?(other)
    @text == other.to_s
  end

  def ==(other)
    @text == other.to_s
  end

  def hash
    @text.hash
  end

  def to_s
    @text
  end

  def break?
    @is_break
  end

  def whitespace?
    @is_whitespace
  end

  def comment?
    @is_comment
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
  def initialize(text)
    super
  end
end

# break token
class BreakToken < AbstractToken
  def initialize(text)
    super
    @is_break = true
  end
end

# whitespace token
class WhitespaceToken < AbstractToken
  def initialize(text)
    super
    @is_whitespace = true
  end
end

# keyword token
class KeywordToken < AbstractToken
  def initialize(text)
    super
    @is_keyword = true
  end
end

# comment token
class CommentToken < AbstractToken
  def initialize(text)
    super
    @is_comment = true
  end
end

# remark comment token
class RemarkToken < AbstractToken
  def initialize(text)
    super
  end
end

# operator token
class OperatorToken < AbstractToken
  def initialize(text)
    super
    @is_operator = true
  end

  def equals?
    @text == '='
  end

  def comparison?
    @text == '<' || @text == '<=' ||
      @text == '>' || @text == '>=' ||
      @text == '=' || @text == '<>'
  end
end

# group start token
class GroupStartToken < AbstractToken
  def initialize(text)
    super
    @is_groupstart = true
  end
end

# group end token
class GroupEndToken < AbstractToken
  def initialize(text)
    super
    @is_groupend = true
  end
end

# parameter separator token
class ParamSeparatorToken < AbstractToken
  def initialize(text)
    super
    @is_separator = true
  end
end

# function token
class FunctionToken < AbstractToken
  def initialize(text)
    super
    @is_function = true
  end
end

# text constant token
class TextConstantToken < AbstractToken
  def initialize(text)
    super
    @is_text_constant = true
  end

  def value
    @text[1..-2]
  end
end

# numeric constant token
class NumericConstantToken < AbstractToken
  def initialize(text)
    super
    @is_numeric_constant = true
  end

  def to_f
    @text.to_f
  end

  def to_i
    @text.to_f.to_i
  end
end

# boolean constant token
class BooleanConstantToken < AbstractToken
  def initialize(text)
    super
    @is_boolean_constant = true
  end
end

# user function token
class UserFunctionToken < AbstractToken
  def initialize(text)
    super
    @is_user_function = true
  end
end

# variable token
class VariableToken < AbstractToken
  def initialize(text)
    super
    @is_variable = true
  end
end
