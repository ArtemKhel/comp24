(** Copyright 2024, Artem Khelmianov *)

(** SPDX-License-Identifier: LGPL-2.1 *)

open Lib
open Base
open Format

let test code =
  let ast =
    match Parser.parse_program code with
    | Error e -> failwith e
    | Ok ast ->
      (match Inferencer.inference_program ast with
       | Error e -> failwith (asprintf "%a" Pp_typing.pp_error e)
       | Ok ast ->
         ast
         |> Remove_patterns.remove_patterns
         |> Remove_match.remove_match
         |> Closure_conversion.closure_conversion
         |> Lambda_lifting.lambda_lifting
         |> Anf.anf)
  in
  printf "%a" Anf_ast.pp_program ast
;;

let%expect_test _ =
  test {|
    let a = 42
  |};
  [%expect {| 
    let a = 42
  |}]
;;

let%expect_test _ =
  test {|
    let a = 1 + 2 - 42
  |};
  [%expect {|
    let a = let a1 = ( + ) 1 2 in
      ( - ) a1 42
    |}]
;;

let%expect_test _ =
  test {|
    let a = 
      let one = 1 in 
      let two = 2 in
      one + two
  |};
  [%expect {|
    let a = let a0 = 1 in
      let a1 = 2 in
      ( + ) a0 a1
    |}]
;;

let%expect_test _ =
  test
    {|
    let rec fact = fun x -> if x < 2 then 1 else x * fact (x - 1)
    let main = print_int (fact 5)
  |};
  [%expect
    {|
    let fact x =
      let a1 = ( < ) x 2 in
      if a1
      then 1
      else let a4 = ( - ) x 1 in
        let a3 = fact a4 in
        ( * ) x a3
    let main = let a6 = fact 5 in
      print_int a6
    |}]
;;

let%expect_test _ =
  test
    {|
      let fact n =
        let rec helper n cont =
          if n <= 1 then 
            cont 1
          else 
            helper (n - 1) (fun res -> cont (n * res)) 
        in 
        helper n (fun x -> x)
    |};
  [%expect
    {|
    let `ll_2 cont n res = let a1 = ( * ) n res in
      cont a1
    let `helper_1 n cont =
      let a3 = ( <= ) n 1 in
      if a3
      then cont 1
      else let a6 = ( - ) n 1 in
        let a7 = `ll_2 cont n in
        `helper_1 a6 a7
    let `ll_3 x = x
    let fact n = `helper_1 n `ll_3
    |}]
;;

let%expect_test _ =
  test
    {|
    let cross (x1, y1, z1) (x2, y2, z2) =
      let x = (y1 * z2) - (z1 * y2) in
      let y = (z1 * x2) - (x1 * z2) in
      let z = (x1 * y2) - (y1 * x2) in
      (x, y, z)
    
    let main = 
      let a = (1, 2, 3) in
      let b = (4, 5, 6) in
      let c = cross a b in
      print_tuple c
    |};
  [%expect
    {|
    let cross `arg_0 `arg_1 =
      let a2 = `get_tuple_field `arg_1 0 in
      let a4 = `get_tuple_field `arg_1 1 in
      let a6 = `get_tuple_field `arg_1 2 in
      let a9 = `get_tuple_field `arg_0 0 in
      let a11 = `get_tuple_field `arg_0 1 in
      let a13 = `get_tuple_field `arg_0 2 in
      let a24 = ( * ) a11 a6 in
      let a25 = ( * ) a13 a4 in
      let a15 = ( - ) a24 a25 in
      let a22 = ( * ) a13 a2 in
      let a23 = ( * ) a9 a6 in
      let a17 = ( - ) a22 a23 in
      let a20 = ( * ) a9 a4 in
      let a21 = ( * ) a11 a2 in
      let a19 = ( - ) a20 a21 in
      (a15, a17, a19)
    let main =
      let a26 = (1, 2, 3) in
      let a27 = (4, 5, 6) in
      let a29 = cross a26 a27 in
      print_tuple a29
    |}]
;;

let%expect_test _ =
  test
    {|
    let rec map f list = match list with
      | hd :: tl -> (f hd) :: (map f tl) 
      | [] -> []

    let rec map_ f list = match list with
      | hd :: tl -> f hd :: map f tl
      | _ -> []
  |};
  [%expect
    {|
    let map f list =
      let a9 = `list_is_empty list in
      let a1 = not a9 in
      if a1
      then
        let a3 = `list_hd list in
        let a5 = `list_tl list in
        let a7 = f a3 in
        let a8 = map f a5 in
        ( :: ) a7 a8
      else []
    let map_ f list =
      let a19 = `list_is_empty list in
      let a11 = not a19 in
      if a11
      then
        let a13 = `list_hd list in
        let a15 = `list_tl list in
        let a17 = f a13 in
        let a18 = map f a15 in
        ( :: ) a17 a18
      else []
    |}]
;;

(* let%expect_test _ =
  test {| |};
  [%expect {| |}]
;; *)
