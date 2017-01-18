# tests for NumericConstantToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestNumericConstantToken < Test::Unit::TestCase

  def test_10
    token = NumericConstantToken.new('10')

    assert_equal('10', token.to_s)
    assert_equal(10, token.to_f)
    assert_equal(10, token.to_i)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
  def test_10_2
    token = NumericConstantToken.new('10.2')

    assert_equal('10.2', token.to_s)
    assert_equal(10.2, token.to_f)
    assert_equal(10, token.to_i)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
  def test_minus_10
    token = NumericConstantToken.new('-10')

    assert_equal('-10', token.to_s)
    assert_equal(-10, token.to_f)
    assert_equal(-10, token.to_i)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
  def test_minus_10_2
    token = NumericConstantToken.new('-10.2')

    assert_equal('-10.2', token.to_s)
    assert_equal(-10.2, token.to_f)
    assert_equal(-10, token.to_i)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(!token.text_constant?)
    assert(token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
end
