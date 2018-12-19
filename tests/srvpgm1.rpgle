**FREE

Ctl-Opt NoMain;

Dcl-Proc TestFunc Export;
  Dcl-Pi *N;
    pName Char(20);
  End-Pi;
  
  pName = 'Hello ' + pName;
End-Proc;

Dcl-Proc TestRet Export;
  Dcl-Pi *N Char(10);
  End-Pi;
  
  Return 'Hello';
End-Proc;