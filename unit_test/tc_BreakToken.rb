# tests for BreakToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestBreakToken < Test::Unit::TestCase

  def test_simple
    token = BreakToken.new('_')

    assert_equal('_', token.to_s)
    assert_equal('_', token.text)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(!token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(!token.operand?)
  end
  
end
