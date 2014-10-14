include .knightos/variables.make

# This is a list of files that need to be added to the filesystem when installing your program
ALL_TARGETS:=$(BIN)castle $(ETC)castle.conf

# This is all the make targets to produce said files
$(BIN)castle: main.asm
	mkdir -p $(BIN)
	$(AS) $(ASFLAGS) --listing $(OUT)main.list main.asm $(BIN)castle

$(ETC)castle.conf: castle.conf.asm
	mkdir -p $(ETC)
	$(AS) $(ASFLAGS) castle.conf.asm $(ETC)castle.conf

include .knightos/sdk.make
