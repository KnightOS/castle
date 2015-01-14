include .knightos/variables.make

ALL_TARGETS:=$(BIN)castle $(ETC)castle.conf

$(BIN)castle: *.asm
	mkdir -p $(BIN)
	$(AS) $(ASFLAGS) --listing $(OUT)main.list main.asm $(BIN)castle

$(ETC)castle.conf: castle.conf.asm
	mkdir -p $(ETC)
	$(AS) $(ASFLAGS) castle.conf.asm $(ETC)castle.conf

include .knightos/sdk.make
