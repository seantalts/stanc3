(** The Middle Intermediate Representation, which program transformations
    operate on *)

open Core_kernel
open Common
(** Arithmetic and logical operators *)
type operator =
  | Plus
  | PPlus
  | Minus
  | PMinus
  | Times
  | Divide
  | Modulo
  | LDivide
  | EltTimes
  | EltDivide
  | Pow
  | Or
  | And
  | Equals
  | NEquals
  | Less
  | Leq
  | Greater
  | Geq
  | PNot
  | Transpose
[@@deriving sexp, hash, compare]

(** Unsized types for function arguments and for decorating expressions
    during type checking; we have a separate type here for Math library
    functions as these functions can be overloaded, so do not have a unique
    type in the usual sense. Still, we want to assign a unique type to every
    expression during type checking.  *)
type unsizedtype =
  | UInt
  | UReal
  | UVector
  | URowVector
  | UMatrix
  | UArray of unsizedtype
  | UFun of (autodifftype * unsizedtype) list * returntype
  | UMathLibraryFunction
[@@deriving sexp, hash]

(** Flags for data only arguments to functions *)
and autodifftype = DataOnly | AutoDiffable [@@deriving sexp, hash, compare]

and returntype = Void | ReturnType of unsizedtype [@@deriving sexp, hash]

(** Sized types, for variable declarations *)
type 'e sizedtype =
  | SInt
  | SReal
  | SVector of 'e
  | SRowVector of 'e
  | SMatrix of 'e * 'e
  | SArray of 'e sizedtype * 'e
[@@deriving sexp, compare, map, hash, fold]

(* TODO : derive using ppx *)
module Make_traversable_sizedtype (A : Applicative.S) :
  Traversable.S with type 'a t := 'a sizedtype and module A := A = struct
  let rec traverse x ~f =
    match x with
    | SInt -> A.return SInt
    | SReal -> A.return SReal
    | SVector e -> A.map ~f:(fun e -> SVector e) (f e)
    | SRowVector e -> A.map ~f:(fun e -> SVector e) (f e)
    | SMatrix (e1, e2) ->
        A.map2 ~f:(fun e1 e2 -> SMatrix (e1, e2)) (f e1) (f e2)
    | SArray (st, e) ->
        A.map2 ~f:(fun st e -> SArray (st, e)) (traverse ~f st) (f e)
end

module Make_traversable_sizedtype2 (A : Applicative.S2) :
  Traversable.S2 with type 'a t := 'a sizedtype and module A := A = struct
  let rec traverse x ~f =
    match x with
    | SInt -> A.return SInt
    | SReal -> A.return SReal
    | SVector e -> A.map ~f:(fun e -> SVector e) (f e)
    | SRowVector e -> A.map ~f:(fun e -> SVector e) (f e)
    | SMatrix (e1, e2) ->
        A.map2 ~f:(fun e1 e2 -> SMatrix (e1, e2)) (f e1) (f e2)
    | SArray (st, e) ->
        A.map2 ~f:(fun st e -> SArray (st, e)) (traverse ~f st) (f e)
end

type 'e possiblysizedtype = Sized of 'e sizedtype | Unsized of unsizedtype
[@@deriving sexp, compare, map, hash, fold]

module Make_traversable_possiblysizedtype (A : Applicative.S) :
  Traversable.S with type 'a t := 'a possiblysizedtype and module A := A =
struct
  module Traversable_sizedtype = Make_traversable_sizedtype (A)

  let traverse x ~f =
    match x with
    | Sized ty ->
        A.map ~f:(fun ty -> Sized ty) @@ Traversable_sizedtype.traverse ~f ty
    | Unsized ty -> A.return @@ Unsized ty
end

module Make_traversable_possiblysizedtype2 (A : Applicative.S2) :
  Traversable.S2 with type 'a t := 'a possiblysizedtype and module A := A =
struct
  module Traversable_sizedtype = Make_traversable_sizedtype2 (A)

  let traverse x ~f =
    match x with
    | Sized ty ->
        A.map ~f:(fun ty -> Sized ty) @@ Traversable_sizedtype.traverse ~f ty
    | Unsized ty -> A.return @@ Unsized ty
