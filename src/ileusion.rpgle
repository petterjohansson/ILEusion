
        // -----------------------------------------------------------------------------
        // Start it:
        // SBMJOB CMD(CALL PGM(ILEUSION)) JOB(ILEASTIC1) JOBQ(QSYSNOMAX) ALWMLTTHD(*YES)
        // -----------------------------------------------------------------------------     
        
        ctl-opt copyright('Sitemule.com  (C), 2018');
        ctl-opt decEdit('0,') datEdit(*YMD.) main(main);
        ctl-opt debug(*yes) bndDir('ILEASTIC':'NOXDB');
        ctl-opt thread(*CONCURRENT);
        
        /include ./headers/ILEastic.rpgle
        /include ./headers/jsonparser.rpgle
        /include ./headers/data_h.rpgle
        /include ./headers/callfunc_h.rpgle
        
        Dcl-Pr GetLibraryPointer extproc('_RSLVSP2');
          Object  Pointer;
          Options Char(34);
        End-Pr;
        
        Dcl-Pr GetObjectPointer extproc('_RSLVSP4');
          Object  Pointer;
          Options Char(34);
          Library Pointer;
        End-Pr;
        
        Dcl-Pr ActivateServiceProgram Int(20) ExtProc('QleActBndPgmLong');
          Object Pointer;
        End-Pr;
        
        Dcl-Pr RetrieveFunctionPointer Pointer ExtProc('QleGetExpLong');
          Mark          Int(20); //From ActivateServiceProgram
          ExportNum     Int(10) Value;  //Can pass 0
          ExportNameLen Int(10);  //Length
          ExportName    Pointer Value Options(*String); //Name
          rFuncPointer  Pointer; //Return pointer
          rFuncResult   Int(10);  //Return status code
        End-Pr;
     
        Dcl-Pr callpgmv extproc('_CALLPGMV');
          pgm_ptr Pointer;
          argv    Pointer Dim(256);
          argc    Uns(10) Value;
        End-Pr;
        
        Dcl-C DQ_LEN 16384;
        
        Dcl-Pr DQSend ExtPgm('QSNDDTAQ');
          Object  Char(10);
          Library Char(10);
          DataLen Packed(5);
          Data    Pointer;
          KeyLen  Packed(3) Options(*NoPass);
          Key     Pointer   Options(*NoPass);
        End-Pr;
        
        Dcl-Pr DQPop ExtPgm('QRCVDTAQ');
          Object   Char(10);
          Library  Char(10);
          DataLen  Packed(5);
          Data     Char(DQ_LEN);
          WaitTime Packed(5);
          KeyOrder Char(2)   Options(*NoPass);
          KeyLen   Packed(3) Options(*NoPass);
          Key      Pointer   Options(*NoPass);
        End-Pr;
        
        // -----------------------------------------------------------------------------
        // Main
        // -----------------------------------------------------------------------------
        
        dcl-proc main;
          Dcl-Pi *N;
            gHost Char(15);
            gPort Int(10);
          End-Pi;

          dcl-ds config likeds(il_config);

          config.host = %TrimR(gHost);
          config.port = gPort; 

          il_listen (config : %paddr(myservlet));

        end-proc;
        
        // -----------------------------------------------------------------------------
        // Servlet call back implementation
        // -----------------------------------------------------------------------------
        
        dcl-proc myservlet;

          dcl-pi *n;
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S lEndpoint Varchar(128);
          Dcl-S lMethod   Varchar(10);
          Dcl-S lError    Pointer;
          
          lEndpoint = il_getRequestResource(request);
          lMethod   = il_getRequestMethod(request);
          
          response.contentType = 'application/json';
          
          If (lMethod = 'POST');
            Select;
              When (lEndpoint = '/sql');
                lError = Handle_SQL(request:response);
              When (lEndpoint = '/call');
                lError = Handle_Call(request:response);
              When (lEndpoint = '/dq/send');
                lError = Handle_DataQueue_Send(request:response);
              When (lEndpoint = '/dq/pop');
                lError = Handle_DataQueue_Pop(request:response);
            Endsl;
            
          Else;
            lError = Generate_Error('Requires POST request.');
          Endif;
          
          If (lError <> *NULL);
            il_responseWrite(response:JSON_AsJsonText(lError));
            Dealloc(NE) lError;
          Endif;
          
        end-proc;
        
        // -----------------------------------------------------------------------------

        Dcl-Proc Handle_SQL;
          dcl-pi *n Pointer; //Returns *NULL if successful
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S lError     Pointer;
          
          Dcl-S lResultSet Pointer;
          Dcl-S lDocument  Pointer;
          Dcl-S lSQLStmt   Pointer;
          
          Dcl-S lContent   Varchar(32767);
          
          lDocument = JSON_ParseString(request.content.string);
          
          If (JSON_Error(lDocument));
            lError = Generate_Error('Error parsing JSON.');
              
          Else;
          
            lSQLStmt = JSON_Locate(lDocument:'/query');
            If (lSQLStmt <> *NULL);
            
              lResultSet = JSON_sqlResultSet(json_GetValuePtr(lSQLStmt));
              
              If (JSON_Error(lResultSet));
                lError = Generate_Error(JSON_Message(lResultSet));
                
              Else;
                lContent = JSON_AsJsonText(lResultSet);
                il_responseWrite(response:lContent);
                //il_responseWriteStream(response : JSON_stream(lResultSet));
                
                JSON_NodeDelete(lResultSet);
              Endif;
              
              JSON_sqlDisconnect();
              
            Else;
              lError = Generate_Error('Missing SQL statement.');
            Endif;
            
          Endif;
          
          JSON_NodeDelete(lDocument);
          
          return lError;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_Call;
          dcl-pi *n Pointer; //Returns *NULL if successful
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S  lError    Pointer;
          Dcl-S  lContent  Varchar(32767);
          Dcl-S  lDocument Pointer; //Request JSON document
          Dcl-S  lArray    Pointer; //Params array JSON document
          Dcl-S  lResponse Pointer; //Response JSON document
          Dcl-DS lList     likeds(JSON_ITERATOR);
          
          Dcl-Ds ProgramInfo Qualified;
            Library  Char(10);
            Name     Char(10);
            Function Varchar(32);
            argv     Pointer Dim(256) Inz(*NULL);
            argc     Uns(3);
            
            LibPtr  Pointer;
            CallPtr Pointer; //Pointer to object or function
          End-Ds;
          
          Dcl-S lResParm   Pointer; //Parameter return document
          Dcl-S lIndex     Uns(3);
          
          Dcl-S MakeCall   Ind Inz(*On);  //Used to determine whether a valid call
          Dcl-S IsFunction Ind Inz(*Off); //If true, func call, otherwise pgm
          
          Dcl-S lLength    Int(10);
          Dcl-S lMark      Int(20); //Reference to activated srvpgm
          Dcl-S lExportRes Int(10) Inz(-1); //Result of RetrieveFunctionPointer
          Dcl-S lFuncRes   Pointer; //Function result
          
          Dcl-Ds rslvsp Qualified;
            Obj_Type Char(2);
            Obj_Name Char(30);
            Auth     Char(2)  inz(x'0000');
          End-Ds;
          
          lDocument = JSON_ParseString(request.content.string);
          
          If (JSON_Error(lDocument));
              lError = Generate_Error(JSON_Message(lDocument));
              
          Else;
          
            Monitor;
              MakeCall = *On;
              
              ProgramInfo.Library = JSON_GetStr(lDocument:'library');
              ProgramInfo.Name    = JSON_GetStr(lDocument:'object');
              ProgramInfo.argc    = 0;
              
              If (JSON_Locate(lDocument:'function') <> *NULL);
                ProgramInfo.Function = JSON_GetStr(lDocument:'function');
                IsFunction = *On;
              Endif;
              
              rslvsp.Obj_Type = x'0401';
              rslvsp.Obj_name = ProgramInfo.Library;
              GetLibraryPointer(ProgramInfo.LibPtr:rslvsp);
              
              If (IsFunction);
                rslvsp.Obj_Type = x'0203'; //Service program
              Else;
                rslvsp.Obj_Type = x'0201'; //Regular program
              Endif;
              
              rslvsp.Obj_name = ProgramInfo.Name;
              GetObjectPointer(ProgramInfo.CallPtr:rslvsp:ProgramInfo.LibPtr);
              
              //If it's a function, then get the function pointer
              If (IsFunction);
                lLength = %Len(ProgramInfo.Function);
                lMark = ActivateServiceProgram(ProgramInfo.CallPtr);
                RetrieveFunctionPointer(lMark
                                       :0
                                       :lLength
                                       :ProgramInfo.Function
                                       :ProgramInfo.CallPtr
                                       :lExportRes);
              Endif;
              
              lList = JSON_SetIterator(lDocument:'args'); //Array: value, type
              dow JSON_ForEach(lList);
                ProgramInfo.argc += 1;
                ProgramInfo.argv(ProgramInfo.argc) = Generate_Data(lList.this);
                
                If (ProgramInfo.argv(ProgramInfo.argc) = *NULL);
                  MakeCall = *Off;
                  Leave;
                Endif;
              enddo;
          
            On-Error *All;
              lError = Generate_Error('Error parsing request.');
              MakeCall = *Off;
            Endmon;

            //**************************
            
            If (MakeCall);
              Monitor;
                If (IsFunction);
                  lFuncRes = callfunc(ProgramInfo.CallPtr 
                                     :ProgramInfo.argv 
                                     :ProgramInfo.argc);
                Else;
                  callpgmv(ProgramInfo.CallPtr 
                          :ProgramInfo.argv 
                          :ProgramInfo.argc);
                Endif;
                
                lArray = JSON_NewArray();
                lIndex  = 0;
                
                lList = JSON_SetIterator(lDocument:'args'); //Array: value, type
                dow JSON_ForEach(lList);
                  lIndex += 1;
                  
                  lResParm = Get_Result(lList.this:ProgramInfo.argv(lIndex));
                  
                  If (JSON_GetLength(lResParm) = 1);
                    JSON_ArrayPush(lArray:JSON_GetChild(lResParm));
                  Else;
                    JSON_ArrayPush(lArray:lResParm);
                  Endif;
                       
                enddo;
                
                lResponse = JSON_NewObject();
                
                JSON_SetPtr(lResponse:'args':lArray);
                
                If (IsFunction);
                  lResParm = JSON_Locate(lDocument:'result');
                  lResParm = Get_Result(lResParm
                                       :lFuncRes);
                                       
                  If (JSON_GetLength(lResParm) = 1);
                    JSON_SetPtr(lResponse:'result':JSON_GetChild(lResParm));
                  Else;
                    JSON_SetPtr(lResponse:'result':lResParm);
                  Endif;
                Endif;
                
                lContent = JSON_AsJsonText(lArray);
                il_responseWrite(response:lContent);
                JSON_NodeDelete(lArray);
                JSON_NodeDelete(lResponse);
              On-Error *All;
                lError = Generate_Error('Error making call.');
              Endmon;
              
            Else;
              lError = Generate_Error('Error determining parameters.');
            Endif;
            
            For lIndex = 1 to ProgramInfo.argc;
              Dealloc ProgramInfo.argv(lIndex);
            Endfor;
          
          Endif;
          
          JSON_NodeDelete(lDocument);
          
          Return lError;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_DataQueue_Send;
          dcl-pi *n Pointer; //Returns *NULL if successful
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S lError    Pointer Inz(*NULL);
          Dcl-S lDocument Pointer;
          Dcl-S lResponse Pointer;
          Dcl-S lContent  Varchar(128);
          
          Dcl-Ds DQInfo Qualified;
            Library Char(10);
            Object  Char(10);
            DataLen Packed(5);
            DataPtr Pointer;
            KeyLen  Packed(3);
            KeyPtr  Pointer;
          End-Ds;
          
          lDocument = JSON_ParseString(request.content.string);
          
          If (JSON_Error(lDocument));
            lError = Generate_Error(JSON_Message(lDocument));
              
          Else;
            DQInfo.Library = JSON_GetStr(lDocument:'library':'');
            DQInfo.Object  = JSON_GetStr(lDocument:'object':'');
            
            DQInfo.DataLen = %Len(JSON_GetStr(lDocument:'data':''));
            DQInfo.DataPtr = JSON_GetValuePtr(JSON_Locate(lDocument:'data'));
            
            DQInfo.KeyLen  = %Len(JSON_GetStr(lDocument:'key':''));
            DQInfo.KeyPtr = JSON_GetValuePtr(JSON_Locate(lDocument:'key'));
            
            Monitor;
              If (DQInfo.KeyLen = 0); //No key
                DQSend(DQInfo.Object
                      :DQInfo.Library
                      :DQInfo.DataLen
                      :DQInfo.DataPtr);
              Else;
                DQSend(DQInfo.Object
                      :DQInfo.Library
                      :DQInfo.DataLen
                      :DQInfo.DataPtr
                      :DQInfo.KeyLen
                      :DQInfo.KeyPtr);
              Endif;
              
              //json_GetValuePtr
              lResponse = JSON_NewObject();
              JSON_SetBool(lResponse:'success':*On);
              
              lContent = JSON_AsJsonText(lResponse);
              il_responseWrite(response:lContent);
            On-Error *All;
              lError = Generate_Error('Error sending to data queue.');
            Endmon;
            
          Endif;
          
          Return lError;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_DataQueue_Pop;
          dcl-pi *n Pointer; //Returns *NULL if successful
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S lError    Pointer Inz(*NULL);
          Dcl-S lDocument Pointer;
          Dcl-S lResponse Pointer;
          Dcl-S lContent  Varchar(32767);
          
          Dcl-Ds DQInfo Qualified;
            Library  Char(10);
            Object   Char(10);
            DataLen  Packed(5);
            DataPtr  Pointer;
            Waittime Packed(5);
            KeyOrder Char(2);
            KeyLen   Packed(3);
            KeyPtr   Pointer;
          End-Ds;
          
          Dcl-S DataChar Char(DQ_LEN) Based(DQInfo.DataPtr);
          
          lDocument = JSON_ParseString(request.content.string);
          
          If (JSON_Error(lDocument));
            lError = Generate_Error(JSON_Message(lDocument));
              
          Else;
            DQInfo.Library  = JSON_GetStr(lDocument:'library':'');
            DQInfo.Object   = JSON_GetStr(lDocument:'object':'');
            DQInfo.DataLen  = JSON_GetNum(lDocument:'length':128);
            DQInfo.Waittime = JSON_GetNum(lDocument:'waittime':0);
            DQInfo.KeyOrder = JSON_GetStr(lDocument:'keyorder':'EQ');
            DQInfo.KeyLen   = %Len(JSON_GetStr(lDocument:'key':''));
            DQInfo.KeyPtr   = JSON_GetValuePtr(lDocument:'key');
            
            DQInfo.DataPtr = %Alloc(DQInfo.DataLen + 1);
            
            Monitor;
              If (DQInfo.KeyLen = 0); //No key
                DQPop(DQInfo.Object
                      :DQInfo.Library
                      :DQInfo.DataLen
                      :DataChar
                      :DQInfo.Waittime);
              Else;
                DQPop(DQInfo.Object
                      :DQInfo.Library
                      :DQInfo.DataLen
                      :DataChar
                      :DQInfo.Waittime
                      :DQInfo.KeyOrder
                      :DQInfo.KeyLen
                      :DQInfo.KeyPtr);
              Endif;
              
              //json_GetValuePtr
              lResponse = JSON_NewObject();
              JSON_SetBool(lResponse:'success':*On);
              JSON_SetNum(lResponse:'length':DQInfo.DataLen);
              JSON_SetStr(lResponse:'value':DQInfo.DataPtr);
              
              lContent = JSON_AsJsonText(lResponse);
              il_responseWrite(response:lContent);
            On-Error *All;
              lError = Generate_Error('Error sending to data queue.');
            Endmon;
            
          Endif;
          
          Return lError;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Error;
          Dcl-Pi *N Pointer;
            pMessage Pointer Value Options(*String);
          End-Pi;
          
          Dcl-S lResult Pointer;
          
          lResult = JSON_newObject();
          JSON_SetBool(lResult:'success':*Off);
          JSON_SetStr(lResult:'message': pMessage);
          
          return lResult;
        End-Proc;