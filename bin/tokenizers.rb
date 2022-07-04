# frozen_string_literal: true

# tokenizer class
class Tokenizer
  def initialize(tokenbuilders, invalid_tokenbuilder)
    @tokenbuilders = tokenbuilders
    @invalid_tokenbuilder = invalid_tokenbuilder
  end

  def tokenize(text)
    tokens = []

    until text.nil? || text.empty?
      new_tokens, count = try_tokenbuilders(text)

      if new_tokens.empty? && !@invalid_tokenbuilder.nil?
        new_tokens, count = try_invalid(text)
      end

      raise(BASICSyntaxError, "Cannot tokenize '#{text}'") if
        new_tokens.empty?

      tokens += new_tokens

      text = text[count..-1]
    end

    tokens
  end

  private

  def try_tokenbuilders(text)
    @tokenbuilders.each { |tokenbuilder| tokenbuilder.try(text) }
    count = 0
    tokens = []

    # general tokenbuilders
    @tokenbuilders.each do |tokenbuilder|
      if tokenbuilder.count > count
        tokens = tokenbuilder.tokens
        count = tokenbuilder.count
      end
    end

    [tokens, count]
  end

  def try_invalid(text)
    @invalid_tokenbuilder.try(text)
    tokens = @invalid_tokenbuilder.tokens
    count = @invalid_tokenbuilder.count
    [tokens, count]
  end
end
