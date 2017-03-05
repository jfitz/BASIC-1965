# accept any characters
class InvalidTokenBuilder
  def try(text)
    @token = ''
    @token += text.empty? ? '' : text[0]
  end

  def count
    @token.size
  end

  def token
    InvalidToken.new(@token)
  end
end

# accept characters to match item in list
class ListTokenBuilder
  attr_reader :count
  
  def initialize(legals, class_name)
    @legals = legals
    @max_length = 0
    @legals.each do |legal|
      @max_length = legal.size if legal.size > @max_length
    end
    @class = class_name
    @count = 0
  end

  def try(text)
    token = ''
    candidate = ''
    chars_eaten = 0
    if text.size > 0 && text[0] != ' '
      max_index = [@max_length, text.size].min - 1
      (0..max_index).each do |i|
        unless text[i] == ' '
          candidate = candidate + text[i]
          @legals.each do |legal|
            if candidate == legal && candidate.size > token.size
              token = legal
              chars_eaten = i + 1
            end
          end
        end
      end
    end
    @token = token
    @count = chars_eaten
  end

  def token
    @class.new(@token)
  end
end

# token reader for whitespace
class WhitespaceTokenBuilder
  def try(text)
    @token = ''

    /\A\s+/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    WhitespaceToken.new(@token)
  end
end

# token reader for text constants
class TextTokenBuilder
  attr_reader :count
  
  def try(text)
    @token = ''

    candidate = ''
    num_quotes = 0
    i = 0
    if text.size > 0 && text[0] == '"'
      until i == text.size || num_quotes == 2
        c = text[i]
        candidate = candidate + c
        num_quotes += 1 if c == '"'
        i += 1
      end
    end

    @token = candidate if num_quotes == 2
    @count = @token.size
  end

  def token
    TextConstantToken.new(@token)
  end
end

# token reader for numeric constants in input channels (READ, INPUT)
class InputNumberTokenBuilder
  def try(text)
    regexes = [
      /\A[+-]?\d+/,
      /\A[+-]?\d+\./,
      /\A[+-]?\d+E[+-]?\d+/,
      /\A[+-]?\d+\.E[+-]?\d+/,
      /\A[+-]?\d+\.\d+/,
      /\A[+-]?\d+\.\d+E[+-]?\d+/,
      /\A[+-]?\.\d+/,
      /\A[+-]?\.\d+E[+-]?\d+/
    ]

    @token = ''

    regexes.each { |regex| regex.match(text) { |m| @token = m[0] } }
  end

  def count
    @token.size
  end

  def token
    NumericConstantToken.new(@token)
  end
end

# token reader for numeric constants
class NumberTokenBuilder
  attr_reader :count
  
  def try(text)
    @token = ''

    candidate = ''
    i = 0
    if text.size > 0 && text[0] != ' '
      refused = false
      until i == text.size || refused
        # ignore space char
        unless text[i] == ' '
          c = text[i]
          refused = !accept?(candidate, c)
          unless refused
            candidate = candidate + c
            i += 1
          end
        else
          i += 1
        end
      end
    end

    # check that string conforms to one of these
    regexes = [
      /\A\d+/,
      /\A\d+\./,
      /\A\d+E[+-]?\d+/,
      /\A\d+\.E[+-]?\d+/,
      /\A\d+\.\d+(E[+-]?\d+)?/,
      /\A\.\d+(E[+-]?\d+)?/
    ]

    @token = ''
    regexes.each { |regex| regex.match(candidate) { |m| @token = m[0] } }
    @count = @token.size
    @count > 0
  end

  def token
    NumericConstantToken.new(@token)
  end

  private

  def accept?(candidate, c)
    result = false
    # can always append a digit
    result = true if /[0-9]/.match(c)
    # can append a decimal point if no decimal point and no E
    result = true if c == '.' && candidate.count('.', 'E') == 0
    # can append E if no E and at least one digit (not just decimal point)
    result = true if c == 'E' && candidate.count('0-9') > 0
    # can append sign if no chars or last char was E
    result = true if c == '+' && candidate.size.zero? || candidate[-1] == 'E'
    result = true if c == '-' && candidate.size.zero? || candidate[-1] == 'E'

    result
  end
end

# token reader for variables
class VariableTokenBuilder
  def try(text)
    @token = ''
    /\A[A-Z]/.match(text) { |m| @token = m[0] }
    /\A[A-Z]\d/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    VariableToken.new(@token)
  end
end

# token reader for token separator
class BreakTokenBuilder
  def try(text)
    @token = ''
    @token = text[0] if text[0] == '_'
  end

  def count
    @token.size
  end

  def token
    BreakToken.new(@token)
  end
end
