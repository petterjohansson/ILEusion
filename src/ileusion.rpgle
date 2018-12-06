
        // -----------------------------------------------------------------------------
        // Start it:
        // SBMJOB CMD(CALL PGM(ILEUSION)) JOB(ILEASTIC1) JOBQ(QSYSNOMAX) ALWMLTTHD(*YES)
        // -----------------------------------------------------------------------------     
        
        ctl-opt copyright('Sitemule.com  (C), 2018');
        ctl-opt decEdit('0,') datEdit(*YMD.) main(main);
        ctl-opt debug(*yes);
        ctl-opt thread(*CONCURRENT);
        
        /include ./headers/actions_h.rpgle
        /include ./headers/ILEastic.rpgle
        /include ./headers/jsonparser.rpgle

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
          Dcl-S lDocument Pointer;
          Dcl-S lResponse Pointer;
          
          lEndpoint = il_getRequestResource(request);
          lMethod   = il_getRequestMethod(request);
          
          response.contentType = 'application/json';
          
          lDocument = JSON_ParseString(request.content.string);
          If (JSON_Error(lDocument));
            lResponse = Generate_Error('Error parsing JSON.');
            
          Else;
          
            If (lMethod = 'POST');
              lResponse = Handle_Action(il_getRequestResource(request)
                                       :lDocument);
              
            Else;
              lResponse = Generate_Error('Requires POST request.');
            Endif;
            
          Endif;
          
          If (lResponse <> *NULL);
            il_responseWrite(response:JSON_AsJsonText(lResponse));
            JSON_NodeDelete(lResponse);
          Endif;
          
          JSON_NodeDelete(lDocument);
          
        end-proc;