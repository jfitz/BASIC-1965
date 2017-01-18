# tests for OperatorToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestOperatorToken < Test::Unit::TestCase

  def test_equals
    token = OperatorToken.new('=')

    assert_equal('=', token.to_s)

    assert(!token.keyword?)
    assert(token.operator?)
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

    assert(token.equals?)
    assert(token.comparison?)
  end
  
  def test_less_than
    token = OperatorToken.new('<')

    assert_equal('<', token.to_s)

    assert(!token.keyword?)
    assert(token.operator?)
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

    assert(!token.equals?)
    assert(token.comparison?)
  end
  
  def test_less_equals
    token = OperatorToken.new('<=')

    assert_equal('<=', token.to_s)
    assert_equal('<=', token.text)
    assert(!token.keyword?)
    assert(token.operator?)
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

    assert(!token.equals?)
    assert(token.comparison?)
  end
  
  def test_greater_then
    token = OperatorToken.new('>')

    assert_equal('>', token.to_s)
    assert_equal('>', token.text)
    assert(!token.keyword?)
    assert(token.operator?)
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

    assert(!token.equals?)
    assert(token.comparison?)
  end
  
  def test_greater_equals
    token = OperatorToken.new('>=')

    assert_equal('>=', token.to_s)
    assert_equal('>=', token.text)
    assert(!token.keyword?)
    assert(token.operator?)
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

    assert(!token.equals?)
    assert(token.comparison?)
  end
  
  def test_not_equals
    token = OperatorToken.new('<>')

    assert_equal('<>', token.to_s)
    assert_equal('<>', token.text)
    assert(!token.keyword?)
    assert(token.operator?)
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

    assert(!token.equals?)
    assert(token.comparison?)
  end
  
end
