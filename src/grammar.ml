type rule = {
  buttons : Automaton.symbol list;
  move_name : string;
}

let is_not_empty (text : string) : bool =
  text <> ""

let rec list_contains (items : string list) (wanted : string) : bool =
  match items with
  | [] ->
      false
  | first_item :: remaining_items ->
      first_item = wanted || list_contains remaining_items wanted

let rec unique_strings (items : string list) : string list =
  let rec unique_loop (remaining_items : string list) (known_items : string list) : string list =
    match remaining_items with
    | [] ->
        []
    | first_item :: other_items ->
        if list_contains known_items first_item then
          unique_loop other_items known_items
        else
          first_item :: unique_loop other_items (first_item :: known_items)
  in
  unique_loop items []

(* 
  Fireball; Down, Right, X
*)

let parse_line (line : string) : rule option =
  match String.split_on_char ';' line with
  | [move_name; combo] ->
      let move_name = String.trim move_name in
      let combo = String.trim combo in
      let raw_buttons = String.split_on_char ',' combo in
      let trimmed_buttons = List.map String.trim raw_buttons in
      let buttons = List.filter is_not_empty trimmed_buttons in
      if move_name = "" || buttons = [] then
        None
      else
        Some { buttons = buttons; move_name = move_name }
  | _ ->
      None

let rec read_rules_loop (channel : in_channel) (line_number : int) (rules : rule list) : (rule list, string) result =
  try
    let line = input_line channel in
    let line = String.trim line in
    if line = "" then
      read_rules_loop channel (line_number + 1) rules
    else
      match parse_line line with
      | Some rule ->
          read_rules_loop channel (line_number + 1) (rule :: rules)
      | None ->
          Error ("Bad grammar line " ^ string_of_int line_number ^ ": " ^ line)
  with End_of_file ->
    Ok rules

let read_rules (grammar_file : string) : (rule list, string) result =
  try
    let channel = open_in grammar_file in
    let result = read_rules_loop channel 1 [] in
    close_in channel;
    match result with
    | Ok rules ->
        Ok (List.rev rules)
    | Error message ->
        Error message
  with Sys_error message ->
    Error message

let rec collect_rule_symbols (rules : rule list) : Automaton.symbol list =
  match rules with
  | [] ->
      []
  | first_rule :: remaining_rules ->
      first_rule.buttons @ collect_rule_symbols remaining_rules

let symbols_from_rules (rules : rule list) : Automaton.symbol list =
  unique_strings (collect_rule_symbols rules)

let rec list_length (items : 'a list) : int =
  match items with
  | [] ->
      0
  | _first_item :: remaining_items ->
      1 + list_length remaining_items

let rec max_combo_length_loop (rules : rule list) (current_max : int) : int =
  match rules with
  | [] ->
      current_max
  | first_rule :: remaining_rules ->
      let combo_length = list_length first_rule.buttons in
      let next_max =
        if combo_length > current_max then
          combo_length
        else
          current_max
      in
      max_combo_length_loop remaining_rules next_max

let max_combo_length (rules : rule list) : int =
  max_combo_length_loop rules 0

let rec train_automaton (rules : rule list) (automaton : Automaton.automaton) : Automaton.automaton =
  match rules with
  | [] ->
      automaton
  | first_rule :: remaining_rules ->
      let updated_automaton = Automaton.add_combo automaton first_rule.buttons first_rule.move_name in
      train_automaton remaining_rules updated_automaton
