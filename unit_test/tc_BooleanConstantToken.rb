# tests for BooleanConstantToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestBooleanConstantToken < Test::Unit::TestCase

  def test_simple
    token = BooleanConstantToken.new('ON')

    assert_equal('ON', token.to_s)

    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(!token.numeric_constant?)
    assert(token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
end
