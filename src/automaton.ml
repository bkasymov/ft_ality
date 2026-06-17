type state = int

type symbol = string

type transition = {
  from_state : state;
  symbol : symbol;
  to_state : state;
}

type final_state = {
  state : state;
  move_name : string;
}

type automaton = {
  start : state;
  next_state : state;
  transitions : transition list;
  finals : final_state list;
}

let empty_automaton : automaton =
  {
    start = 0;
    next_state = 1;
    transitions = [];
    finals = [];
  }

let make_transition (from_state : state) (symbol : symbol) (to_state : state) : transition =
  {
    from_state = from_state;
    symbol = symbol;
    to_state = to_state;
  }

let transition_matches (transition : transition) (current_state : state) (input_symbol : symbol) : bool =
  transition.from_state = current_state && transition.symbol = input_symbol

let rec find_transition (transitions : transition list) (current_state : state) (input_symbol : symbol) : transition option =
  match transitions with
  | [] ->
      None
  | first_transition :: remaining_transitions ->
      if transition_matches first_transition current_state input_symbol then
        Some first_transition
      else
        find_transition remaining_transitions current_state input_symbol

let add_transition (automaton : automaton) (transition : transition) : automaton =
  {
    automaton with
    transitions = transition :: automaton.transitions;
  }

let add_final_state (automaton : automaton) (current_state : state) (move_name : string) : automaton =
  {
    automaton with
    finals = { state = current_state; move_name = move_name } :: automaton.finals;
  }

let create_state (automaton : automaton) : automaton * state =
  let new_state = automaton.next_state in
  let updated_automaton = {
    automaton with
    next_state = automaton.next_state + 1;
  } in
  (updated_automaton, new_state)

let get_or_create_transition (automaton : automaton) (current_state : state) (input_symbol : symbol) : automaton * state =
  match find_transition automaton.transitions current_state input_symbol with
  | Some transition ->
      (automaton, transition.to_state)
  | None ->
      let (automaton_after_state_create, new_state) = create_state automaton in
      let new_transition = make_transition current_state input_symbol new_state in
      let automaton_after_transition_add = add_transition automaton_after_state_create new_transition in
      (automaton_after_transition_add, new_state)

let rec add_combo_from_state (automaton : automaton) (current_state : state) (buttons : symbol list) (move_name : string) : automaton =
  match buttons with
  | [] ->
      add_final_state automaton current_state move_name
  | first_button :: remaining_buttons ->
      let (updated_automaton, next_state) = get_or_create_transition automaton current_state first_button in
      add_combo_from_state updated_automaton next_state remaining_buttons move_name

let add_combo (automaton : automaton) (buttons : symbol list) (move_name : string) : automaton =
  add_combo_from_state automaton automaton.start buttons move_name

let rec find_final_names (finals : final_state list) (current_state : state) : string list =
  match finals with
  | [] ->
      []
  | first_final :: remaining_finals ->
      let names_from_rest = find_final_names remaining_finals current_state in
      if first_final.state = current_state then
        first_final.move_name :: names_from_rest
      else
        names_from_rest

let final_names (automaton : automaton) (current_state : state) : string list =
  List.rev (find_final_names automaton.finals current_state)

let rec transition_symbols (transitions : transition list) : symbol list =
  match transitions with
  | [] ->
      []
  | first_transition :: remaining_transitions ->
      first_transition.symbol :: transition_symbols remaining_transitions

let rec list_contains (items : string list) (wanted : string) : bool =
  match items with
  | [] ->
      false
  | first_item :: remaining_items ->
      first_item = wanted || list_contains remaining_items wanted

let rec unique_strings (items : string list) : string list =
  match items with
  | [] ->
      []
  | first_item :: remaining_items ->
      let unique_remaining_items = unique_strings remaining_items in
      if list_contains unique_remaining_items first_item then
        unique_remaining_items
      else
        first_item :: unique_remaining_items

let alphabet (automaton : automaton) : symbol list =
  unique_strings (transition_symbols automaton.transitions)
