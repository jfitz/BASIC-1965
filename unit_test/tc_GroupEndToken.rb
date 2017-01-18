# tests for GroupEndToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestGroupEndToken < Test::Unit::TestCase

  def test_parens
    token = GroupEndToken.new(')')

    assert_equal(')', token.to_s)
    assert_equal(')', token.ender)
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
    assert(token.groupend?)
    assert(!token.whitespace?)
    assert(!token.operand?)
  end
  
  def test_bracket
    token = GroupEndToken.new(']')

    assert_equal(']', token.to_s)
    assert_equal(']', token.ender)
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
    assert(token.groupend?)
    assert(!token.whitespace?)
    assert(!token.operand?)
  end
  
end
