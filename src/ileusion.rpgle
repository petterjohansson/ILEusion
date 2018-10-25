**FREE

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

        Dcl-Pr memcpy ExtProc('__memcpy');
          target Pointer Value;
          source Pointer Value;
          length Uns(10) Value;
        End-Pr;
        
        Dcl-Ds CurrentArg_T Qualified Template;
          ArraySize   Int(5);
          ByteSize    Int(5); //Size of type for each element
          Type        Char(10);
          Length      Int(5); //Variable length for each element
        End-Ds;
  
        Dcl-Ds Types Qualified Template;
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
            il_responseWrite(response:JSON_AsJsonText(gError));
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
            il_responseWrite(response:JSON_AsJsonText(gError));
              
          Else;
          
            lSQLStmt = JSON_Locate(lDocument:'/query');
            If (lSQLStmt <> *NULL);
            
              lContent = JSON_GetStr(lSQLStmt);
              lResultSet = JSON_sqlResultSet(lContent);
              
              If (JSON_Error(lResultSet));
                gError = Generate_Error(JSON_Message(lResultSet));
                il_responseWrite(response:JSON_AsJsonText(gError));
                
              Else;
                lContent = JSON_AsJsonText(lResultSet);
                il_responseWrite(response:lContent);
                //il_responseWriteStream(response : JSON_stream(lResultSet));
                
                JSON_NodeDelete(lResultSet);
              Endif;
              
              JSON_sqlDisconnect();
              
            Else;
              gError = Generate_Error('Missing SQL statement.');
              il_responseWrite(response:JSON_AsJsonText(gError));
            Endif;
            
          Endif;
          
          JSON_NodeDelete(lDocument);
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
          
          Dcl-S  lResParm   Pointer;
          Dcl-S  lIndex     Uns(3);
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
              gError = Generate_Error('Error parsing request.');
              il_responseWrite(response:JSON_AsJsonText(gError));
              MakeCall = *Off;
            Endmon;

            //**************************
            
            If (MakeCall);
              Monitor;
                callpgmv(ProgramInfo.ObjPtr : ProgramInfo.argv : ProgramInfo.argc);
                
                lResult = JSON_NewArray();
                lIndex  = 0;
                
                lList = JSON_SetIterator(lDocument:'args'); //Array: value, type
                dow JSON_ForEach(lList);
                  lIndex += 1;
                  
                  lResParm = Get_Result(lList.this:ProgramInfo.argv(lIndex));
                  
                  If (JSON_GetLength(lResParm) = 1);
                    JSON_ArrayPush(lResult:JSON_GetChild(lResParm));
                  Else;
                    JSON_ArrayPush(lResult:lResParm);
                  Endif;
                       
                enddo;
                
                lContent = JSON_AsJsonText(lResult);
                il_responseWrite(response:lContent);
                JSON_NodeDelete(lResult);
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
          
          JSON_NodeDelete(lDocument);
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Get_Result;
        
          Dcl-Pi *N Pointer;
            pCurrentArg Pointer; //Info about the current argument
            pValue      Pointer; //Value pointer
          End-Pi;
          
          Dcl-S  lIndex     Int(5);
          Dcl-S  lTotal     Int(5);
          Dcl-S  lArray     Pointer;
          Dcl-S  lResult    Varchar(MAX_STRING);
          Dcl-DS ValuePtr   LikeDS(Types);
          Dcl-Ds CurrentArg LikeDS(CurrentArg_T);

          CurrentArg.Type        = JSON_GetStr(pCurrentArg:'type');
          CurrentArg.Length      = JSON_GetNum(pCurrentArg:'length':1);
          CurrentArg.ByteSize    = JSON_GetNum(pCurrentArg:'bytesize':0);
          CurrentArg.ArraySize   = JSON_GetNum(pCurrentArg:'arraysize':1);

          If (CurrentArg.ByteSize > 0);
            lIndex = 0;
            lArray = JSON_NewArray();
            lTotal = CurrentArg.ByteSize * CurrentArg.ArraySize;

            Dow (lIndex < lTotal);
              memcpy(%Addr(ValuePtr):pValue+lIndex:CurrentArg.ByteSize);
                
              Select;
                When (CurrentArg.Type = 'char');
                  lResult = %TrimR(%Str(pValue+lIndex:CurrentArg.ByteSize));
                  
                When (CurrentArg.Type = 'bool');
                  lResult = %TrimR(%Str(pValue+lIndex:CurrentArg.ByteSize));
                  If (lResult = '1');
                    lResult = 'true';
                  Else;
                    lResult = 'false';
                  Endif;
                  
                When (CurrentArg.Type = 'ind');
                  lResult = %TrimR(%Str(pValue+lIndex:CurrentArg.ByteSize));
                  
                When (CurrentArg.Type = 'int');
                  Select;
                    When (CurrentArg.Length = 3);
                      lResult = %Char(ValuePtr.int3);
                    When (CurrentArg.Length = 5);
                      lResult = %Char(ValuePtr.int5);
                    When (CurrentArg.Length = 10);
                      lResult = %Char(ValuePtr.int10);
                    When (CurrentArg.Length = 20);
                      lResult = %Char(ValuePtr.int20);
                  Endsl;
                  
                When (CurrentArg.Type = 'uns');
                  Select;
                    When (CurrentArg.Length = 3);
                      lResult = %Char(ValuePtr.uns3);
                    When (CurrentArg.Length = 5);
                      lResult = %Char(ValuePtr.uns5);
                    When (CurrentArg.Length = 10);
                      lResult = %Char(ValuePtr.uns10);
                    When (CurrentArg.Length = 20);
                      lResult = %Char(ValuePtr.uns20);
                  Endsl;
                
                When (CurrentArg.Type = 'float');
                  Select;
                    When (CurrentArg.Length = 4);
                      lResult = %Char(ValuePtr.float);
                    When (CurrentArg.Length = 8);
                      lResult = %Char(ValuePtr.double);
                  Endsl;
              Endsl;
              
              JSON_ArrayPush(lArray:lResult);
              lIndex += CurrentArg.ByteSize;
            Enddo;

          Endif;
          
          Return lArray;
        End-Proc;
          
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Data;
          Dcl-Pi *N Pointer;
            pCurrentArg Pointer;
          End-Pi;
          
          Dcl-S lArray  Pointer Inz(*NULL);
          Dcl-S lResult Pointer Inz(*NULL);

          Dcl-S  TotalSize  Int(5);
          Dcl-Ds CurrentArg LikeDS(CurrentArg_T);

          lArray = JSON_Locate(pCurrentArg:'values');

          if (lArray = *NULL);
            CurrentArg.ArraySize = 1;
            lArray    = JSON_NewArray();
            JSON_ArrayPush(lArray:JSON_GetStr(pCurrentArg:'value'));
          Else;
            CurrentArg.ArraySize = JSON_GetLength(lArray);
          Endif;

          CurrentArg.Type        = JSON_GetStr(pCurrentArg:'type');
          CurrentArg.Length      = JSON_GetNum(pCurrentArg:'length':1);
          CurrentArg.ByteSize    = 0;

          Select;
            When (CurrentArg.Type = 'char');
              CurrentArg.ByteSize = CurrentArg.Length;
              
            When (CurrentArg.Type = 'bool');
              CurrentArg.ByteSize = 2;
              
            When (CurrentArg.Type = 'ind');
              CurrentArg.ByteSize = 2;
              
            When (CurrentArg.Type = 'int');
              Select;
                When (CurrentArg.Length = 3);
                  CurrentArg.ByteSize = %Size(Types.int3);
                When (CurrentArg.Length = 5);
                  CurrentArg.ByteSize = %Size(Types.int5);
                When (CurrentArg.Length = 10);
                  CurrentArg.ByteSize = %Size(Types.int10);
                When (CurrentArg.Length = 20);
                  CurrentArg.ByteSize = %Size(Types.int20);
              Endsl;
              
            When (CurrentArg.Type = 'uns');
              Select;
                When (CurrentArg.Length = 3);
                  CurrentArg.ByteSize = %Size(Types.uns3);
                When (CurrentArg.Length = 5);
                  CurrentArg.ByteSize = %Size(Types.uns5);
                When (CurrentArg.Length = 10);
                  CurrentArg.ByteSize = %Size(Types.uns10);
                When (CurrentArg.Length = 20);
                  CurrentArg.ByteSize = %Size(Types.uns20);
              Endsl;
            
            When (CurrentArg.Type = 'float');
              Select;
                When (CurrentArg.Length = 4);
                  CurrentArg.ByteSize = %Size(Types.float);
                When (CurrentArg.Length = 8);
                  CurrentArg.ByteSize = %Size(Types.double);
              Endsl;
          Endsl;


          If (CurrentArg.ByteSize > 0);
            JSON_SetNum(pCurrentArg:'bytesize':CurrentArg.ByteSize);

            TotalSize = CurrentArg.ByteSize * CurrentArg.ArraySize;
            If (CurrentArg.Type = 'char');
              TotalSize += 1; //Null term string
            Endif;

            lResult = %Alloc(TotalSize);
            AppendValues(lResult:lArray:CurrentArg);
          Endif;

          Return lResult;
        End-Proc;
        
        // -----------------------------------------------------------------------------

        Dcl-Proc AppendValues;
          Dcl-Pi *N;
            pResult Pointer;
            pArray  Pointer;
            pArg    LikeDS(CurrentArg_T);
          End-Pi;

          Dcl-Ds ValuePtr LikeDS(Types);
          Dcl-S  lIndex   Int(5);
          Dcl-DS lList    likeds(JSON_ITERATOR);

          lIndex = 0;
          lList = JSON_SetIterator(pArray); //Array: value
          Dow JSON_ForEach(lList);
            Select;
              When (pArg.Type = 'char');
                %Str(pResult+lIndex:pArg.ByteSize) = JSON_GetStr(lList.this);
                
              When (pArg.Type = 'bool');
                If (JSON_GetStr(lList.this) = 'true');
                  %Str(pResult+lIndex:pArg.ByteSize) = '1';
                Else;
                  %Str(pResult+lIndex:pArg.ByteSize) = '0';
                Endif;
                
              When (pArg.Type = 'ind');
                %Str(pResult+lIndex:pArg.ByteSize) = JSON_GetStr(lList.this);
                
              When (pArg.Type = 'int');
                Select;
                  When (pArg.Length = 3);
                    ValuePtr.int3 = %Int(JSON_GetStr(lList.this));
                  When (pArg.Length = 5);
                    ValuePtr.int5 = %Int(JSON_GetStr(lList.this));
                  When (pArg.Length = 10);
                    ValuePtr.int10 = %Int(JSON_GetStr(lList.this));
                  When (pArg.Length = 20);
                    ValuePtr.int20 = %Int(JSON_GetStr(lList.this));
                Endsl;
                memcpy(pResult+lIndex:%Addr(ValuePtr):pArg.ByteSize);
                
              When (pArg.Type = 'uns');
                Select;
                  When (pArg.Length = 3);
                    ValuePtr.uns3 = %Uns(JSON_GetStr(lList.this));
                  When (pArg.Length = 5);
                    ValuePtr.uns5 = %Uns(JSON_GetStr(lList.this));
                  When (pArg.Length = 10);
                    ValuePtr.uns10 = %Uns(JSON_GetStr(lList.this));
                  When (pArg.Length = 20);
                    ValuePtr.uns20 = %Uns(JSON_GetStr(lList.this));
                Endsl;
                memcpy(pResult+lIndex:%Addr(ValuePtr):pArg.ByteSize);
              
              When (pArg.Type = 'float');
                Select;
                  When (pArg.Length = 4);
                    ValuePtr.float = %Float(JSON_GetStr(lList.this));
                  When (pArg.Length = 8);
                    ValuePtr.double = %Float(JSON_GetStr(lList.this));
                Endsl;
                memcpy(pResult+lIndex:%Addr(ValuePtr):pArg.ByteSize);
            Endsl;

            lIndex += pArg.ByteSize;
          Enddo;
        End-Proc;
        
        // -----------------------------------------------------------------------------
        
        Dcl-Proc Generate_Error;
          Dcl-Pi *N Pointer;
            pMessage Varchar(50) Const;
          End-Pi;
          
          Dcl-S lResult Pointer;
          
          lResult = JSON_newObject();
          JSON_SetBool(lResult:'success':*Off);
          JSON_SetStr(lResult:'message': pMessage);
          
          return lResult;
        End-Proc;