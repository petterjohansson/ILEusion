
BIN_LIB=ILEUSION
DBGVIEW=*ALL
MODS=$(BIN_LIB)/ACTIONS $(BIN_LIB)/DATA $(BIN_LIB)/CALLFUNC $(BIN_LIB)/TYPES

# ---------------

.ONESHELL:

all: $(BIN_LIB).lib ileusion.pgm cmds ileusion_s.srvpgm

%.lib:
	-system -q "CRTLIB $* TYPE(*PROD) TEXT('ILEusion')"

ileusion.pgm: ileusion.rpgle actions.rpgle data.rpgle callfunc.rpgle types.c

ileusion_s.srvpgm: ileusion_s.rpgle actions.rpgle data.rpgle callfunc.rpgle types.c

%.pgm:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -i "CRTPGM PGM($(BIN_LIB)/$*) MODULE($(BIN_LIB)/$* $(MODS)) BNDDIR(JSONXML ILEASTIC)"
	EOF

%.srvpgm:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -i "CRTSRVPGM SRVPGM($(BIN_LIB)/$*) MODULE($(BIN_LIB)/$* $(MODS)) EXPORT(*ALL) ACTGRP(*CALLER)"
	EOF

cmds:
	qsh <<EOF
	liblist -a $(BIN_LIB)
	
	-system -q "CRTSRCPF FILE($(BIN_LIB)/QSRC) RCDLEN(112)"
	system "CPYFRMSTMF FROMSTMF('./src/strilesrv.clle') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QSRC.file/STRILESRV.mbr') MBROPT(*replace)"
	system "CPYFRMSTMF FROMSTMF('./src/strilesrv.cmd') TOMBR('/QSYS.lib/$(BIN_LIB).lib/QSRC.file/STRILESRVC.mbr') MBROPT(*replace)"
	
	system "CRTBNDCL PGM($(BIN_LIB)/STRILESRV) SRCFILE($(BIN_LIB)/QSRC) DBGVIEW($(DBGVIEW))"
	system "CRTCMD CMD($(BIN_LIB)/STRILESRV) PGM($(BIN_LIB)/STRILESRV) SRCFILE($(BIN_LIB)/QSRC) SRCMBR(STRILESRVC)"
	EOF

%.rpgle:
	system -q "CRTRPGMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.rpgle') DBGVIEW($(DBGVIEW)) REPLACE(*YES)" | grep '*RNF' | grep -v '*RNF7031' | sed  "s!*!$@: &!"
	
%.c:
	system "CRTCMOD MODULE($(BIN_LIB)/$*) SRCSTMF('./src/$*.c') DBGVIEW($(DBGVIEW)) REPLACE(*YES)"
	
all:
	@echo "Build finished!"