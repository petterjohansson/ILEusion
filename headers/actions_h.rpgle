

          Dcl-Pr Handle_Action Pointer;
            pEndpoint Char(128) Const;
            pDocument Pointer;
          End-Pr;
          
          Dcl-Pr Generate_Error Pointer;
            pMessage Pointer Value Options(*String);
          End-Pr;