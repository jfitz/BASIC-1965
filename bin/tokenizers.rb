# tokenizer class
class Tokenizer
  def initialize(tokenizers, invalid_tokenizer)
    @tokenizers = tokenizers
    @invalid_tokenizer = invalid_tokenizer
  end

  def tokenize(text)
    tokens = []
    until text.nil? || text.empty?
      @tokenizers.each { |tokenizer| tokenizer.try(text) }

      count = 0
      token = nil
      # general tokenizers
      @tokenizers.each do |tokenizer|
        if tokenizer.count > count
          token = tokenizer.token
          count = tokenizer.count
        end
      end

      # invalid tokenizer
      if token.nil? && !@invalid_tokenizer.nil?
        @invalid_tokenizer.try(text)
        token = @invalid_tokenizer.token
        count = @invalid_tokenizer.count
      end
      raise(Exception, "Cannot tokenize '#{text}'") if token.nil?
      tokens += token
      text = text[count..-1]
    end
    tokens
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

# token reader for whitespace
class WhitespaceTokenizer
  def try(text)
    @token = ''
    /\A\s+/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [WhitespaceToken.new(@token)]
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
class ReadNumberTokenizer
  def try(text)
    @token = ''
    /\A[+-]?\d+/.match(text) { |m| @token = m[0] }
    /\A[+-]?\d+\./.match(text) { |m| @token = m[0] }
    /\A[+-]?\d+E[+-]?\d+/.match(text) { |m| @token = m[0] }
    /\A[+-]?\d+\.E[+-]?\d+/.match(text) { |m| @token = m[0] }
    /\A[+-]?\d+\.\d+/.match(text) { |m| @token = m[0] }
    /\A[+-]?\d+\.\d+E[+-]?\d+/.match(text) { |m| @token = m[0] }
    /\A[+-]?\.\d+/.match(text) { |m| @token = m[0] }
    /\A[+-]?\.\d+E[+-]?\d+/.match(text) { |m| @token = m[0] }
  end

  def count
    @token.size
  end

  def token
    [NumericConstantToken.new(@token)]
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

# token reader for token separator
class BreakTokenizer
  def try(text)
    @token = ''
    @token = text[0] if text[0] == '_'
    text = '_'
  end

  def count
    @token.size
  end

  def token
    [BreakToken.new(@token)]
  end
end
