# test suite for tokens.rb

require 'test/unit'

require_relative 'tc_InvalidToken'
require_relative 'tc_BreakToken'
require_relative 'tc_WhitespaceToken'
require_relative 'tc_KeywordToken'
require_relative 'tc_OperatorToken'
require_relative 'tc_GroupStartToken'
require_relative 'tc_GroupEndToken'
require_relative 'tc_ParamSeparatorToken'
require_relative 'tc_FunctionToken'
require_relative 'tc_UserFunctionToken'
require_relative 'tc_TextConstantToken'
require_relative 'tc_NumericConstantToken'
require_relative 'tc_BooleanConstantToken'
require_relative 'tc_VariableToken'
