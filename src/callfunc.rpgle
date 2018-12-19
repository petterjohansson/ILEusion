        
        Ctl-Opt NoMain;
        
        Dcl-C MAX_BUFFER 1024;
        
        Dcl-Pr memcpy ExtProc('__memcpy');
          target Pointer Value;
          source Pointer Value;
          length Uns(10) Value;
        End-Pr;
        
        Dcl-Proc callfunc Export;
          Dcl-Pi *N Pointer;
            pProc  Pointer(*Proc);
            pArgv  Pointer Dim(256);
            pArgc  Uns(3);
            pBytes Uns(5) Const;
          End-Pi;
          
          Dcl-S lResPtr Pointer Inz(*Null);
          Dcl-S lResult Char(MAX_BUFFER) Inz(*Blank);
          
          Dcl-Pr PARM0 Like(lResult) ExtProc(pProc);
          End-Pr;
          Dcl-Pr PARM1 Like(lResult) ExtProc(pProc);
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM2 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM3 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM4 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM5 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM6 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM7 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
          End-Pr;
          Dcl-Pr PARM8 Like(lResult) ExtProc(pProc);
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
            *N Pointer;
          End-Pr;
          
          Select;
            When (pArgc = 0);
              lResult = PARM0();
            When (pArgc = 1);
              lResult = PARM1(pArgv(1));
            When (pArgc = 2);
              lResult = PARM2(pArgv(1):pArgv(2));
            When (pArgc = 3);
              lResult = PARM3(pArgv(1):pArgv(2):pArgv(3));
            When (pArgc = 4);
              lResult = PARM4(pArgv(1):pArgv(2):pArgv(3):pArgv(4));
            When (pArgc = 5);
              lResult = PARM5(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5));
            When (pArgc = 6);
              lResult = PARM6(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5)
                              :pArgv(6));
            When (pArgc = 7);
              lResult = PARM7(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5)
                              :pArgv(6):pArgv(7));
            When (pArgc = 8);
              lResult = PARM8(pArgv(1):pArgv(2):pArgv(3):pArgv(4):pArgv(5)
                              :pArgv(6):pArgv(7):pArgv(8));
          Endsl;
          
          If (pBytes > 0);
            lResPtr = %Alloc(pBytes);
            memcpy(lResPtr:%Addr(lResult):pBytes);
          Endif;
          
          Return lResPtr;
        End-Proc;