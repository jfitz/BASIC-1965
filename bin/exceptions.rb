class BASICError < RuntimeError; end

class BASICCommandError < BASICError; end

class BASICSyntaxError < BASICError; end

class BASICExpressionError < BASICSyntaxError; end

class BASICPreexecuteError < BASICError; end

class BASICRuntimeError < BASICError; end

class BASICIOError < BASICRuntimeError; end

class BASICValueError < BASICRuntimeError; end

class BASICFunctionError < BASICRuntimeError; end

class BASICStatementError < BASICRuntimeError; end

class BASICVariableError < BASICRuntimeError; end
