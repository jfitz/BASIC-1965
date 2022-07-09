# frozen_string_literal: true

# accept any characters
class InvalidTokenBuilder
  def try(text)
    @token = ''
    @token += text.empty? ? '' : text[0]
  end

  def count
    @token.size
  end

  def tokens
    [InvalidToken.new(@token)]
  end
end

# accept characters to match item in list
class ListTokenBuilder
  attr_reader :count

  def initialize(legals, class_name)
    @legals = legals
    @class = class_name
    @count = 0
  end

  def try(text)
    best_candidate = ''
    best_count = 0

    if !text.empty? && text[0] != ' '
      candidate = ''
      i = 0
      accepted = true

      while i < text.size && accepted
        c = text[i]

        # ignore space char
        if c == ' '
          i += 1
        else
          accepted = accept?(candidate, c)

          if accepted
            candidate += c
            i += 1

            if @legals.include?(candidate)
              best_candidate = candidate
              best_count = i
            end
          end
        end
      end
    end

    @count = 0

    unless best_candidate.empty?
      @token = best_candidate
      @count = best_count
    end

    @count.positive?
  end

  def tokens
    [@class.new(@token)]
  end

  private

  def accept?(candidate, c)
    token = candidate + c
    count = token.size - 1
    result = false

    @legals.each do |legal|
      result = true if legal[0..count] == token
    end

    result
  end
end

# Remark tokens (returns 2)
class RemarkTokenBuilder
  attr_reader :count

  def initialize
    @legals = %w[REMARK REM]
    @count = 0
  end

  def try(text)
    best_candidate = ''
    best_count = 0

    if !text.empty? && text[0] != ' '
      candidate = ''
      i = 0
      accepted = true

      while i < text.size && accepted
        c = text[i]

        # ignore space char
        if c == ' '
          i += 1
        else
          accepted = accept?(candidate, c)

          if accepted
            candidate += c
            i += 1

            if @legals.include?(candidate)
              best_candidate = candidate
              best_count = i
            end
          end
        end
      end
    end

    @count = 0

    unless best_candidate.empty?
      @keyword_token = best_candidate
      remark = text[best_count..-1]
      @remark_token = remark[0] == ' ' ? remark[1..-1] : remark
      @count = text.size
    end

    @count.positive?
  end

  def tokens
    tokens = []
    tokens << KeywordToken.new(@keyword_token)
    tokens << RemarkToken.new(@remark_token) unless @remark_token.empty?
    tokens
  end

  private

  def accept?(candidate, c)
    token = candidate + c
    count = token.size - 1
    result = false

    @legals.each do |legal|
      result = true if legal[0..count] == token
    end

    result
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

  def tokens
    [WhitespaceToken.new(@token)]
  end
end

# token reader for comments
class CommentTokenBuilder
  attr_reader :count

  def initialize(lead_chars)
    @lead_chars = lead_chars
  end

  def try(text)
    @token = ''
    @token = text if !text.empty? && @lead_chars.include?(text[0])

    @count = @token.size
  end

  def tokens
    [CommentToken.new(@token)]
  end
end

# token reader for text constants
class TextTokenBuilder
  attr_reader :count

  def initialize(quotes)
    @quotes = quotes
  end

  def try(text)
    @token = ''

    candidate = ''
    i = 0

    if !text.empty? && @quotes.include?(text[0])
      until i == text.size ||
            (candidate.size >= 2 && candidate[-1] == candidate[0])
        c = text[i]
        candidate += c
        i += 1
      end
    end

    unless candidate.empty?
      lead_quote = text[0]
      candidate += lead_quote if candidate.count(lead_quote) == 1
      @token = candidate if candidate.count(lead_quote) == 2
    end

    @count = @token.size
  end

  def tokens
    [QuotedTextLiteralToken.new(@token)]
  end
end

