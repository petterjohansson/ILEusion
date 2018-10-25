**FREE

        // -----------------------------------------------------------------------------
        // Start it:
        // SBMJOB CMD(CALL PGM(JSONSRV)) JOB(ILEASTIC1) JOBQ(QSYSNOMAX) ALWMLTTHD(*YES)
        // -----------------------------------------------------------------------------     
        
        ctl-opt copyright('Sitemule.com  (C), 2018');
        ctl-opt decEdit('0,') datEdit(*YMD.) main(main);
        ctl-opt debug(*yes) bndDir('ILEASTIC':'NOXDB');
        ctl-opt thread(*CONCURRENT);
        /include ./headers/ILEastic.rpgle
        /include ./headers/jsonparser.rpgle
        
        Dcl-C MAX_STRING 1024;
        
        Dcl-Pr GetLibraryPointer extproc('_RSLVSP2');
          Object  Pointer;
          Options Char(34);
        End-Pr;
        
        Dcl-Pr GetObjectPointer extproc('_RSLVSP4');
          Object  Pointer;
          Options Char(34);
          Library Pointer;
        End-Pr;
     
        Dcl-Pr callpgmv extproc('_CALLPGMV');
          pgm_ptr Pointer;
          argv    Pointer Dim(256);
          argc    Uns(10) Value;
        End-Pr;
        
        Dcl-DS CurrentArg_T Qualified Template;
          StringValue Varchar(MAX_STRING);
          Type        Char(15);
          Length      Uns(10);
        End-Ds;
        
        Dcl-S gError Pointer;
        
        // -----------------------------------------------------------------------------
        // Main
        // -----------------------------------------------------------------------------
        
        dcl-proc main;

          dcl-ds config likeds(il_config);

          config.port = 8008; 
          config.host = '*ANY';

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
          
          lEndpoint = il_getRequestResource(request);
          lMethod   = il_getRequestMethod(request);
          
          response.contentType = 'application/json';
          
          If (lMethod = 'POST');
            Select;
              When (lEndpoint = '/sql');
                Handle_SQL(request:response);
              When (lEndpoint = '/pgm');
                Handle_Program(request:response);
            Endsl;
            
          Else;
            gError = Generate_Error('Requires POST request.');
            il_responseWrite(response:json_AsJsonText(gError));
          Endif;
          
          If (gError <> *NULL);
            Dealloc(NE) gError;
          Endif;
          
        end-proc;
        
        // -----------------------------------------------------------------------------

        Dcl-Proc Handle_SQL;
          dcl-pi *n;
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S lResultSet Pointer;
          Dcl-S lDocument  Pointer;
          Dcl-S lSQLStmt   Pointer;
          
          Dcl-S lContent   Varchar(32767);
          
          lContent  = il_getContent(request);
          lDocument = JSON_ParseString(lContent);
          
          If (JSON_Error(lDocument));
            gError = Generate_Error('Error parsing JSON.');
            il_responseWrite(response:json_AsJsonText(gError));
              
          Else;
          
            lSQLStmt = JSON_Locate(lDocument:'/query');
            If (lSQLStmt <> *NULL);
            
              lContent = JSON_GetStr(lSQLStmt);
              lResultSet = JSON_sqlResultSet(lContent);
              
              If (JSON_Error(lResultSet));
                gError = Generate_Error(JSON_Message(lResultSet));
                il_responseWrite(response:JSON_AsJsonText(gError));
                
              Else;
                lContent = json_AsJsonText(lResultSet);
                il_responseWrite(response:lContent);
                //il_responseWriteStream(response : json_stream(lResultSet));
                
                json_NodeDelete(lResultSet);
              Endif;
              
              json_sqlDisconnect();
              
            Else;
              gError = Generate_Error('Missing SQL statement.');
              il_responseWrite(response:JSON_AsJsonText(gError));
            Endif;
            
          Endif;
          
          json_NodeDelete(lDocument);
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Handle_Program;
          dcl-pi *n;
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S  lContent  Varchar(32767);
          Dcl-S  lDocument Pointer;
          Dcl-S  lResult   Pointer;
          Dcl-DS lList     likeds(JSON_ITERATOR);
          
          Dcl-Ds ProgramInfo Qualified;
            Library Char(10);
            Name    Char(10);
            argv    Pointer Dim(256) Inz(*NULL);
            argc    Uns(3);
            
            LibPtr  Pointer;
            ObjPtr  Pointer;
          End-Ds;
          
          Dcl-S  lIndex     Uns(3);
          Dcl-Ds CurrentArg LikeDS(CurrentArg_T);
          Dcl-S  MakeCall   Ind Inz(*On);
          
          Dcl-Ds rslvsp Qualified;
            Obj_Type Char(2);
            Obj_Name Char(30);
            Auth     Char(2)  inz(x'0000');
          End-Ds;
          
          lContent  = il_getContent(request);
          lDocument = JSON_ParseString(lContent);
          
          If (JSON_Error(lDocument));
              gError = Generate_Error(JSON_Message(lDocument));
              il_responseWrite(response:JSON_AsJsonText(gError));
              
          Else;
          
            Monitor;
              MakeCall = *On;
              
              ProgramInfo.Library = JSON_GetStr(lDocument:'library');
              ProgramInfo.Name    = JSON_GetStr(lDocument:'program');
              ProgramInfo.argc    = 0;
              
              rslvsp.Obj_Type = x'0401';
              rslvsp.Obj_name = ProgramInfo.Library;
              GetLibraryPointer(ProgramInfo.LibPtr:rslvsp);
              
              rslvsp.Obj_Type = x'0201';
              rslvsp.Obj_name = ProgramInfo.Name;
              GetObjectPointer(ProgramInfo.ObjPtr:rslvsp:ProgramInfo.LibPtr);
              
              lList = json_SetIterator(lDocument:'args'); //Array: value, type
              dow json_ForEach(lList);
                
                CurrentArg.StringValue = JSON_GetStr(lList.this:'value');
                CurrentArg.Type        = JSON_GetStr(lList.this:'type');
                CurrentArg.Length      = json_GetNum(lList.this:'length':1);
                
                ProgramInfo.argc += 1;
                ProgramInfo.argv(ProgramInfo.argc) = Generate_Data(CurrentArg);
                
                If (ProgramInfo.argv(ProgramInfo.argc) = *NULL);
                  MakeCall = *Off;
                  Leave;
                Endif;
              enddo;
          
            On-Error *All;
              gError = Generate_Error('Error parsing request.');
              il_responseWrite(response:JSON_AsJsonText(gError));
              MakeCall = *Off;
            Endmon;
            
            If (MakeCall);
              Monitor;
                callpgmv(ProgramInfo.ObjPtr : ProgramInfo.argv : ProgramInfo.argc);
                
                lResult = json_NewArray();
                lIndex  = 0;
                
                lList = json_SetIterator(lDocument:'args'); //Array: value, type
                dow json_ForEach(lList);
                  lIndex += 1;
                  
                  CurrentArg.Type        = JSON_GetStr(lList.this:'type');
                  CurrentArg.Length      = json_GetNum(lList.this:'length':1);
                  
                  JSON_ArrayPush(lResult:
                       Get_Result(CurrentArg:ProgramInfo.argv(lIndex)));
                       
                enddo;
                
                lContent = json_AsJsonText(lResult);
                il_responseWrite(response:lContent);
              On-Error *All;
                gError = Generate_Error('Error calling RPG program.');
                il_responseWrite(response:JSON_AsJsonText(gError));
              Endmon;
              
            Else;
              gError = Generate_Error('Error determining parameters.');
              il_responseWrite(response:JSON_AsJsonText(gError));
            Endif;
            
            For lIndex = 1 to ProgramInfo.argc;
              Dealloc ProgramInfo.argv(lIndex);
            Endfor;
          
          Endif;
          
          json_NodeDelete(lDocument);
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Get_Result;
        
          Dcl-Pi *N Varchar(MAX_STRING);
            pCurrentArg LikeDS(CurrentArg_T);
            pValue      Pointer;
          End-Pi;
          
          Dcl-S lResult Varchar(MAX_STRING);
          
          Dcl-Ds ValuePtr Based(pValue);
            int3   Int(3)   Pos(1);
            int5   Int(5)   Pos(1);
            int10  Int(10)  Pos(1);
            int20  Int(20)  Pos(1);
            uns3   Uns(3)   Pos(1);
            uns5   Uns(5)   Pos(1);
            uns10  Uns(10)  Pos(1);
            uns20  Uns(20)  Pos(1);
            float  Float(4) Pos(1);
            double Float(8) Pos(1);
          End-Ds;
          
          Select;
            When (pCurrentArg.Type = 'char');
              lResult = %TrimR(%Str(pValue:MAX_STRING));
              
            When (pCurrentArg.Type = 'bool');
              lResult = %Str(pValue:MAX_STRING);
              If (lResult = '1');
                lResult = 'true';
              Else;
                lResult = 'false';
              Endif;
              
            When (pCurrentArg.Type = 'ind');
              lResult = %Str(pValue:MAX_STRING);
              
            When (pCurrentArg.Type = 'int');
              Select;
                When (pCurrentArg.Length = 3);
                  lResult = %Char(int3);
                When (pCurrentArg.Length = 5);
                  lResult = %Char(int5);
                When (pCurrentArg.Length = 10);
                  lResult = %Char(int10);
                When (pCurrentArg.Length = 20);
                  lResult = %Char(int20);
              Endsl;
              
            When (pCurrentArg.Type = 'uns');
              Select;
                When (pCurrentArg.Length = 3);
                  lResult = %Char(uns3);
                When (pCurrentArg.Length = 5);
                  lResult = %Char(uns5);
                When (pCurrentArg.Length = 10);
                  lResult = %Char(uns10);
                When (pCurrentArg.Length = 20);
                  lResult = %Char(uns20);
              Endsl;
            
            When (pCurrentArg.Type = 'float');
              Select;
                When (pCurrentArg.Length = 4);
                  lResult = %Char(float);
                When (pCurrentArg.Length = 8);
                  lResult = %Char(double);
              Endsl;
          Endsl;
          
          Return lResult;
        End-Proc;
          
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Data;
          Dcl-Pi *N Pointer;
            pCurrentArg LikeDS(CurrentArg_T);
          End-Pi;
          
          Dcl-Pr memcpy ExtProc('__memcpy');
            target Pointer Value;
            source Pointer Value;
            length Uns(10) Value;
          End-Pr;
          
          Dcl-S lResult Pointer Inz(*NULL);
          
          Dcl-Ds ValuePtr;
            int3   Int(3)   Pos(1);
            int5   Int(5)   Pos(1);
            int10  Int(10)  Pos(1);
            int20  Int(20)  Pos(1);
            uns3   Uns(3)   Pos(1);
            uns5   Uns(5)   Pos(1);
            uns10  Uns(10)  Pos(1);
            uns20  Uns(20)  Pos(1);
            float  Float(4) Pos(1);
            double Float(8) Pos(1);
          End-Ds;
          
          Select;
            When (pCurrentArg.Type = 'char');
              lResult = %Alloc(pCurrentArg.Length+1);
              %Str(lResult:pCurrentArg.Length) = pCurrentArg.StringValue;
              
            When (pCurrentArg.Type = 'bool');
              lResult = %Alloc(2);
              If (pCurrentArg.StringValue = 'true');
                %Str(lResult:pCurrentArg.Length) = '1';
              Else;
                %Str(lResult:pCurrentArg.Length) = '0';
              Endif;
              
            When (pCurrentArg.Type = 'ind');
              lResult = %Alloc(2);
              %Str(lResult:pCurrentArg.Length) = pCurrentArg.StringValue;
              
            When (pCurrentArg.Type = 'int');
              lResult = %Alloc(%Size(ValuePtr));
              Select;
                When (pCurrentArg.Length = 3);
                  int3 = %Int(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 5);
                  int5 = %Int(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 10);
                  int10 = %Int(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 20);
                  int20 = %Int(pCurrentArg.StringValue);
              Endsl;
              memcpy(lResult:%Addr(ValuePtr):%Size(ValuePtr));
              
            When (pCurrentArg.Type = 'uns');
              lResult = %Alloc(%Size(ValuePtr));
              Select;
                When (pCurrentArg.Length = 3);
                  uns3 = %Uns(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 5);
                  uns5 = %Uns(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 10);
                  uns10 = %Uns(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 20);
                  uns20 = %Uns(pCurrentArg.StringValue);
              Endsl;
              memcpy(lResult:%Addr(ValuePtr):%Size(ValuePtr));
            
            When (pCurrentArg.Type = 'float');
              lResult = %Alloc(%Size(ValuePtr));
              Select;
                When (pCurrentArg.Length = 4);
                  float = %Float(pCurrentArg.StringValue);
                When (pCurrentArg.Length = 8);
                  double = %Float(pCurrentArg.StringValue);
              Endsl;
              memcpy(lResult:%Addr(ValuePtr):%Size(ValuePtr));
          Endsl;
          
          Return lResult;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Error;
          Dcl-Pi *N Pointer;
            pMessage Varchar(50) Const;
          End-Pi;
          
          Dcl-S lResult Pointer;
          
          lResult = json_newObject();
          json_SetBool(lResult:'success':*Off);
          json_SetStr(lResult:'message': pMessage);
          
          return lResult;
        End-Proc;