let run_program (grammar_file : string) : int =
  match Grammar.read_rules grammar_file with
  | Error message ->
      print_endline ("Error: " ^ message);
      1
  | Ok rules ->
      if rules = [] then
        (print_endline "Error: grammar file contains no valid rules."; 1)
      else
        let symbols = Grammar.symbols_from_rules rules in
        match Keyboard_input.validate_symbols symbols with
        | Error message ->
            print_endline ("Error: " ^ message);
            1
        | Ok () ->
            let max_buffer_length = Grammar.max_combo_length rules in
            let automaton = Grammar.train_automaton rules Automaton.empty_automaton in
            match Keyboard_input.run_training_mode automaton symbols max_buffer_length with
            | Ok () ->
                0
            | Error message ->
                print_endline ("Error: " ^ message);
                1

let () =
  let exit_code =
    match Sys.argv with
    | [| _program_name; grammar_file |] ->
        run_program grammar_file
    | _ ->
        print_endline "Usage: ./ft_ality <grammar_file>";
        1
  in
  exit exit_code
