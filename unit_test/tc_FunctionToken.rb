# tests for FunctionToken class

require 'test/unit'

require_relative '../bin/tokens'

class TestFunctionToken < Test::Unit::TestCase

  def test_simple
    token = FunctionToken.new('INT')

    assert_equal('INT', token.to_s)

    assert(!token.keyword?)
    assert(!token.operator?)
    assert(!token.separator?)
    assert(token.function?)
    assert(!token.text_constant?)
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
