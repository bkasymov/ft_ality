# ft_ality

`ft_ality` is an OCaml implementation of a fighting-game training mode.
It reads a grammar file, builds a finite-state automaton at runtime, computes a keyboard mapping from the grammar, and prints move names when the user enters a known combo.

## Run With Docker Compose

Build and run the project in the provided Debian/OCaml container:

```sh
docker compose run --rm ocaml make
docker compose run --rm ocaml ./ft_ality grammars/small.gmr
```

Clean generated files:

```sh
docker compose run --rm ocaml make fclean
```

Rebuild from scratch:

```sh
docker compose run --rm ocaml make re
```

The Docker setup is only a development convenience. The project itself is built by the `Makefile`.

## Run Without Docker

If OCaml is installed locally:

```sh
make
./ft_ality grammars/small.gmr
```

Clean:

```sh
make fclean
```

## Grammar Format

Each non-empty grammar line has this format:

```text
Move Name; Button1, Button2, Button3
```

Example:

```text
Fireball; Down, Right, X
Iceball; Down, Right, Y
Ground Slam; Down, Down, B
```

The text before `;` is the move name.
The comma-separated tokens after `;` are the input symbols used to train the automaton.

## Runtime Example

```text
Key mappings:
q -> Down
w -> Right
e -> X
r -> Y
t -> B
Press mapped keys to execute moves immediately.
Exit keys: Esc, Ctrl-D. Interrupt: Ctrl-C.
----------------------
Down
Right
X
Fireball !!
```

The mapping is automatically computed from the grammar symbols. The physical keys are fixed (`q`, `w`, `e`, etc.), but the symbols assigned to them come from the grammar file.

## Automaton Formula

The subject defines a finite-state automaton as:

```text
A = <Q, Sigma, Q0, F, delta>
```

In this project:

```text
Q      = the set of states
Sigma  = the input alphabet, collected from grammar symbols
Q0     = the start state
F      = the final states, where moves are recognized
delta  = the transition function from (state, symbol) to next state
```

The implementation stores these concepts in `src/automaton.ml`:

```ocaml
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
```

Mapping to the formula:

```text
Q      -> all states created through next_state
Sigma  -> all unique symbols found in grammar rules
Q0     -> automaton.start
F      -> automaton.finals
delta  -> automaton.transitions
```

## Work Flow

The main program flow is:

```text
main
 |
 v
read grammar file
 |
 v
parse lines into rules
 |
 v
collect unique symbols
 |
 v
validate that symbols fit available keyboard keys
 |
 v
compute max combo length
 |
 v
train automaton from rules
 |
 v
build keyboard mapping
 |
 v
read keyboard input
 |
 v
store recent symbols in a bounded buffer
 |
 v
check recent suffixes against the automaton
 |
 v
print move names when a final state is reached
```

## Automaton Training

For a grammar rule:

```text
Fireball; Down, Right, X
```

the program creates a path:

```text
0 --Down--> 1 --Right--> 2 --X--> 3
```

Then state `3` becomes final:

```text
3 => Fireball
```

For another rule:

```text
Iceball; Down, Right, Y
```

the shared prefix is reused:

```text
0 --Down--> 1 --Right--> 2 --X--> 3 => Fireball
                            |
                            --Y--> 4 => Iceball
```

This is similar to a trie: common prefixes are shared, and new branches are created only when a transition does not already exist.

## Recognition Process

The automaton reads symbols from left to right.

Example:

```text
Input symbols: Down, Right, X
```

Automaton walk:

```text
start at 0
Down  -> transition 0 --Down--> 1
Right -> transition 1 --Right--> 2
X     -> transition 2 --X--> 3
```

After all symbols are read, the program checks whether the current state is final.
If state `3` is final and stores `Fireball`, the program prints:

```text
Fireball !!
```

If a transition is missing, the sequence is not recognized.
If the path exists but the last state is not final, the sequence is only a prefix, not a complete move.

## Recent Input Buffer

The program processes input online. It does not store all user input forever.

It computes:

```text
max_buffer_length = length of the longest combo in the grammar
```

After each key press, the new symbol is appended to the buffer.
If the buffer becomes too long, the oldest symbols are removed.

Example with `max_buffer_length = 3`:

```text
[A; B; C] + D
[A; B; C; D]
remove oldest A
[B; C; D]
```

This keeps memory bounded while still preserving enough recent input to recognize every combo in the grammar.

## Longest Recent Match

After every valid key press, the program checks suffixes of the recent buffer from longest to shortest.

For:

```text
[Down; Down; Right; X]
```

the suffixes are:

```text
[Down; Down; Right; X]
[Down; Right; X]
[Right; X]
[X]
```

If `Down, Right, X` is a known combo, it is recognized even though there was an extra `Down` before it.

This is why an input like:

```text
q q w e
```

can still trigger `Fireball` when:

```text
q -> Down
w -> Right
e -> X
```

## Homonymous Rules

Several move names can share the same combo:

```text
Move A; Down, X
Move B; Down, X
Move C; Down, X
```

The automaton path is created once, but the final state stores all matching move names.
When the combo is entered, all names are printed:

```text
Move A !!
Move B !!
Move C !!
```

## Edge Case Grammars

Useful grammar files included for testing:

```text
grammars/small.gmr       basic moves
grammars/homonymous.gmr  several moves with the same combo
grammars/prefixes.gmr    moves sharing common prefixes
hundred_combo.gmr        one combo with 100 symbols and all 36 mappings
too_many_symbols.gmr     validation error: 37 symbols but only 36 keys
space_symbols.gmr        symbols containing spaces
overlap.gmr              overlapping short and long combos
```

## Exit Keys

During runtime:

```text
Esc    exits the program normally
Ctrl-D exits the program normally
Ctrl-C interrupts the program through SIGINT
```

Unknown keys reset the input buffer and the program keeps running.
