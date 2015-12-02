
(*
 * Elements
 *)

module Result = struct
  module Public = struct
    type ('a, 'e) result =
      | Ok    of 'a
      | Error of 'e

    let ok x = Ok x
    let error x = Error x
  end

  include Public

  type ('a, 'e) t = ('a, 'e) result

  let (!) r =
    match r with
    | Ok x -> x
    | Error exn -> raise exn
end

module type Type = sig
  type t
end

module type Functor = sig
  type 'a t
  val map : ('a -> 'b) -> 'a t -> 'b t
end

module Id = struct
  module Make (X : Type) = X

  type 'a t = 'a
  let map f x = f x
end

module T2 = struct
  type ('a, 'b) t = ('a * 'b)
  let map f (x, y) = (x, f y)
end

module type Monad = sig
  type 'a t
  val return : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
end

module Fn = struct
  type ('a, 'b) t = 'a -> 'b
  let compose f g = fun x -> f (g x)
  let invcompose g f = fun x -> f (g x)
  let apply f x = f x
  let map f x = compose f x
  let id x = x
  let flip f x y = f y x
  let (@@) = apply
  let (@.) = compose
  let (|>) = invcompose

  module Public = struct
    let (@.) = (@.)
    let (|>) = (|>)
    let id = id
    let flip = flip
  end
end

module Opt = struct

  type 'a t = 'a option
  exception No_value

  let some x = Some x
  let none = None

  let option ~none:if_none ~some:if_some opt =
    match opt with
    | None -> Lazy.force if_none
    | Some a -> if_some a

  let value_exn opt =
    match opt with
    | Some x -> x
    | None -> raise No_value

  let value ~default opt =
    match opt with
    | Some x -> x
    | None -> default

  let return x = Some x

  let (>>=) opt f =
    match opt with
    | Some x -> f x
    | None -> None

  let (>>|) opt f =
    match opt with
    | Some x -> Some (f x)
    | None -> None

  let (>>) opt1 opt2 =
    opt1 >>= fun _ -> opt2

  let (||) opt default =
    value ~default opt

  let (!) opt = value_exn opt

  module Public = struct
    let some = some
    let none = none
    let option = option
  end
end

module Exn = struct

  let guard f x =
    try Result.Ok (f x)
    with e -> Result.Error e

  let fail msg = raise (Failure msg)

  module Public = struct
    let guard = guard
    let fail = fail
  end

  let to_string = Printexc.to_string
end

module List = struct
  open Result.Public

  type 'a t = 'a list

  module Public = struct
    let cons x xs = x::xs
  end

  let partition l ~f = StdLabels.List.partition ~f l
  let fold_left l ~init ~f = StdLabels.List.fold_left l ~f ~init
  let fold_right l ~init ~f = StdLabels.List.fold_right l ~f ~init
  let fold = fold_left

  let rec all xs ~f =
    match xs with
    | []               -> true
    | x :: xs when f x -> all xs ~f
    | _                -> false

  let rev l =
    let rec loop acc l =
      match l with
      | x::xs -> loop (x::acc) xs
      | [] -> acc in
    loop [] l

  let len l =
    let rec loop acc l =
      match l with
      | _::xs -> loop (acc + 1) xs
      | [] -> acc in
    loop 0 l

  let rec range s e =
    if s = e then []
    else s::range (s + 1) e

  let iota = range 0

  let map l ~f =
    rev (fold l ~f:(fun acc e -> f e::acc) ~init:[])

  let nth l n =
    if n < 0 then
      Error (Invalid_argument "nth: negative index")
    else
      let rec go l n =
        match l with
        | [] -> Error (Failure "nth: list index out of range")
        | x :: xs -> if n = 0 then Ok x else go xs (n - 1) in
      go l n

  let rec iter f l =
    match l with
    | [] -> ()
    | x :: xs -> f x; iter f xs

  let iteri l ~f =
    let rec go i l =
      match l with
      | [] -> ()
      | x :: xs -> f i x; go (i + 1) xs in
    go 0 l

  let filter_map l ~f =
    let res =
      fold l ~init:[] ~f:(fun acc e -> f e::acc) in
    fold res ~init:[]
      ~f:(fun acc -> function None -> acc | Some x -> x::acc)

  let reduce l ~f =
    match l with
    | x::xs -> Ok (fold xs ~f ~init:x)
    | [] -> Error (Failure "reduce: empty list with no initial value")

  let reduce_exn l ~f = Result.(!) (reduce l ~f)

  let find l ?key ~f =
    match key with
    | None -> reduce l ~f
    | Some key -> reduce l ~f:(fun a b -> if f (key a) (key b) then a else b)

  let min ?key l =
    match key with
    | None -> reduce l ~f:min
    | Some key -> reduce l ~f:(fun a b -> if (key a < key b) then a else b)

  let max ?key l =
    match key with
    | None -> reduce l ~f:Pervasives.max
    | Some key -> reduce l ~f:(fun a b -> if (key a > key b) then a else b)

  (* TODO: Inv *)
  let max_all ?(key = Fn.id) l =
    match l with
    | [] | [_] -> l
    | x::xs -> fst begin
        fold xs ~init:([x], key x)
          ~f:begin fun (acc, el) i ->
            let v = key i in
            match () with
            | () when el < v -> ([i], v)
            | () when el = v -> (i::acc, el)
            | ()             -> (acc, el)
          end
      end

  let group_with l ~f =
    let rec loop acc l =
      match l with
      | [] -> acc
      | x::_ as l ->
        let ltrue, lfalse = partition l ~f:(f x) in
        if len ltrue = 0 then
          [x] :: acc
        else
          loop (ltrue :: acc) lfalse in
    loop [] l

  let take l n =
    let rec loop l n acc =
      if n = 0 then rev acc
      else match l with
        | x::xs -> loop xs (n - 1) (x :: acc)
        | [] -> rev acc in
    loop l n []

