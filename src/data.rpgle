        
        Ctl-Opt NoMain;
        
        /copy ./headers/jsonparser.rpgle
        /copy ./headers/data_h.rpgle
        
        Dcl-C MAX_STRING 1024;
        
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
        
        // -------------------------
        
        Dcl-Proc Get_Result Export;
        
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
          
          If (CurrentArg.ByteSize = 0);
            CurrentArg.ByteSize = GetByteSize(CurrentArg);
          Endif;

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
        
        Dcl-Proc Generate_Data Export;
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
          CurrentArg.ByteSize    = GetByteSize(CurrentArg);
          
          If (CurrentArg.ByteSize > 0);
            JSON_SetNum(pCurrentArg:'bytesize':CurrentArg.ByteSize);
            JSON_SetNum(pCurrentArg:'arraysize':CurrentArg.ArraySize);

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
        
        Dcl-Proc GetByteSize;
          Dcl-Pi *N Int(5);
            pCurrentArg LikeDS(CurrentArg_T);
          End-Pi;
          
          Dcl-S ByteSize Int(5) Inz(0);
          
          Select;
            When (pCurrentArg.Type = 'char');
              ByteSize = pCurrentArg.Length;
              
            When (pCurrentArg.Type = 'bool');
              ByteSize = 2;
              
            When (pCurrentArg.Type = 'ind');
              ByteSize = 2;
              
            When (pCurrentArg.Type = 'int');
              Select;
                When (pCurrentArg.Length = 3);
                  ByteSize = %Size(Types.int3);
                When (pCurrentArg.Length = 5);
                  ByteSize = %Size(Types.int5);
                When (pCurrentArg.Length = 10);
                  ByteSize = %Size(Types.int10);
                When (pCurrentArg.Length = 20);
                  ByteSize = %Size(Types.int20);
              Endsl;
              
            When (pCurrentArg.Type = 'uns');
              Select;
                When (pCurrentArg.Length = 3);
                  ByteSize = %Size(Types.uns3);
                When (pCurrentArg.Length = 5);
                  ByteSize = %Size(Types.uns5);
                When (pCurrentArg.Length = 10);
                  ByteSize = %Size(Types.uns10);
                When (pCurrentArg.Length = 20);
                  ByteSize = %Size(Types.uns20);
              Endsl;
            
            When (pCurrentArg.Type = 'float');
              Select;
                When (pCurrentArg.Length = 4);
                  ByteSize = %Size(Types.float);
                When (pCurrentArg.Length = 8);
                  ByteSize = %Size(Types.double);
              Endsl;
          Endsl;
          
          Return ByteSize;
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