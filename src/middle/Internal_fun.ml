open Core_kernel

type t = Mir_pattern.internal_fn =
  | FnLength
  | FnMakeArray
  | FnMakeRowVec
  | FnNegInf
  | FnReadData
  | FnReadParam
  | FnWriteParam
  | FnConstrain
  | FnUnconstrain
  | FnCheck
  | FnPrint
  | FnReject
[@@deriving sexp]


let to_string x = Sexp.to_string (sexp_of_t x) ^ "__"

let of_string_opt x =
  try
    String.chop_suffix_exn ~suffix:"__" x |> Sexp.of_string |> t_of_sexp |> Some
  with
  | Sexplib.Conv.Of_sexp_error _ -> None
  | Invalid_argument _ -> None