# frozen_string_literal: true

# abstract token
class AbstractToken
  def self.pretty_tokens(keywords, tokens)
    pretty_tokens = []

    prev = NullToken.new
    prev2 = NullToken.new

    keywords.each do |token|
      pretty_tokens << WhitespaceToken.new(' ') unless pretty_tokens.empty?
      pretty_tokens << token

      prev2 = prev
      prev = token
    end

    tokens.each do |token|
      prev_is_variable = prev.variable? ||
                         prev.function? ||
                         prev.user_function?

      prev2_is_operand = prev2.operand? || prev2.group_end?

      pretty_tokens << WhitespaceToken.new(' ') unless
        token.separator? ||
        (token.group_start? && prev_is_variable) ||
        token.group_end? ||
        prev.group_start? ||
        (prev.operator? && !prev2_is_operand) ||
        prev.whitespace? ||
        prev.null?

      pretty_tokens << token.pretty

      prev2 = prev
      prev = token
    end

    pretty_tokens.map(&:to_s).join
  end

  def self.pretty_multiline(keywords, tokens)
    pretty_lines = []
    pretty_tokens = []

    keywords.each do |token|
      pretty_tokens << WhitespaceToken.new(' ')
      pretty_tokens << token
    end

    prev = WhitespaceToken.new(' ')
    prev2 = WhitespaceToken.new(' ')

    tokens.each do |token|
      prev_is_variable = prev.variable? ||
                         prev.function? ||
                         prev.user_function?

      prev2_is_operand = prev2.operand? || prev2.group_end?

      pretty_tokens << WhitespaceToken.new(' ') unless
        token.separator? ||
        (token.group_start? && prev_is_variable) ||
        token.group_end? ||
        prev.group_start? ||
        (prev.operator? && prev.to_s != 'NOT' && !prev2_is_operand)

      pretty_tokens << token.pretty

      if token.statement_separator?
        pretty_line = pretty_tokens.map(&:to_s).join
        pretty_lines << pretty_line
        pretty_tokens = []
      end

      prev2 = prev
      prev = token
    end

    pretty_line = pretty_tokens.map(&:to_s).join
    pretty_lines << pretty_line
  end

  attr_reader :text

  def initialize(text)
    @text = text
    @is_null = false
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
    @is_units_constant = false
    @is_user_function = false
    @is_variable = false
    @is_statement_separator = false
    @is_group_start = false
    @is_group_end = false
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

  def pretty
    @text
  end

  def dump
    "#{self.class.name}:#{@text}"
  end

  def null?
    @is_null
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

  def group_start?
    @is_group_start
  end

  def group_end?
    @is_group_end
  end

  def operand?
    @is_function || @is_text_constant || @is_numeric_constant ||
      @is_boolean_constant || @is_user_function || @is_variable
  end

  def statement_separator?
    @is_statement_separator
  end
end

# invalid token
class InvalidToken < AbstractToken
end

# null token used for pretty()
class NullToken < AbstractToken
  def initialize
    super('')

    @is_null = true
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

# remark token
class RemarkToken < AbstractToken
end

# statement separator token
class StatementSeparatorToken < AbstractToken
  def initialize(text)
    super

    @is_statement_separator = true
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
    ['<', '<=', '>', '>=', '=', '<>'].include?(@text)
  end

  def pound?
    @text == '#'
  end
end

# group start token
class GroupStartToken < AbstractToken
  def initialize(text)
    super

    @is_group_start = true
  end
end

# group end token
class GroupEndToken < AbstractToken
  def initialize(text)
    super

    @is_group_end = true
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

  def ==(other)
    @text == other.text
  end

  def hash
    @text.hash
  end

  def <=>(other)
    @text <=> other.text
  end
end

# text constant token
class TextConstantToken < AbstractToken
  def initialize(text)
    super

    @is_text_constant = true
  end

  def <=>(other)
    value <=> other.value
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

  def <=>(other)
    @text.to_f <=> other.to_f
  end

  def negate
    @text = @text[0] == '-' ? @text[1..-1] : "-#{@text}"
  end

  def to_f
    @text.to_f
  end

  def to_i
    @text.to_f.to_i
  end

  def pretty
    float_to_possible_int(@text)
  end

  private

  def float_to_possible_int(s)
    f = s.to_f
    i = f.to_i
    frac = f - i
    if frac.zero? || (!i.zero? && frac.abs < 1e-7)
      s1 = '%G' % i.to_f
      s2 = i.to_s
      s1.size < s2.size ? s1 : s2
    else
      s1 = '%G' % f
      s2 = f.to_s
      s1.size < s2.size ? s1 : s2
    end
  end
end

# numeric symbol token
class NumericSymbolToken < AbstractToken
  def initialize(text)
    super

    @is_numeric_constant = true
    @is_symbol_constant = true

    @values = {
      'PI' => 3.14159265358979,
      'EUL' => 2.71828182845905,
      'AUR' => 1.61803398874989
    }
  end

  def value
    @values[@text]
  end
end

# boolean constant token
class BooleanConstantToken < AbstractToken
  def initialize(text)
    super

    @is_boolean_constant = true
  end
end

# units constant token
class UnitsConstantToken < AbstractToken
  attr_reader :values

  def initialize(text)
    super

    @is_units_constant = true

    @values = []

    value = ''

    text.each_char do |c|
      if value == ''
        value += c if is_alpha(c)
      elsif is_alpha(value[-1])
        value += c if is_alnum(c)
      elsif is_digit(value[-1])
        if is_digit(c)
          value += c
        end
        if is_alpha(c)
          @values << value
          value = c
        end
      end
    end

    @values << value unless value.empty?
  end

  def is_digit(c)
    '0' <= c && c <= '9'
  end

  def is_alpha(c)
    'A' <= c && c <= 'Z' || 'a' <= c && c <= 'z'
  end

  def is_alnum(c)
    'A' <= c && c <= 'Z' || 'a' <= c && c <= 'z' || '0' <= c && c <= '9'
  end
end

# user function token
class UserFunctionToken < AbstractToken
  attr_reader :content_type

  def initialize(text)
    super
    @is_user_function = true
    @content_type = :numeric
  end

  def ==(other)
    @text == other.text
  end

  def hash
    @text.hash
  end

  def <=>(other)
    @text <=> other.text
  end
end

# variable token
class VariableToken < AbstractToken
  attr_reader :content_type

  def initialize(text)
    super

    @is_variable = true
    @content_type = :numeric
  end

  def ==(other)
    @text == other.text
  end

  def hash
    @text.hash
  end

  def <=>(other)
    @text <=> other.text
  end
end
