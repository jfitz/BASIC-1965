class BASICError < RuntimeError; end

class BASICCommandError < BASICError; end

class BASICSyntaxError < BASICError; end

class BASICExpressionError < BASICSyntaxError; end

class BASICTrappableError < BASICError
  attr_reader :code

  def initialize(message='unknown error', code=0)
    super(message)

    @code = code
  end
end

class BASICRuntimeError < BASICTrappableError; end

class BASICPreexecuteError < BASICTrappableError; end
