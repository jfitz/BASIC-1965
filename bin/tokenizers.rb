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
