class BASICError < RuntimeError; end

class BASICCommandError < BASICError; end

class BASICRuntimeError < BASICError; end

class BASICExpressionError < BASICError; end

class BASICSyntaxError < BASICError; end
