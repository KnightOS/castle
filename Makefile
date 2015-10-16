include .knightos/variables.make

ALL_TARGETS:=$(BIN)castle

$(BIN)castle: *.asm
	mkdir -p $(BIN)
	$(AS) $(ASFLAGS) --listing $(OUT)main.list main.asm $(BIN)castle

include .knightos/sdk.make
