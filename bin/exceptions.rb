class BASICError < RuntimeError; end

class BASICCommandError < BASICError; end

class BASICSyntaxError < BASICError; end

class BASICExpressionError < BASICSyntaxError; end

class BASICTrappableError < BASICError
  attr_reader :scode
  attr_reader :code
  attr_reader :extra

  def initialize(scode, extra = nil)
    message = $error_messages[scode]
    super(message)

    @scode = scode
    @code = $error_codes[scode]
    @extra = extra
  end

  def message
    message = $error_messages[scode]
    message = "Unknown error #{@scode}" if message.nil?

    return message if @extra.nil?

    message + ' for ' + @extra
  end
end

class BASICRuntimeError < BASICTrappableError; end

class BASICPreexecuteError < BASICTrappableError; end

$error_codes = {
  te_unk: 0,
  te_exp_num: 100,
  te_exp_sep: 101,
  te_eof: 102,
  te_out_of_data: 103,
  te_fname_no: 104,
  te_mode_inv: 105,
  te_op_inc: 106,
  te_fh_inv: 108,
  te_fnum_inv: 109,
  te_list_empty: 110,
  te_div_zero: 111,
  te_too_few: 112,
  te_too_many: 113,
  te_arr_no_dim: 114,
  te_arr_dif_siz: 115,
  te_mat_no_dim: 116,
  te_mat_no_sq: 117,
  te_subscript_out: 118,
  te_args_no_match: 120,
  te_var_uninit: 130,
  te_var_lock: 131,
  te_var_lock2: 132,
  te_var_no_type: 133,
  te_var_no_lock: 134,
  te_ret_no_gos: 140,
  te_next_no_for: 141,
  te_inext_no_for: 142,
  te_fname_inv: 150,
  te_file_no_fnd: 151,
  te_fh_unk: 152,
  te_str_empty: 160,
  te_val_out: 161,
  te_count_inv: 162,
  te_len_inv: 163,
  te_erl_no_err: 170,
  te_err_no_err: 171,
  te_rec_no_read: 180,
  te_rec_no_write: 181,
  te_not_text_c: 182,
  te_inp_no_num_text: 183,
  te_mode_inc: 184,
  te_recno_inv: 185,
  te_recno_out: 186,
  te_file_no_read: 187,
  te_file_no_write: 188,
  te_break: 190,
  te_no_fmt: 200,
  te_few_fmt: 201,
  te_func_no: 210,
  te_func_alr: 211,
  te_no_chain: 220,
  te_option_no_run: 230
}

$error_messages = {
  te_unk: 'Unknown error',
  te_exp_num: 'Expected number',
  te_exp_sep: 'Expected separator',
  te_eof: 'End of file',
  te_out_of_data: 'Out of data',
  te_fname_no: 'No file name',
  te_mode_inv: 'Invalid mode',
  te_op_inc: 'Inconsistent operation',
  te_fh_inv: 'Invalid file handle',
  te_fnum_inv: 'Invalid file number',
  te_list_empty: 'List is empty',
  te_div_zero: 'Divide by zero',
  te_too_few: 'Too few items',
  te_too_many: 'Too many items',
  te_arr_no_dim: 'Array not dimensioned',
  te_arr_dif_siz: 'Arrays have different sizes',
  te_mat_no_dim: 'Matrix not dimensioned',
  te_mat_no_sq: 'Matrix must be square',
  te_args_no_match: 'Arguments do not match signature',
  te_subscript_out: 'Subscript out of range',
  te_var_uninit: 'Variable not initialized',
  te_var_lock: 'Variable is locked',
  te_var_lock2: 'Variable is already locked',
  te_var_no_type: 'Wrong type for variable',
  te_var_no_lock: 'Variable is not locked',
  te_ret_no_gos: 'RETURN without GOSUB',
  te_next_no_for: 'NEXT without FOR',
  te_inext_no_for: 'Implied NEXT without FOR',
  te_fname_inv: 'Invalid file name',
  te_file_no_fnd: 'File not found',
  te_fh_unk: 'Unknown file handle',
  te_str_empty: 'String is empty',
  te_val_out: 'Value out of range',
  te_count_inv: 'Invalid count',
  te_len_inv: 'invalid length',
  te_erl_no_err: 'ERL() without error',
  te_err_no_err: 'ERR() without error',
  te_rec_no_read: 'Read failed',
  te_rec_no_write: 'Write failed',
  te_not_text_c: 'Not text constant',
  te_inp_no_num_text: 'Expected numeric or text input',
  te_mode_inc: 'Inconsistent mode',
  te_recno_inv: 'invalid record number',
  te_recno_out: 'Record number out of range',
  te_file_no_read: 'Read failed',
  te_file_no_write: 'Write failed',
  te_break: 'BREAK',
  te_no_fmt: 'No format for USING',
  te_few_fmt: 'Too few items for USING',
  te_func_no: 'Function not defined',
  te_func_alr: 'Function already defined',
  te_no_chain: 'Cannot chain to file',
  te_option_no_run: 'Cannot set option'
}
