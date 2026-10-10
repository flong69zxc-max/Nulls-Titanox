CXX ?= g++
RECOIL_HOOK ?= ../Recoil/recoil_hook
INC = -Isim/shim -I$(RECOIL_HOOK) -Isrc
CXXFLAGS ?= -std=c++17 -O2

sim/dodge_sim: sim/sim_main.cpp
	$(CXX) $(CXXFLAGS) $(INC) sim/sim_main.cpp -o sim/dodge_sim -lm

run: sim/dodge_sim
	./sim/dodge_sim 1200

clean:
	rm -f sim/dodge_sim

.PHONY: run clean
