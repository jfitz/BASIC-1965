# tests for TextConstantToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestTextConstantToken < Test::Unit::TestCase

  def test_empty
    token = TextConstantToken.new('""')

    assert_equal('""', token.to_s)
    assert_equal('""', token.text_constant)
    assert_equal('', token.value)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(token.text_constant?)
    assert(!token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
  def test_simple
    token = TextConstantToken.new('"SIMPLE"')

    assert_equal('"SIMPLE"', token.to_s)
    assert_equal('"SIMPLE"', token.text_constant)
    assert_equal('SIMPLE', token.value)
    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(!token.function?)
    assert(token.text_constant?)
    assert(!token.numeric_constant?)
    assert(!token.boolean_constant?)
    assert(!token.user_function?)
    assert(!token.variable?)
    assert(!token.groupstart?)
    assert(!token.groupend?)
    assert(!token.whitespace?)
    assert(token.operand?)
  end
  
end
