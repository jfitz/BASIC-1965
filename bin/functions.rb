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

  def check_square(dims)
    raise(BASICException, @name + ' requires matrix') unless dims.size == 2
    raise(BASICException, @name + ' requires square matrix') unless
      dims[1] == dims[0]
  end
end

# function INT
class FunctionInt < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
    check_arg_types(args, ['NumericConstant'])
    interpreter.int_floor? ? args[0].floor : args[0].truncate
  end
end

# function RND
class FunctionRnd < AbstractScalarFunction
  def initialize(text)
    super
  end

  # return a single value
  def evaluate(interpreter, stack)
    stack.push([NumericConstant.new(100)]) if
      stack.empty? || stack[-1].class.to_s != 'Array'
    ensure_argument_count(stack, [0, 1])
    args = stack.pop
    args = [NumericConstant.new(100)] if args.empty? || args[0].nil?
    check_arg_types(args, ['NumericConstant'])
    interpreter.rand(args[0])
  end
end

# function EXP
class FunctionExp < AbstractScalarFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1, 2])
    args = stack.pop
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
    ensure_argument_count(stack, [1, 2])
    args = stack.pop
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
    ensure_argument_count(stack, [1, 2])
    args = stack.pop
    check_arg_types(args, ['NumericConstant'] * args.size)
    check_square(args) if args.size == 2
    dims = [args[0]] * 2
    matrix = Matrix.new(dims, {})
    Matrix.new(dims, matrix.identity_values)
  end

  private

  def check_square(dims)
    raise(BASICException, @name + ' requires matrix') unless dims.size == 2
    raise(BASICException, @name + ' requires square matrix') unless
      dims[1] == dims[0]
  end
end

# function DET
class FunctionDet < AbstractMatrixFunction
  def initialize(text)
    super
  end

  def evaluate(_, stack)
    ensure_argument_count(stack, [1])
    args = stack.pop
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
    ensure_argument_count(stack, [1])
    args = stack.pop
    dims = args[0].dimensions
    check_arg_types(args, ['Matrix'])
    check_square(dims)
    Matrix.new(dims.clone, args[0].inverse_values)
  end
end
