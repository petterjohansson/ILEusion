
BIN_LIB=ILEUSION
DBGVIEW=*ALL

# ---------------

.ONESHELL:

all: lib modules program cmds

lib:
	-system -q "CRTLIB $(BIN_LIB) TYPE(*PROD) TEXT('ILEusion')"

modules: ileusion.rpgle data.rpgle callfunc.rpgle

program:
	qsh <<EOF
	liblist -a NOXDB
	liblist -a ILEASTIC
	liblist -a $(BIN_LIB)
	system -i "CRTPGM PGM($(BIN_LIB)/ILEUSION) MODULE($(BIN_LIB)/ILEUSION $(BIN_LIB)/DATA $(BIN_LIB)/CALLFUNC) BNDDIR(JSONXML ILEASTIC)"
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
	
all:
	@echo "Build finished!"