# Function that expects scalar parameters
class AbstractScalarFunction < Function
  def initialize(text)
    super
  end

  def default_type
    ScalarValue
  end
end

# Function that expects matrix parameters
class AbstractMatrixFunction < Function
  def initialize(text)
    super
  end

  def default_type
    MatrixValue
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'INT requires single value') if args.size != 1
    check_arg_types(args, ['NumericConstant'])
    args[0].truncate
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    args = stack.pop
    raise(BASICException, 'Zero or one argument required for RND()') unless
      args.size == 0 || args.size == 1
    x = NumericConstant.new(100) if args.empty?
    if args.size == 1
      check_arg_types(args, ['NumericConstant'])
      x = args[0]
    end
    interpreter.rand(x)
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for EXP()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].exp
  end
end

# function LOG
class FunctionLog < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for LOG()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].log
  end
end

# function ABS
class FunctionAbs < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for ABS()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].abs
  end
end

# function SQR
class FunctionSqr < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for SQR()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].sqrt
  end
end

# function SIN
class FunctionSin < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for SIN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].sin
  end
end

# function COS
class FunctionCos < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for COS()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].cos
  end
end

# function TAN
class FunctionTan < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for TAN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].tan
  end
end

# function ATN
class FunctionAtn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for ATN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].atn
  end
end

# function SGN
class FunctionSgn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for SGN()') unless
      args.size == 1
    check_arg_types(args, ['NumericConstant'])
    args[0].sign
  end
end

# function TRN
class FunctionTrn < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for TRN()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
    dims = args[0].dimensions
    new_dims = [dims[1], dims[0]]
    Matrix.new(new_dims, args[0].transpose_values)
  end
end

# function ZER
class FunctionZer < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One or two arguments required for ZER()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    matrix = Matrix.new(args.clone, {})
    Matrix.new(matrix.dimensions, matrix.zero_values)
  end
end

# function CON
class FunctionCon < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One or two arguments required for CON()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    matrix = Matrix.new(args.clone, {})
    Matrix.new(matrix.dimensions, matrix.one_values)
  end
end

# function IDN
class FunctionIdn < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    check(args)
    dims = [args[0]] * 2
    matrix = Matrix.new(dims, {})
    Matrix.new(dims, matrix.identity_values)
  end

  private

  def check(args)
    raise(BASICException, 'One or two arguments required for IDN()') unless
      args.size == 1 || args.size == 2
    check_arg_types(args, ['NumericConstant'] * args.size)
    raise(BASICException, 'IDN requires square matrix') if
      args.size == 2 && args[1] != args[0]
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    raise(BASICException, 'One argument required for DET()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
    args[0].determinant
  end
end

# function INV
class FunctionInv < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    args = stack.pop
    check(args)
    dims = args[0].dimensions
    check_2(dims)
    Matrix.new(dims.clone, args[0].inverse_values)
  end

  private

  def check(args)
    raise(BASICException, 'One argument required for INV()') unless
      args.size == 1
    check_arg_types(args, ['Matrix'])
  end

  def check_2(dims)
    raise(BASICException, 'INV requires matrix') unless dims.size == 2
    raise(BASICException, 'INV requires square matrix') if dims[1] != dims[0]
  end
end
