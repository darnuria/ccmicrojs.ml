(**
  * ccmain.ml
  * Part of Micro-JavaScript Compiler
  *
  * 3I018 Compilation
  * Université Pierre et Marie Curie
  *
  *)
open Cmdliner
module P = Printf

(*
type verbosity =
  | Verbose
  | Quiet

let string_of_verbosity = function
  | Verbose -> "verbose"
  | Quiet -> "quiet"
*)

let parse_file filename =
  try
    let in_file = Pervasives.open_in filename in
    let lexbuf = Lexing.from_channel in_file in
    let prog = Parser.program Lexer.token lexbuf in
    Pervasives.close_in in_file;
    `Ok ({ prog with Ast.filename = filename })
  with Parseutils.Parse_Exception (msg, pos) ->
    let pos = (Parseutils.string_of_position pos)
      in `Error (P.sprintf "Parse error: %s\n(%s)\n" msg pos)

let write_target filename code =
    let out_file = Pervasives.open_out filename in
    List.iter (fun s -> Pervasives.output_string out_file s) code;
    Pervasives.close_out out_file


let compile_prog prog =
  Expander.expand_prog prog
  |> Compiler.compile_prog (Prim.init_prim_env ())

let result_string = P.sprintf
    "\n===========================\n%s\n===========================\n"

let select_action parse compile expand =
  if parse then
    (fun prog ->
       Ast.string_of_program prog
       |> result_string
       |> P.sprintf "Parsed program:%s")
   else if expand then
    (fun prog ->
       Expander.expand_prog prog
       |> Kast.string_of_kprogram
       |> result_string
       |> P.sprintf "Kernal Abstract Syntax Tree:%s")
   else if compile then
    (fun prog ->
      compile_prog prog
      |> Bytecode.string_of_bytecode
      |> result_string
      |> P.sprintf "Bytecode:%s")
   else
     failwith "Writing to file not implemented!"
    (* (fun prog ->
       expand_prog prog
       |> compile_prog (init_prim_env ())
       |> write_target filename)
      *)

(**
  * Command line Interface and Entry Point
  *)
let cmicrojs parse expand compile filename =
  let prog = parse_file filename in
  match prog with
  | `Ok prog ->
    if (parse <> compile <> expand) then
      let action = select_action parse compile expand in
      `Ok (P.printf "%s" (action prog))
    else
      `Error (false, "Compile to bytecode not implemented.")
  (* `Ok (compile_prog prog) *)
  | `Error msg -> `Error (false, msg)

let file =
  Arg.(required
       & pos ~rev:true 0 (some string) None
       & info [] ~docv:"SOURCE"
         ~doc:"Micro-JavaScript file(s) to process.")

let parse =
  Arg.(value & flag & info ["p"; "parse"]
         ~docv:"PARSE"
         ~doc:"Parse and show parsed program." )

let expand =
  Arg.(value & flag & info ["e"; "expand"]
         ~docv:"EXPAND"
         ~doc:"Parse, expand and show kernel abstract syntax tree")

let compile =
  Arg.(value & flag & info ["c"; "compile"]
      ~docv:"COMPILE"
      ~doc:"Parse, compile and show the compiled code")

let run =
  Arg.(value & flag & info ["r"; "run"]
         ~docv:"RUNNING"
         ~doc:"Compile and run program (debug mode)")

let generate =
  Arg.(value & flag & info ["g"; "gen"]
         ~docv:"GENERATE"
         ~doc:"Compile and generate target (default mode)")

let dot_graph =
  Arg.(value & flag & info ["astDot"]
         ~docv:"GENERATE"
         ~doc:"Compile and generate target (default mode)")

let verbosity =
  let verbose =
    Arg.info ["v"; "verbose"]
       ~doc:"Output full process on stdout" in
  Arg.(value & flag & verbose)

let cmd =
  (Term.(Term.ret(const cmicrojs $ parse $ expand $ compile $ file))
  , Term.info "cmicrojs"
      ~version:"0.0.1"
      ~doc:"Microjs compiler in Ocaml"
      ~man:
        [ `S "DESCRIPTION"
        ; `P "$(tname) is a compiler of Micro-Javascript language to\
              NativeVM bytecode."
        ; `P "BUGS: Report bugs to <frederic dot pechansky at lip6 dot fr>."])

(* See cmicrojs for real entry point *)
let () =
  match Term.eval cmd with
  |  `Error _ -> exit 1
  | _ -> exit 0
