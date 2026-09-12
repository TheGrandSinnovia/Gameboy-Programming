ROM = practice3.gb
OBJ = main.o
SRC = practice3.asm

all: $(ROM)

$(OBJ): $(SRC)
	rgbasm -o $(OBJ) $(SRC)

$(ROM): $(OBJ)
	rgblink -o $(ROM) $(OBJ)
	rgbfix -v -p 0xFF $(ROM)

clean:
	rm -f $(OBJ) $(ROM)