NAME = ft_ality

SRC_DIR = src

SOURCES = $(SRC_DIR)/automaton.ml \
		  $(SRC_DIR)/grammar.ml \
		  $(SRC_DIR)/keyboard_input.ml \
		  $(SRC_DIR)/main.ml
OBJECTS = $(SOURCES:.ml=.cmo)
INTERFACES = $(SOURCES:.ml=.cmi)

OCAMLC = ocamlc
OCAMLFLAGS = -I $(SRC_DIR)

all: $(NAME)

$(NAME): $(OBJECTS)
	$(OCAMLC) $(OCAMLFLAGS) -o $(NAME) $(OBJECTS)

$(SRC_DIR)/automaton.cmo: $(SRC_DIR)/automaton.ml
	$(OCAMLC) $(OCAMLFLAGS) -c $<

$(SRC_DIR)/keyboard_input.cmo: $(SRC_DIR)/automaton.cmo $(SRC_DIR)/keyboard_input.ml
	$(OCAMLC) $(OCAMLFLAGS) -c $(SRC_DIR)/keyboard_input.ml

$(SRC_DIR)/grammar.cmo: $(SRC_DIR)/automaton.cmo $(SRC_DIR)/grammar.ml
	$(OCAMLC) $(OCAMLFLAGS) -c $(SRC_DIR)/grammar.ml

$(SRC_DIR)/main.cmo: $(SRC_DIR)/automaton.cmo $(SRC_DIR)/grammar.cmo $(SRC_DIR)/keyboard_input.cmo $(SRC_DIR)/main.ml
	$(OCAMLC) $(OCAMLFLAGS) -c $(SRC_DIR)/main.ml

clean:
	rm -f $(OBJECTS) $(INTERFACES)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all clean fclean re
