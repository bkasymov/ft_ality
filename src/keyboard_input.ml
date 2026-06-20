type key_mapping = {
  key : string;
  symbol : Automaton.symbol;
}

let restore_terminal () : unit =
  ignore (Sys.command "stty sane 2>/dev/null")

let setup_raw_terminal () : unit =
  ignore (Sys.command "stty raw -echo isig 2>/dev/null")

let print_raw_line (line : string) : unit =
  print_string (line ^ "\r\n");
  flush stdout

let install_exit_signal_handler () : unit =
  let handle_signal (_signal_number : int) : unit =
    restore_terminal ();
    print_endline "";
    print_endline "Interrupted. Bye.";
    exit 0
  in
  Sys.set_signal Sys.sigint (Sys.Signal_handle handle_signal);
  Sys.set_signal Sys.sigterm (Sys.Signal_handle handle_signal)

let default_keys : string list =
  [
    "q"; "w"; "e"; "r"; "t"; "y"; "u"; "i"; "o"; "p";
    "a"; "s"; "d"; "f"; "g"; "h"; "j"; "k"; "l";
    "z"; "x"; "c"; "v"; "b"; "n"; "m";
    "1"; "2"; "3"; "4"; "5"; "6"; "7"; "8"; "9"; "0";
  ]

let rec list_length (items : 'a list) : int =
  match items with
  | [] ->
      0
  | _first_item :: remaining_items ->
      1 + list_length remaining_items

let rec build_key_mapping_loop (symbols : Automaton.symbol list) (keys : string list) : key_mapping list =
  match symbols with
  | [] ->
      []
  | first_symbol :: remaining_symbols ->
      match keys with
      | [] ->
          []
      | first_key :: remaining_keys ->
          { key = first_key; symbol = first_symbol } :: build_key_mapping_loop remaining_symbols remaining_keys

let max_key_count () : int =
  list_length default_keys

let validate_symbols (symbols : Automaton.symbol list) : (unit, string) result =
  let symbol_count = list_length symbols in
  let key_count = max_key_count () in
  if symbol_count > key_count then
    Error ("grammar uses " ^ string_of_int symbol_count ^ " symbols, but only " ^ string_of_int key_count ^ " keyboard keys are available")
  else
    Ok ()

let build_key_mapping (symbols : Automaton.symbol list) : (key_mapping list, string) result =
  match validate_symbols symbols with
  | Error message ->
      Error message
  | Ok () ->
      Ok (build_key_mapping_loop symbols default_keys)

let rec find_symbol_for_key (mapping : key_mapping list) (input_key : string) : Automaton.symbol option =
  match mapping with
  | [] ->
      None
  | first_mapping :: remaining_mapping ->
      if first_mapping.key = input_key || first_mapping.symbol = input_key then
        Some first_mapping.symbol
      else
        find_symbol_for_key remaining_mapping input_key

let rec print_key_mapping (mapping : key_mapping list) : unit =
  match mapping with
  | [] ->
      ()
  | first_mapping :: remaining_mapping ->
      print_raw_line (first_mapping.key ^ " -> " ^ first_mapping.symbol);
      print_key_mapping remaining_mapping

let print_move_names (move_names : string list) : unit =
  let rec print_loop (names : string list) : unit =
    match names with
    | [] ->
        ()
    | first_name :: remaining_names ->
        print_raw_line (first_name ^ " !!");
        print_loop remaining_names
  in
  print_loop move_names

let rec drop_oldest (items : 'a list) (count : int) : 'a list =
  if count <= 0 then
    items
  else
    match items with
    | [] ->
        []
    | _first_item :: remaining_items ->
        drop_oldest remaining_items (count - 1)

let trim_to_length (items : 'a list) (max_length : int) : 'a list =
  let extra_items = list_length items - max_length in
  if extra_items > 0 then
    drop_oldest items extra_items
  else
    items

let append_recent_symbol (buffer : Automaton.symbol list) (max_length : int) (symbol : Automaton.symbol) : Automaton.symbol list =
  trim_to_length (buffer @ [symbol]) max_length

let rec state_after_symbols (automaton : Automaton.automaton) (current_state : Automaton.state) (symbols : Automaton.symbol list) : Automaton.state option =
  match symbols with
  | [] ->
      Some current_state
  | first_symbol :: remaining_symbols ->
      match Automaton.find_transition automaton.transitions current_state first_symbol with
      | Some transition ->
          state_after_symbols automaton transition.to_state remaining_symbols
      | None ->
          None

let move_names_for_symbols (automaton : Automaton.automaton) (symbols : Automaton.symbol list) : string list =
  match state_after_symbols automaton automaton.start symbols with
  | Some state ->
      Automaton.final_names automaton state
  | None ->
      []

let rec first_non_empty_match (automaton : Automaton.automaton) (suffixes : Automaton.symbol list list) : string list =
  match suffixes with
  | [] ->
      []
  | first_suffix :: remaining_suffixes ->
      let move_names = move_names_for_symbols automaton first_suffix in
      if move_names = [] then
        first_non_empty_match automaton remaining_suffixes
      else
        move_names

let rec suffixes (items : 'a list) : 'a list list =
  match items with
  | [] ->
      []
  | _first_item :: remaining_items ->
      items :: suffixes remaining_items

let print_longest_recent_match (automaton : Automaton.automaton) (buffer : Automaton.symbol list) : unit =
  let move_names = first_non_empty_match automaton (suffixes buffer) in
  print_move_names move_names

let is_ignored_input (character : char) : bool =
  character = ' ' || character = ',' || character = '\n' || character = '\r' || character = '\t'

let is_exit_input (character : char) : bool =
  character = '\027' || character = '\004'

let input_key_name (character : char) : string =
  if character = '\027' then
    "Esc"
  else if character = '\004' then
    "Ctrl-D"
  else if character < ' ' || character = '\127' then
    "control key"
  else
    String.make 1 character

let process_input_character (automaton : Automaton.automaton) (mapping : key_mapping list) (max_buffer_length : int) (buffer : Automaton.symbol list) (character : char) : Automaton.symbol list =
  if is_ignored_input character then
    buffer
  else
    let input_key = input_key_name character in
    match find_symbol_for_key mapping input_key with
    | Some symbol ->
        let updated_buffer = append_recent_symbol buffer max_buffer_length symbol in
        print_raw_line symbol;
        print_longest_recent_match automaton updated_buffer;
        updated_buffer
    | None ->
        print_raw_line ("Unknown key: " ^ input_key ^ ". Input buffer reset.");
        []

let rec run_loop (automaton : Automaton.automaton) (mapping : key_mapping list) (max_buffer_length : int) (buffer : Automaton.symbol list) : unit =
  flush stdout;
  try
    let character = input_char stdin in
    if is_exit_input character then
      (print_raw_line "";
       print_raw_line "Bye.")
    else
      let next_buffer = process_input_character automaton mapping max_buffer_length buffer character in
      run_loop automaton mapping max_buffer_length next_buffer
  with End_of_file ->
    print_raw_line "";
    print_raw_line "End of input."

let run_training_mode (automaton : Automaton.automaton) (symbols : Automaton.symbol list) (max_buffer_length : int) : (unit, string) result =
  match build_key_mapping symbols with
  | Error message ->
      Error message
  | Ok mapping ->
      install_exit_signal_handler ();
      print_raw_line "Key mappings:";
      print_key_mapping mapping;
      print_raw_line "Press mapped keys to execute moves immediately.";
      print_raw_line "Exit keys: Esc, Ctrl-D.";
      print_raw_line "----------------------";
      setup_raw_terminal ();
      try
        run_loop automaton mapping max_buffer_length [];
        restore_terminal ();
        Ok ()
      with error ->
        restore_terminal ();
        raise error