# token reader for numeric constants in input channels (READ, INPUT)
class InputNumberTokenBuilder
  def try(text)
    regexes = [
      /\A[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\d+\.(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\d+E[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\d+\.E[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\d+\.\d+(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\d+\.\d+E[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\.\d+(\{[A-Za-z0-9\+\- _]*\})?/,
      /\A[+-]?\.\d+E[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?/
    ]

    @token = ''

    regexes.each { |regex| regex.match(text) { |m| @token = m[0] } }
  end

  def count
    @token.size
  end

  def tokens
    [NumericLiteralToken.new(@token)]
  end
end

# token reader for numeric constants
class NumberTokenBuilder
  attr_reader :count

  def try(text)
    candidate = ''

    if !text.empty? && text[0] != ' '
      i = 0
      accepted = true

      while i < text.size && accepted
        c = text[i]

        # ignore space char
        if c == ' '
          i += 1
        else
          accepted = accept?(candidate, c)

          if accepted
            candidate += c
            i += 1
          end
        end
      end

      # if the candidate ends with 'E', remove it
      # the tokenbuilder takes as many as possible,
      # but a trailing 'E' is not valid
      if candidate[-1] == 'E'
        candidate = candidate[0..-2]
        i -= 1

        # back up to the 'E' in the input text
        # (there may be spaces)
        i -= 1 while text[i] != 'E'
      end
    end

    # check that string conforms to one of these
    regexes = [
      /\A\d+(\{[A-Za-z0-9\+\- _]*\})?\z/,
      /\A\d+\.(\{[A-Za-z0-9\+\- _]*\})?\z/,
      /\A\d+E[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?\z/,
      /\A\d+\.E[+-]?\d+(\{[A-Za-z0-9\+\- _]*\})?\z/,
      /\A\d+\.\d+(E[+-]?\d+)?(\{[A-Za-z0-9\+\- _]*\})?\z/,
      /\A\.\d+(E[+-]?\d+)?(\{[A-Za-z0-9\+\- _]*\})?\z/
    ]

    @token = ''

    regexes.each { |regex| regex.match(candidate) { |m| @token = m[0] } }

    @count = 0
    @count = i unless @token.empty?

    @count.positive?
  end

  def tokens
    [NumericLiteralToken.new(@token)]
  end

  private

  def accept?(candidate, c)
    result = false

    return false if candidate.size.positive? && candidate[-1] == '}'

    if candidate.include?('{')
      result = true if c =~ /[\w _\+\-\}]/
    else
      # can always append a digit
      result = true if c =~ /[0-9]/

      # can append a decimal point if no decimal point and no E
      result = true if c == '.' && candidate.count('.', 'E').zero?

      # can append E if no E and at least one digit (not just decimal point)
      result = true if c == 'E' &&
                       candidate.count('E').zero? &&
                       !candidate.count('0-9').zero?

      # can append sign if no chars or last char was E
      result = true if c == '+' && (candidate.empty? || candidate[-1] == 'E')
      result = true if c == '-' && (candidate.empty? || candidate[-1] == 'E')

      # can append a units sigil
      result = true if c == '{'
    end

    result
  end
end

# token reader for numeric symbols
class NumericSymbolTokenBuilder
  attr_reader :count

  def try(text)
    legals = %w[PI EUL AUR]

    candidate = ''
    i = 0

    legals.each do |symbol|
      if text.start_with?(symbol) && symbol.size > candidate.size
        candidate = symbol
        i = symbol.size
      end
    end

    @token = ''
    @token = candidate if legals.include?(candidate)

    @count = 0
    @count = i unless @token.empty?

    @count.positive?
  end

  def tokens
    [NumericSymbolToken.new(@token)]
  end
end

# token reader for variables
class VariableTokenBuilder
  attr_reader :count

  def try(text)
    @token = ''

    candidate = ''
    i = 0

    if !text.empty? && text[0] != ' '
      accepted = true

      while i < text.size && accepted
        c = text[i]

        # ignore space char
        if c == ' '
          i += 1
        else
          accepted = accept?(candidate, c)

          if accepted
            candidate += c
            i += 1
          end
        end
      end
    end

    # check that string conforms to one of these
    regexes = [
      /\A[A-Z]\z/,
      /\A[A-Z]\d\z/
    ]

    @token = ''
    regexes.each { |regex| regex.match(candidate) { |m| @token = m[0] } }

    @count = 0
    @count = i unless @token.empty?

    @count.positive?
  end

  def tokens
    [VariableToken.new(@token)]
  end

  private

  def accept?(candidate, c)
    result = false
    # can always start with an alpha
    result = true if c =~ /[A-Z]/ && candidate.empty?
    # can always append a digit
    result = true if c =~ /[0-9]/ && candidate.size == 1

    result
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

  def tokens
    [BreakToken.new(@token)]
  end
end
