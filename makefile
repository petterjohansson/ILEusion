
BIN_LIB=ILEUSION
DBGVIEW=*ALL

# ---------------

.ONESHELL:

all: lib modules program

lib:
	-system -q "CRTLIB $(BIN_LIB) TYPE(*PROD) TEXT('ILEusion')"

modules: ileusion.rpgle data.rpgle

program:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -i "CRTPGM PGM($(BIN_LIB)/ILEUSION) MODULE($(BIN_LIB)/ILEUSION $(BIN_LIB)/DATA) BNDDIR(JSONXML ILEASTIC)"
	EOF
	
%.rpgle: %.rpgle
	system -q "CRTRPGMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)" | grep '*RNF' | grep -v '*RNF7031' | sed  "s!*!$@: &!"