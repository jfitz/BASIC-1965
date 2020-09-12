class BASICError < RuntimeError; end

class BASICCommandError < BASICError; end

class BASICSyntaxError < BASICError; end

class BASICExpressionError < BASICSyntaxError; end

class BASICTrappableError < BASICError
  attr_reader :scode
  attr_reader :code

  def initialize(scode, message=nil)
    @scode = scode
    message = $error_messages[scode] if message.nil?
    @code = $error_codes[scode]
    message = "Unknown error code #{scode}" if @code.nil?
    super(message)
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
  te_arr_dif_siz: 113,
  te_mat_no_sq: 114,
  te_args_no_match: 116,
  te_subscript_out: 117,
  te_var_uninit: 118,
  te_var_locked: 119,
  te_var_no_type: 120,
  te_var_no_locked: 121,
  te_ret_no_gos: 122,
  te_next_no_for: 123,
  te_inext_no_for: 124,
  te_fname_inv: 125,
  te_file_no_fnd: 126,
  te_fh_unk: 127,
  te_str_empty: 128,
  te_val_out: 129,
  te_count_inv: 130,
  te_len_inv: 131,
  te_erl_no_err: 132,
  te_err_no_err: 160,
  te_var_locked2: 133,
  te_rec_no_read: 134,
  te_rec_no_write: 135,
  te_not_text_c: 136,
  te_inp_no_num_text: 137,
  te_break: 138,
  te_mode_inc: 139,
  te_recno_inv: 140,
  te_recno_out: 141,
  te_file_no_read: 142,
  te_file_no_write: 143,
  te_no_fmt: 144,
  te_few_fmt: 145,
  te_func_no: 150,
  te_func_alr: 152
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
  te_arr_dif_siz: 'Arrays have different sizes',
  te_mat_no_sq: 'Matrix must be square',
  te_args_no_match: 'Arguments do not match signature',
  te_subscript_out: 'Subscript out of range',
  te_var_uninit: 'Variable not initialized',
  te_var_locked: 'Variable is locked',
  te_var_no_type: 'Wrong type for variable',
  te_var_no_locked: 'Variable is not locked',
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
  te_var_locked2: 'Variable is already locked',
  te_rec_no_read: 'Read failed',
  te_rec_no_write: 'Write failed',
  te_not_text_c: 'Not text C',
  te_inp_no_num_text: 'Expected numeric or text input',
  te_break: 'BREAK',
  te_mode_inc: 'Inconsistent mode',
  te_recno_inv: 'invalid record number',
  te_recno_out: 'Record number out of range',
  te_file_no_read: 'Read failed',
  te_file_no_write: 'Write failed',
  te_no_fmt: 'No format for USING',
  te_few_fmt: 'Too few items for USING',
  te_func_no: 'Function not defined',
  te_func_alr: 'Function already defined'
}