end

module Str = struct
  include String

  let split ?(sep=' ') str =
    let rec indices acc i =
      try
        let i = succ (String.index_from str i sep) in
        indices (i::acc) i
      with Not_found ->
        (String.length str + 1) :: acc
    in
    let is = indices [0] 0 in
    let rec aux acc = function
      | last::start::tl ->
        let w = String.sub str start (last - start - 1) in
        aux (w::acc) (start::tl)
      | _ -> acc
    in
    aux [] is
end

module Either = struct
  module Public = struct
    type ('a, 'b) either =
      | Left  of 'a
      | Right of 'b

    let either f g x =
      match x with
      | Left  l -> f l
      | Right r -> g r
  end
  include Public
  type ('a, 'b) t = ('a, 'b) either

  let return x = Right x

  let (>>=) m f =
    match m with
    | Right x -> f x
    | Left e  -> Left e
end

module Void = struct
  (* Author: Joseph Abrahamson <me@jspha.com>
     Source: <https://github.com/tel/ocaml-cats> *)

  (** The impossible type: no values can be made to exist.
      Values of type {!t} cannot be made to exist, there are no
      introduction forms. This makes them the impossible type; however,
      they are not without their use. A function which claims to return
      {!t} must actually never return. A hypothetical situation which
      offers a value of {!t} must be {!absurd}.
      Technically this should be the bottom type but there's no way to
      convince OCaml of this fact.
  *)

  (** The nonexistent data type. *)
  type t = { absurd : 'a . 'a }

  let absurd t = t.absurd
  (** It is possible in some hypothetical contexts to have access to a
      value of type {!t}. As no values of {!t} can ever come into
      existence we resolve that our hypotheses are wrong and thus
      conclude whatever we like.
      In pithier words, {i from nothing comes anything}.
  *)
  
  module Public = struct
    type void = t
  end
end

module Lazy = struct
  include Lazy
  let (!) = Lazy.force
end

module Base = struct
  include Either.Public
  include Exn.Public
  include Fn.Public
  include List.Public
  include Opt.Public
  include Void.Public
  include Result.Public

  let discard _ = ()

  let time f x =
    let t = Unix.gettimeofday () in
    let fx = f x in
    Printf.printf "Elapsed time: %f sec\n"
      (Unix.gettimeofday () -. t);
    fx

  (* Printing and Formatting *)

  let print = print_endline
  let fmt = Printf.sprintf

  (* Numeric Primitives *)

  let even n = n mod 2 = 0
  let odd  n = n mod 2 = 1

  (* Channel *)
  let output_line chan line =
    output_string chan (line ^ "\n")

end

include Base

module Log = struct
  let out level msg = output_line stderr (fmt "%s: %s"  level msg); flush stderr
  let inf msg = out "inf" msg
  let err msg = out "err" msg
  let wrn msg = out "wrn" msg
end