end

type litType = Int | Real | Str [@@deriving sexp, hash, compare]

(**  *)
type fun_kind = StanLib | CompilerInternal | UserDefined
[@@deriving compare, sexp, hash]

type 'e index =
  | All
  | Single of 'e
  | Upfrom of 'e
  | Between of 'e * 'e
  | MultiIndex of 'e
[@@deriving sexp, hash, map, compare, fold]

module Make_traversable_index (A : Applicative.S) :
  Traversable.S with type 'a t := 'a index and module A := A = struct
  let traverse x ~f =
    match x with
    | All -> A.return All
    | Single e -> A.map ~f:(fun e -> Single e) (f e)
    | Upfrom e -> A.map ~f:(fun e -> Upfrom e) (f e)
    | MultiIndex e -> A.map ~f:(fun e -> MultiIndex e) (f e)
    | Between (e1, e2) ->
        A.map2 ~f:(fun e1 e2 -> Between (e1, e2)) (f e1) (f e2)
end

module Make_traversable_index2 (A : Applicative.S2) :
  Traversable.S2 with type 'a t := 'a index and module A := A = struct
  let traverse x ~f =
    match x with
    | All -> A.return All
    | Single e -> A.map ~f:(fun e -> Single e) (f e)
    | Upfrom e -> A.map ~f:(fun e -> Upfrom e) (f e)
    | MultiIndex e -> A.map ~f:(fun e -> MultiIndex e) (f e)
    | Between (e1, e2) ->
        A.map2 ~f:(fun e1 e2 -> Between (e1, e2)) (f e1) (f e2)
end

type 'e expr =
  | Var of string
  | Lit of litType * string
  | FunApp of fun_kind * string * 'e list
  | TernaryIf of 'e * 'e * 'e
  | EAnd of 'e * 'e
  | EOr of 'e * 'e
  | Indexed of 'e * 'e index list
[@@deriving sexp, hash, map, compare, fold]

module Make_traversable_expr (A : Applicative.S) :
  Traversable.S with type 'a t := 'a expr and module A := A = struct
  module Traversable_index = Make_traversable_index (A)

  let traverse x ~f =
    match x with
    | Var n -> A.return @@ Var n
    | Lit (ty, n) -> A.return @@ Lit (ty, n)
    | FunApp (fn_kind, name, args) ->
        List.map ~f args |> A.all
        |> A.map ~f:(fun args -> FunApp (fn_kind, name, args))
    | TernaryIf (pred, te, fe) ->
        A.map3
          ~f:(fun pred te fe -> TernaryIf (pred, te, fe))
          (f pred) (f te) (f fe)
    | EAnd (e1, e2) -> A.map2 ~f:(fun e1 e2 -> EAnd (e1, e2)) (f e1) (f e2)
    | EOr (e1, e2) -> A.map2 ~f:(fun e1 e2 -> EOr (e1, e2)) (f e1) (f e2)
    | Indexed (e, idxs) ->
        List.map ~f:(Traversable_index.traverse ~f) idxs
        |> A.all
        |> A.map2 ~f:(fun e idxs -> Indexed (e, idxs)) (f e)
end

module Make_traversable_expr2 (A : Applicative.S2) :
  Traversable.S2 with type 'a t := 'a expr and module A := A = struct
  module Traversable_index = Make_traversable_index2 (A)

  let traverse x ~f =
    match x with
    | Var n -> A.return @@ Var n
    | Lit (ty, n) -> A.return @@ Lit (ty, n)
    | FunApp (fn_kind, name, args) ->
        List.map ~f args |> A.all
        |> A.map ~f:(fun args -> FunApp (fn_kind, name, args))
    | TernaryIf (pred, te, fe) ->
        A.map3
          ~f:(fun pred te fe -> TernaryIf (pred, te, fe))
          (f pred) (f te) (f fe)
    | EAnd (e1, e2) -> A.map2 ~f:(fun e1 e2 -> EAnd (e1, e2)) (f e1) (f e2)
    | EOr (e1, e2) -> A.map2 ~f:(fun e1 e2 -> EOr (e1, e2)) (f e1) (f e2)
    | Indexed (e, idxs) ->
        List.map ~f:(Traversable_index.traverse ~f) idxs
        |> A.all
        |> A.map2 ~f:(fun e idxs -> Indexed (e, idxs)) (f e)
