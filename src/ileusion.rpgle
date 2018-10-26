
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
          Dcl-S lError    Pointer;
          
          lEndpoint = il_getRequestResource(request);
          lMethod   = il_getRequestMethod(request);
          
          response.contentType = 'application/json';
          
          If (lMethod = 'POST');
            Select;
              When (lEndpoint = '/sql');
                lError = Handle_SQL(request:response);
              When (lEndpoint = '/pgm');
                lError = Handle_Program(request:response);
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
          
          lContent  = il_getContent(request);
          lDocument = JSON_ParseString(lContent);
          
          If (JSON_Error(lDocument));
            lError = Generate_Error('Error parsing JSON.');
              
          Else;
          
            lSQLStmt = JSON_Locate(lDocument:'/query');
            If (lSQLStmt <> *NULL);
            
              lContent = JSON_GetStr(lSQLStmt);
              lResultSet = JSON_sqlResultSet(lContent);
              
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
        
        Dcl-Proc Handle_Program;
          dcl-pi *n Pointer; //Returns *NULL if successful
            request  likeds(il_request);
            response likeds(il_response);
          end-pi;
          
          Dcl-S  lError    Pointer;
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
              lError = Generate_Error(JSON_Message(lDocument));
              il_responseWrite(response:JSON_AsJsonText(lError));
              
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
              lError = Generate_Error('Error parsing request.');
              MakeCall = *Off;
            Endmon;

            //**************************
            
            If (MakeCall);
              Monitor;
                callpgmv(ProgramInfo.ObjPtr 
                        :ProgramInfo.argv 
                        :ProgramInfo.argc);
                
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
                lError = Generate_Error('Error calling RPG program.');
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