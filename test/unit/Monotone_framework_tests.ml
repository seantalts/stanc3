open Std
open Middle
open Common
open Analysis_and_optimization
open Analysis_and_optimization.Dataflow_types

(* A chain of [n] diamonds: 1 -> {a, b} -> join -> {a, b} -> join ... *)
let diamond_chain n =
  let a i = (3 * i) + 2 and b i = (3 * i) + 3 and join i = (3 * i) + 4 in
  let edges =
    (1, [a 0; b 0])
    :: List.concat_map (List.range 0 n) ~f:(fun i ->
        [ (a i, [join i]); (b i, [join i])
        ; (join i, if i = n - 1 then [] else [a (i + 1); b (i + 1)]) ]) in
  (module struct
    type labels = int

    let initials = Set.Poly.singleton 1

    let successors =
      LabelMap.of_list
        (List.map edges ~f:(fun (l, succs) -> (l, Set.Poly.of_list succs)))
  end : Monotone_framework_sigs.FLOWGRAPH
    with type labels = int)

let%expect_test "mfp visits each node of an acyclic graph once" =
  let n = 20 in
  let (module F) = diamond_chain n in
  let calls = ref 0 in
  let (module Lattice) =
    Monotone_framework.powerset_lattice
      (module struct
        type vals = int

        let initial = Set.Poly.empty
      end) in
  let (module Transfer) =
    (module struct
      type labels = int
      type properties = int Set.Poly.t

      let transfer_function l p =
        incr calls;
        Set.Poly.add l p
    end : Monotone_framework_sigs.TRANSFER_FUNCTION
      with type labels = int
       and type properties = int Set.Poly.t) in
  let (module Mf) =
    Monotone_framework.monotone_framework
      (module F)
      (module Lattice)
      (module Transfer) in
  let result = Mf.mfp () in
  let last = LabelMap.find ((3 * (n - 1)) + 4) result in
  Fmt.pr "nodes: %d, transfer calls during iteration: %d, facts at exit: %d@."
    (LabelMap.cardinal F.successors)
    (!calls - LabelMap.cardinal F.successors)
    (Set.Poly.cardinal last.exit);
  [%expect
    {| nodes: 61, transfer calls during iteration: 61, facts at exit: 61 |}]

let live_variables_of_model model =
  Gensym.reset_danger_use_cautiously ();
  let mir = Test_utils.mir_of_string model in
  let stmt = Stmt.{pattern= SList mir.log_prob; meta= Location_span.empty} in
  let rev_flowgraph, flowgraph_to_mir =
    Monotone_framework.inverse_flowgraph_of_stmt stmt in
  let live =
    Monotone_framework.live_variables_mfp mir rev_flowgraph flowgraph_to_mir
  in
  let globals = Monotone_framework.globals mir in
  LabelMap.iter live ~f:(fun ~key ~data ->
      let local =
        Set.Poly.diff data.Monotone_framework_sigs.exit globals
        |> Set.Poly.to_list in
      let stmt = (LabelMap.find key flowgraph_to_mir).pattern in
      let kind =
        match stmt with
        | For {loopvar; _} -> "for " ^ loopvar
        | NRFunApp _ -> "print"
        | Block _ -> "block"
        | SList _ -> "list"
        | _ -> "other" in
      Fmt.pr "%d %s: live before {%a}@." key kind
        Fmt.(list ~sep:comma string)
        local)

let%expect_test "a loop variable is not live before its loop" =
  live_variables_of_model
    {|
      model {
        for (i in 1:2) print(i);
        for (j in 1:2) print(j);
      }
    |};
  [%expect
    {|
    1 list: live before {}
    2 block: live before {}
    3 for i: live before {}
    4 block: live before {}
    5 print: live before {i}
    6 for j: live before {}
    7 block: live before {}
    8 print: live before {j}
    |}]
