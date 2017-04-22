(* Semantic checking for the MicroC compiler *)

open Ast
open Str
module StringMap = Map.Make(String)

(* Semantic checking of a program. Returns void if successful,
   throws an exception if something is wrong.

   Check each global variable, then check each function *)

let check (globals, functions, structs) =

  (* Raise an exception if the given list has a duplicate *)
  let report_duplicate exceptf list =
    let rec helper = function
  n1 :: n2 :: _ when n1 = n2 -> raise (Failure (exceptf n1))
      | _ :: t -> helper t
      | [] -> ()
    in helper (List.sort compare list)
  in

  (* Raise an exception if a given binding is to a void type *)
  let check_not_void exceptf = function
    (Void, n) -> raise (Failure (exceptf n))
    | (String, x) -> ()
    | _ -> ()
  in
  
  (* Raise an exception of the given rvalue type cannot be assigned to
     the given lvalue type *)
  let check_assign lvaluet rvaluet err =
    if lvaluet == rvaluet then lvaluet else raise err
  in

  let check_assign_func lvaluet rvaluet =
    if lvaluet == rvaluet then true else false
  in
  
  (** Methods for structs **)
  let match_struct_to_accessor a b = 
    let s1 = try List.find (fun s-> s.sname=a) structs 
      with Not_found -> raise (Failure("Struct of name " ^ a ^ "not found.")) in
    try fst( List.find (fun s-> snd(s)=b) s1.sformals) 
      with Not_found -> raise (Failure("Struct " ^ a ^ " does not have field " ^ b))
  in

  let check_access lvaluet rvalues =
     match lvaluet with
       StructType s -> match_struct_to_accessor s rvalues
       | _ -> raise (Failure(string_of_typ lvaluet ^ " is not a struct"))
  
  in

  let r = Str.regexp "hello \\([A-Za-z]+\\)" in
  (*
  let add_default_sformals user_struct =
    if user_struct.sname = "Player" then
      begin
        let predefined_formals = [(CoordinateType, "position"); (Bool, "win"); (String, "displayString")] 
        in
          let user_struct.modified_sformals = List.append user_struct.sformals predefined_formals
      end
  in
  *)
  (**** Checking Global Variables ****)

  List.iter (check_not_void (fun n -> "illegal void global " ^ n)) globals;
   
  report_duplicate (fun n -> "duplicate global " ^ n) (List.map snd globals);

  (**** Checking Structs ****)
 
  report_duplicate (fun n -> "duplicate struct " ^ n)
    (List.map (fun sd -> sd.sname) structs);
  
  (* List.iter add_default_sformals structs; *)
  
  (*
  let struct_decls = List.fold_left (fun m fd -> StringMap.add fd.fname fd m)
                         built_in_decls functions
  in

  let function_decl s = try StringMap.find s function_decls
       with Not_found -> raise (Failure (s ^ " function is either missing or unrecognized") )

  type func_decl = {
      typ : typ;
      fname : string;
      formals : bind list;
      locals : bind list;
      body : stmt list;
    }

  type struct_decl = {   (* for adding player datatype *)
      sname: string;
      sformals: bind list;
  }
  *)
  
  (**** Checking Functions ****)

  if List.mem "print" (List.map (fun fd -> fd.fname) functions)
  then raise (Failure ("function print may not be defined")) else ();

  report_duplicate (fun n -> "duplicate function " ^ n)
    (List.map (fun fd -> fd.fname) functions);

  (* Function declaration for a named function *)
  let built_in_decls =  StringMap.add "print"
     { typ = Void; fname = "print"; formals = [( Int, "x")];
       locals = []; body = [] } (StringMap.add "printf"
     { typ = Void; fname = "printf"; formals = [(String, "x")];
       locals = []; body = [] } (StringMap.singleton "printbig"
     { typ = Void; fname = "printbig"; formals = [(Int, "x")];
       locals = []; body = [] }))
   in
     
  let function_decls = List.fold_left (fun m fd -> StringMap.add fd.fname fd m)
                         built_in_decls functions
  in

  let function_decl s = try StringMap.find s function_decls
       with Not_found -> raise (Failure (s ^ " function is either missing or unrecognized") )
  in

  (* 
  let _ = function_decl "layout" in (* Ensure "layout" is defined *)
  *)
  let _ = function_decl "gameloop" in (* Ensure "gameloop" is defined *)
  (* 
  let _ = function_decl "colocation" in (* Ensure "coLocation" is defined *)
  let _ = function_decl "checkGameEnd" in (* Ensure "checkGameEnd" is defined *)
  let _ = function_decl "gameOver" in (* Ensure "gameOver" is defined *) 
  *)

  let check_function func =
    
    List.iter (check_not_void (fun n -> "illegal void formal " ^ n ^
      " in " ^ func.fname)) func.formals;

    report_duplicate (fun n -> "duplicate formal " ^ n ^ " in " ^ func.fname)
      (List.map snd func.formals);

    List.iter (check_not_void (fun n -> "illegal void local " ^ n ^
      " in " ^ func.fname)) func.locals;

    report_duplicate (fun n -> "duplicate local " ^ n ^ " in " ^ func.fname)
      (List.map snd func.locals);

    (* Type of each variable (global, formal, or local *)
    let symbols = List.fold_left (fun m (t, n) -> StringMap.add n t m)
  StringMap.empty (globals @ func.formals @ func.locals )
    in

    let type_of_identifier s =
      try StringMap.find s symbols
      with Not_found -> raise (Failure ("undeclared identifier " ^ s))
    in

    (* Return the type of an expression or throw an exception *)
    let rec expr = function
      Literal _ -> Int
      | BoolLit _ -> Bool
      | String_Lit _ -> String
      | Id s -> type_of_identifier s
      | Dotop(e1, field) -> let lt = expr e1 in
         check_access (lt) (field)
      | Binop(e1, op, e2) as e -> let t1 = expr e1 and t2 = expr e2 in
  (match op with
          Add | Sub | Mult | Div when t1 = Int && t2 = Int -> Int
  | Equal | Neq when t1 = t2 -> Bool
  | Less | Leq | Greater | Geq when t1 = Int && t2 = Int -> Bool
  | And | Or when t1 = Bool && t2 = Bool -> Bool
        | _ -> raise (Failure ("illegal binary operator " ^
              string_of_typ t1 ^ " " ^ string_of_op op ^ " " ^
              string_of_typ t2 ^ " in " ^ string_of_expr e))
        )
      | Unop(op, e) as ex -> let t = expr e in
   (match op with
     Neg when t = Int -> Int
   | Not when t = Bool -> Bool
         | _ -> raise (Failure ("illegal unary operator " ^ string_of_uop op ^
           string_of_typ t ^ " in " ^ string_of_expr ex)))
      | Noexpr -> Void
      | Assign(var, e) as ex -> let lt = expr var
                                and rt = expr e in
        check_assign lt rt (Failure ("illegal assignment " ^ string_of_typ lt ^
             " = " ^ string_of_typ rt ^ " in " ^ 
             string_of_expr ex))
      | Call(fname, actuals) as call -> let fd = function_decl fname in
         if List.length actuals != List.length fd.formals then
           raise (Failure ("expecting " ^ string_of_int
             (List.length fd.formals) ^ " arguments in " ^ string_of_expr call))
         else
           List.iter2 (fun (ft, _) e -> let et = expr e in
              if fd = function_decl "print" then
                begin
                  if check_assign_func ft et = false then
                    if check_assign_func String et = false then
                      raise (Failure "fuck off")
                end
              else
                if check_assign_func ft et = false then 
                  raise (Failure ("illegal actual argument found " ^ string_of_typ et ^
                  " expected " ^ string_of_typ ft ^ " in " ^ string_of_expr e) )  ) 
              fd.formals actuals;
            fd.typ
    in

    let check_bool_expr e = if expr e != Bool
     then raise (Failure ("expected Boolean expression in " ^ string_of_expr e))
     else () in

    (* Verify a statement or throw an exception *)
    let rec stmt = function
  Block sl -> let rec check_block = function
           [Return _ as s] -> stmt s
         | Return _ :: _ -> raise (Failure "nothing may follow a return")
         | Block sl :: ss -> check_block (sl @ ss)
         | s :: ss -> stmt s ; check_block ss
         | [] -> ()
        in check_block sl
      | Expr e -> ignore (expr e)
      | Return e -> let t = expr e in if t = func.typ then () else
         raise (Failure ("return gives " ^ string_of_typ t ^ " expected " ^
                         string_of_typ func.typ ^ " in " ^ string_of_expr e))
           
      | If(p, b1, b2) -> check_bool_expr p; stmt b1; stmt b2
      | For(e1, e2, e3, st) -> ignore (expr e1); check_bool_expr e2;
                               ignore (expr e3); stmt st
      | While(p, s) -> check_bool_expr p; stmt s
    in

    stmt (Block func.body)
   
  in
  List.iter check_function functions
