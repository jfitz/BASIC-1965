class BASICError < RuntimeError; end

class BASICCommandError < BASICError; end

class BASICSyntaxError < BASICError; end

class BASICExpressionError < BASICSyntaxError; end

class BASICTrappableError < BASICError
  attr_reader :scode
  attr_reader :code

  def initialize(message='unknown error', scode=:te_unk)
    @scode = scode
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
  te_func_alr: 152,
  te_none: 999
}
