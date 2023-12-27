# frozen_string_literal: true

# tokenizer class
class Tokenizer
  def initialize(tokenbuilders, invalid_tokenbuilder)
    @tokenbuilders = tokenbuilders
    @invalid_tokenbuilder = invalid_tokenbuilder
  end

  def reset_enabled
    @tokenbuilders.map(&:reset)
    @invalid_tokenbuilder.reset
  end

  def tokenize_line(text)
    tokens = []

    reset_tokens = ['THEN', 'ELSE']
    
    until text.nil? || text.empty?
      new_tokens, count = tokenize(text)

      tokens += new_tokens

      new_tokens.each do |new_token|
        if new_token.keyword?
          @tokenbuilders.each { |tb| tb.see_token(new_token) }
          @invalid_tokenbuilder.see_token(new_token)

          reset_enabled if reset_tokens.include?(new_token.to_s)
        end
      end

      text = text[count..-1]
    end

    reset_enabled

    tokens
  end

  def tokenize(text)
    tokens, count = try_tokenbuilders(text)

    if tokens.empty? && !@invalid_tokenbuilder.nil?
      tokens, count = try_invalid(text)
    end

    raise(BASICSyntaxError, "Cannot tokenize '#{text}'") if tokens.empty?

    [tokens, count]
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
