
BIN_LIB=ILEUSION
DBGVIEW=*ALL

# ---------------

all: lib modules

lib:
	-system -q "CRTLIB $(BIN_LIB) TYPE(*PROD) TEXT('ILEusion')"

modules:
	system "CRTRPGMOD MODULE($(BIN_LIB)/ILEUSION) SRCSTMF('./src/ileusion.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"
	system "CRTRPGMOD MODULE($(BIN_LIB)/DATA) SRCSTMF('./src/data.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"
	
	@echo
	@echo "Objects have been built."
	@echo "To build the program:"
	@echo "	ADDLIBLE NOXDB"
	@echo "	ADDLIBLE ILEASTIC"
	@echo "	CRTPGM PGM($(BIN_LIB)/ILEUSION) MODULE($(BIN_LIB)/ILEUSION $(BIN_LIB)/DATA) BNDDIR(JSONXML ILEASTIC)"
	@echo