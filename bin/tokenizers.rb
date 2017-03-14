# tokenizer class
class Tokenizer
  def initialize(tokenizers, invalid_tokenizer)
    @tokenizers = tokenizers
    @invalid_tokenizer = invalid_tokenizer
  end

  def tokenize(text)
    tokens = []
    until text.nil? || text.empty?
      token, count = try_tokenizers(text)

      token, count = try_invalid(text) if token.nil? && !@invalid_tokenizer.nil?
      raise(Exception, "Cannot tokenize '#{text}'") if token.nil?

      if token.class.to_s == 'Array'
        tokens += token
      else
        tokens << token
      end
      text = text[count..-1]
    end
    tokens
  end

  private

  def try_tokenizers(text)
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
    [token, count]
  end

  def try_invalid(text)
    @invalid_tokenizer.try(text)
    token = @invalid_tokenizer.token
    count = @invalid_tokenizer.count
    [token, count]
  end
end