end



type 's fun_def =
  { fdrt: unsizedtype option
  ; fdname: string
  ; fdargs: (autodifftype * string * unsizedtype) list
  ; fdbody: 's
  ; fdloc: Location_span.t sexp_opaque [@compare.ignore] }
[@@deriving sexp, hash, map]

module Make_traversable_fun_def(A:Applicative.S) 
  : Traversable.S with module A := A and type 'a t := 'a fun_def 
= struct
  let traverse ({fdbody;_} as fun_def) ~f = 
    A.map ~f:(fun fdbody -> {fun_def with fdbody }) @@ f fdbody
end


module Make_traversable_fun_def2(A:Applicative.S2) 
  : Traversable.S2 with module A := A and type 'a t := 'a fun_def 
= struct
  let traverse ({fdbody;_} as fun_def) ~f = 
    A.map ~f:(fun fdbody -> {fun_def with fdbody }) @@ f fdbody
end


type ('e, 's) statement =
  | Assignment of (string * 'e index list) * 'e
  | TargetPE of 'e
  | NRFunApp of fun_kind * string * 'e list
  | Break
  | Continue
  | Return of 'e option
  | Skip
  | IfElse of 'e * 's * 's option
  | While of 'e * 's
  (* XXX Collapse with For? *)
  | For of {loopvar: string; lower: 'e; upper: 'e; body: 's}
  (* A Block for now corresponds tightly with a C++ block:
     variables declared within it have local scope and are garbage collected
     when the block ends.*)
  | Block of 's list
  (* SList has no semantics, just programming convenience *)
  | SList of 's list
  | Decl of
      { decl_adtype: autodifftype
      ; decl_id: string
      ; decl_type: 'e possiblysizedtype }
[@@deriving sexp, hash, map, fold, compare]

module Make_traversable_statement (A : Applicative.S) :
  Bitraversable.S with type ('a, 'b) t := ('a, 'b) statement and module A := A =
struct
  module Traversable_index = Make_traversable_index (A)
  module Traversable_possiblysizedtype = Make_traversable_possiblysizedtype (A)

  let traverse x ~f ~g =
    match x with
    | Break -> A.return Break
    | Continue -> A.return Continue
    | Skip -> A.return Skip
    | TargetPE e -> A.map ~f:(fun e -> TargetPE e) (f e)
    | Assignment ((name, idxs), e) ->
        let idxs = A.all @@ List.map ~f:(Traversable_index.traverse ~f) idxs in
        let e = f e in
        A.map2 ~f:(fun idxs e -> Assignment ((name, idxs), e)) idxs e
    | NRFunApp (fn_kind, name, args) ->
        List.map ~f args |> A.all
        |> A.map ~f:(fun args -> NRFunApp (fn_kind, name, args))
    | Return (Some e) -> A.map ~f:(fun e -> Return (Some e)) @@ f e
    | Return _ -> A.return @@ Return None
    | IfElse (pred, ts, Some fs) ->
        A.map3
          ~f:(fun pred ts fs -> IfElse (pred, ts, Some fs))
          (f pred) (g ts) (g fs)
    | IfElse (pred, ts, _) ->
        A.map2 ~f:(fun pred ts -> IfElse (pred, ts, None)) (f pred) (g ts)
    | While (pred, body) ->
        A.map2 ~f:(fun pred body -> While (pred, body)) (f pred) (g body)
    | For {loopvar; lower; upper; body} ->
        A.map3
          ~f:(fun lower upper body -> For {loopvar; lower; upper; body})
          (f lower) (f upper) (g body)
    | Block xs -> List.map ~f:g xs |> A.all |> A.map ~f:(fun xs -> Block xs)
    | SList xs -> List.map ~f:g xs |> A.all |> A.map ~f:(fun xs -> SList xs)
    | Decl decl ->
        Traversable_possiblysizedtype.traverse ~f decl.decl_type
        |> A.map ~f:(fun decl_type -> Decl {decl with decl_type})
end

module Make_traversable_statement2 (A : Applicative.S2) :
  Bitraversable.S2 with type ('a, 'b) t := ('a, 'b) statement and module A := A =
struct
  module Traversable_index = Make_traversable_index2 (A)
  module Traversable_possiblysizedtype = Make_traversable_possiblysizedtype2 (A)

  let traverse x ~f ~g =
    match x with
    | Break -> A.return Break
    | Continue -> A.return Continue
    | Skip -> A.return Skip
    | TargetPE e -> A.map ~f:(fun e -> TargetPE e) (f e)
    | Assignment ((name, idxs), e) ->
        let idxs = A.all @@ List.map ~f:(Traversable_index.traverse ~f) idxs in
        let e = f e in
        A.map2 ~f:(fun idxs e -> Assignment ((name, idxs), e)) idxs e
    | NRFunApp (fn_kind, name, args) ->
        List.map ~f args |> A.all
        |> A.map ~f:(fun args -> NRFunApp (fn_kind, name, args))
    | Return (Some e) -> A.map ~f:(fun e -> Return (Some e)) @@ f e
    | Return _ -> A.return @@ Return None
    | IfElse (pred, ts, Some fs) ->
        A.map3
          ~f:(fun pred ts fs -> IfElse (pred, ts, Some fs))
          (f pred) (g ts) (g fs)
    | IfElse (pred, ts, _) ->
        A.map2 ~f:(fun pred ts -> IfElse (pred, ts, None)) (f pred) (g ts)
    | While (pred, body) ->
        A.map2 ~f:(fun pred body -> While (pred, body)) (f pred) (g body)
    | For {loopvar; lower; upper; body} ->
        A.map3
          ~f:(fun lower upper body -> For {loopvar; lower; upper; body})
          (f lower) (f upper) (g body)
    | Block xs -> List.map ~f:g xs |> A.all |> A.map ~f:(fun xs -> Block xs)
    | SList xs -> List.map ~f:g xs |> A.all |> A.map ~f:(fun xs -> SList xs)
    | Decl decl ->
        Traversable_possiblysizedtype.traverse ~f decl.decl_type
        |> A.map ~f:(fun decl_type -> Decl {decl with decl_type})
end

type io_block = Parameters | TransformedParameters | GeneratedQuantities
[@@deriving sexp, hash]

type 'e outvar =
  { out_unconstrained_st: 'e sizedtype
  ; out_constrained_st: 'e sizedtype
  ; out_block: io_block }
[@@deriving sexp, map, hash]


module Make_traversable_outvar(A:Applicative.S) 
  : Traversable.S with module A := A and type 'a t := 'a outvar 
= struct
  module Traversable_sizedtype = Make_traversable_sizedtype(A)

  let traverse ({out_constrained_st;out_unconstrained_st;_} as outvar) ~f = 
    A.map2 
      ~f:(fun out_constrained_st out_unconstrained_st -> 
          {outvar with 
            out_constrained_st = out_constrained_st
            ; out_unconstrained_st = out_unconstrained_st
           }
      ) 
      (Traversable_sizedtype.traverse ~f out_constrained_st)
      (Traversable_sizedtype.traverse ~f out_unconstrained_st)
end

module Make_traversable_outvar2(A:Applicative.S2) 
  : Traversable.S2 with module A := A and type 'a t := 'a outvar 
= struct
  module Traversable_sizedtype = Make_traversable_sizedtype2(A)

  let traverse ({out_constrained_st;out_unconstrained_st;_} as outvar) ~f = 
    A.map2 
      ~f:(fun out_constrained_st out_unconstrained_st -> 
          {outvar with 
            out_constrained_st = out_constrained_st
            ; out_unconstrained_st = out_unconstrained_st
           }
      ) 
      (Traversable_sizedtype.traverse ~f out_constrained_st)
      (Traversable_sizedtype.traverse ~f out_unconstrained_st)
end

type ('e, 's) prog =
  { functions_block: 's fun_def list
  ; input_vars: (string * 'e sizedtype) list
  ; prepare_data: 's list (* data & transformed data decls and statements *)
  ; log_prob: 's list (*assumes data & params are in scope and ready*)
  ; generate_quantities: 's list (* assumes data & params ready & in scope*)
  ; transform_inits: 's list
  ; output_vars: (string * 'e outvar) list
  ; prog_name: string
  ; prog_path: string }
[@@deriving sexp, map]


module Make_traversable_prog(A:Applicative.S) 
  : Bitraversable.S with module A := A and type ('a,'b) t := ('a,'b) prog
= struct

  module Traversable_fun_def = Make_traversable_fun_def(A)
  module Traversable_sizedtype = Make_traversable_sizedtype(A)
  module Traversable_outvar = Make_traversable_outvar(A)

  let traverse prog ~f ~g = 
    let functions_block = 
      prog.functions_block
      |> List.map ~f:(Traversable_fun_def.traverse ~f:g)   
      |> A.all
    and input_vars = 
      prog.input_vars
      |> List.map ~f:(fun (str,st) -> 
          Traversable_sizedtype.traverse ~f st 
          |> A.map ~f:(fun st -> (str,st))
          ) 
      |> A.all
    and prepare_data = 
      List.map prog.prepare_data ~f:g
      |> A.all 
    and log_prob = 
      List.map prog.log_prob ~f:g
      |> A.all 
    and transform_inits = 
      List.map prog.transform_inits ~f:g
      |> A.all 
    and generate_quantities = 
      List.map prog.generate_quantities ~f:g
      |> A.all 
    and output_vars = 
      List.map prog.output_vars 
        ~f:(fun (str,outvar) -> 
          Traversable_outvar.traverse ~f outvar 
          |> A.map ~f:(fun st -> (str,st))) 
      |> A.all
    in

    A.(return (fun functions_block input_vars prepare_data log_prob generate_quantities transform_inits output_vars  ->
      { prog with 
        functions_block = functions_block
      ; input_vars = input_vars
      ; prepare_data = prepare_data 
      ; log_prob = log_prob 
      ; generate_quantities = generate_quantities 
      ; transform_inits = transform_inits
      ; output_vars = output_vars  
      }
    )
    <*> functions_block
    <*> input_vars
    <*> prepare_data
    <*> log_prob
    <*> generate_quantities
    <*> transform_inits
    <*> output_vars
  )


end



module Make_traversable_prog2(A:Applicative.S2) 
  : Bitraversable.S2 with module A := A and type ('a,'b) t := ('a,'b) prog
= struct

  module Traversable_fun_def = Make_traversable_fun_def2(A)
  module Traversable_sizedtype = Make_traversable_sizedtype2(A)
  module Traversable_outvar = Make_traversable_outvar2(A)

  let traverse prog ~f ~g = 
    let functions_block = 
      prog.functions_block
      |> List.map ~f:(Traversable_fun_def.traverse ~f:g)   
      |> A.all
    and input_vars = 
      prog.input_vars
      |> List.map ~f:(fun (str,st) -> 
          Traversable_sizedtype.traverse ~f st 
          |> A.map ~f:(fun st -> (str,st))
          ) 
      |> A.all
    and prepare_data = 
      List.map prog.prepare_data ~f:g
      |> A.all 
    and log_prob = 
      List.map prog.log_prob ~f:g
      |> A.all 
    and transform_inits = 
      List.map prog.transform_inits ~f:g
      |> A.all 
    and generate_quantities = 
      List.map prog.generate_quantities ~f:g
      |> A.all 
    and output_vars = 
      List.map prog.output_vars 
        ~f:(fun (str,outvar) -> 
          Traversable_outvar.traverse ~f outvar 
          |> A.map ~f:(fun st -> (str,st))) 
      |> A.all
    in

    A.(return (fun functions_block input_vars prepare_data log_prob generate_quantities transform_inits output_vars  ->
      { prog with 
        functions_block = functions_block
      ; input_vars = input_vars
      ; prepare_data = prepare_data 
      ; log_prob = log_prob 
      ; generate_quantities = generate_quantities 
      ; transform_inits = transform_inits
      ; output_vars = output_vars  
      }
    )
    <*> functions_block
    <*> input_vars
    <*> prepare_data
    <*> log_prob
    <*> generate_quantities
    <*> transform_inits
    <*> output_vars
  )
end

type internal_fn =
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