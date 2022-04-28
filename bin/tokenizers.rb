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
      token, count = try_tokenbuilders(text)

      if token.nil? && !@invalid_tokenbuilder.nil?
        token, count = try_invalid(text)
      end

      raise(BASICSyntaxError, "Cannot tokenize '#{text}'") if token.nil?

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

  def try_tokenbuilders(text)
    @tokenbuilders.each { |tokenbuilder| tokenbuilder.try(text) }
    count = 0
    token = nil

    # general tokenbuilders
    @tokenbuilders.each do |tokenbuilder|
      if tokenbuilder.count > count
        token = tokenbuilder.token
        count = tokenbuilder.count
      end
    end

    [token, count]
  end

  def try_invalid(text)
    @invalid_tokenbuilder.try(text)
    token = @invalid_tokenbuilder.token
    count = @invalid_tokenbuilder.count
    [token, count]
  end
end
