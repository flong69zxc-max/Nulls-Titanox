ROOT := ../..
BUILD := build
SRC := $(BUILD)/src

all: run

$(BUILD)/dodgesim: $(shell find $(ROOT)/src -type f) sim_main.cpp sim_world.cpp sim_world.h stub/recoil.h stub/scan_stub.h
	rm -rf $(BUILD)
	mkdir -p $(BUILD)
	cp -r $(ROOT)/src $(SRC)
	cp stub/recoil.h $(SRC)/recoil.h
	cp stub/scan_stub.h $(SRC)/core/scan_stub.h
	g++ -std=c++17 -x c++ -ffunction-sections -fdata-sections -I. sim_main.cpp sim_world.cpp \
	    $(SRC)/helpers/dodge_kinds.mm $(SRC)/helpers/dodge_profiles.mm -Wl,--gc-sections -lm -o $(BUILD)/dodgesim

run: $(BUILD)/dodgesim
	./$(BUILD)/dodgesim

clean:
	rm -rf $(BUILD)

.PHONY: all run clean
