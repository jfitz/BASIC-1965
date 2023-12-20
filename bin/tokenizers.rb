# frozen_string_literal: true

# tokenizer class
class Tokenizer
  def initialize(tokenbuilders, invalid_tokenbuilder)
    @tokenbuilders = tokenbuilders
    @invalid_tokenbuilder = invalid_tokenbuilder
  end

  def handle_token(token)
    @tokenbuilders.each { |tokenbuilder| tokenbuilder.handle_token(token) }
    @invalid_tokenbuilder.handle_token(token)
  end

  def reset_enabled
    @tokenbuilders.map(&:reset)
    @invalid_tokenbuilder.reset
  end

  def tokenize_line(text)
    tokens = []
    seen_only_keywords = true

    until text.nil? || text.empty?
      new_tokens, count = tokenize(text)

      tokens += new_tokens

      tokens.each do |token|
        if token.keyword?
          @tokenbuilders.each { |tb| tb.handle_token(token) }
          @invalid_tokenbuilder.handle_token(token)
        else
          seen_only_keywords = false
        end
      end

      text = text[count..-1]
    end

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
