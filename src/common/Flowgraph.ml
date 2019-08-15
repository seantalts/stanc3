open Core_kernel

module type Basic = sig
  type t

  module Label : Label.S

  val flow_of_t : t -> (Label.t * Label.t) list
  val initial_label_of_t : t -> Label.t
  val final_labels_of_t : t -> Label.Set.t
  val associations_of_t : t -> t Label.Map.t
  val t_of_associations : t Label.Map.t -> t option
end

module type S = sig
  type t

  module Label : Label.S

  type flowgraph_info =
    { flowgraph: (Label.t * Label.t) list
    ; initials: Label.Set.t
    ; associations: t Label.Map.t }

  val flowgraph_info_of_t : t -> flowgraph_info
  val flow_of_t : t -> (Label.t * Label.t) list
  val extremal_labels_of_t : t -> Label.Set.t
  val associations_of_t : t -> t Label.Map.t
  val t_of_associations : t Label.Map.t -> t option
end

module Make (X : Basic) : S with type t = X.t and module Label = X.Label =
struct
  type t = X.t

  module Label = X.Label

  type flowgraph_info =
    { flowgraph: (Label.t * Label.t) list
    ; initials: Label.Set.t
    ; associations: t Label.Map.t }

  let flow_of_t = X.flow_of_t
  let associations_of_t = X.associations_of_t
  let t_of_associations = X.t_of_associations
  let extremal_labels_of_t x = Label.Set.singleton @@ X.initial_label_of_t x

  let flowgraph_info_of_t x =
    { flowgraph= flow_of_t x
    ; initials= extremal_labels_of_t x
    ; associations= associations_of_t x }
end

module Make_reverse (X : Basic) :
  S with type t = X.t and module Label = X.Label = struct
  type t = X.t

  module Label = X.Label

  type flowgraph_info =
    { flowgraph: (Label.t * Label.t) list
    ; initials: Label.Set.t
    ; associations: t Label.Map.t }

  let flow_of_t x = X.flow_of_t x |> List.map ~f:(fun (l1, l2) -> (l2, l1))
  let associations_of_t = X.associations_of_t
  let t_of_associations = X.t_of_associations
  let extremal_labels_of_t x = X.final_labels_of_t x

  let flowgraph_info_of_t x =
    { flowgraph= flow_of_t x
    ; initials= extremal_labels_of_t x
    ; associations= associations_of_t x }
end