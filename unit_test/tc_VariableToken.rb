# tests for VariableToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestVariableToken < Test::Unit::TestCase

  def test_simple
    token = VariableToken.new('A')

    assert_equal('A', token.to_s)
    assert_equal('A', token.variable)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(!token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)

    other_token_1 = VariableToken.new('A')
    assert(token.eql?(other_token_1))
    assert(token == other_token_1)
    
    other_token_2 = VariableToken.new('B')
    assert(!token.eql?(other_token_2))
    assert(!(token == other_token_2))
  end
  
end
