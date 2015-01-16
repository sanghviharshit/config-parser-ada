-- comp_opt=-gnat83 -gnatyt
with Text_IO; 
use Text_IO;

procedure Parser is 
   package Int_IO is new Integer_IO (Integer); 
   use Int_IO; 
   
   type Token is (PROG, SCOL, OBRACE, CBRACE, INT, FLOAT, GLOBAL, HOST, COMMENT, KEY, EQ, HOSTID, ERR, STR, QUOTE, VAL, EOF);
   type Str_Ptr is access String;
   task Main;
   type TokenDataSt is
      record
	 TType : Token := ERR;
	 TValue : Str_Ptr := null;
      end record;
   
   type TokenData_Ptr is access TokenDataSt;
   
   type CurParseState is
      record
	 TopToken : TokenData_Ptr := null;
	 PrevToken : TokenData_Ptr := null;
	 LexInput : Str_Ptr := null;
      end record;
   
   type KeyValTree;
   type KeyValTree_Ptr is access KeyValTree;   
   type KeyValTree is
      record
	 Key : Str_Ptr := null;
	 Value : Str_Ptr := null;
	 KType : Character;
	 NextKeyVal  : KeyValTree_Ptr := null;
      end record;
   
   type GroupTree;
   type GroupTree_Ptr is access GroupTree;
   type GroupTree is
      record
	 GroupType : Character;
	 HostId : Str_Ptr := null;
	 KeyValPairsPtr : KeyValTree_Ptr := null;
	 NextGroup : GroupTree_Ptr := null;
      end record;
   
   CurGroupTree, TopGroupTree, TmpGroupTree : GroupTree_Ptr := null;
   CurKeyValPtr, TopKeyValPtr, TmpKeyValPtr, TmpGloKeyValPtr, TmpHostKeyValPtr : KeyValTree_Ptr;
   
   LineNumber : Natural := 1;
   OverRide : Boolean := False;
   SColon : Boolean := False;
   NewLine : Boolean := False;
   StartInput : Str_Ptr;
      
   File    : File_Type;
   FileRead : Str_Ptr;
   FileName : Str_Ptr;
   FileSize : Integer := 0;
   CurPos : Natural := 1;
   Char : Character;
   
   function Tok2Str (TokenType : Token) return String is
   begin
      case TokenType is

	 when OBRACE => return "OBRACE";
	 when CBRACE => return "CBRACE";
	 when INT => return "INT";
	 when FLOAT => return "FLOAT";
	 when STR => return "STR";
	 when QUOTE => return "QUOTE";
	 when GLOBAL => return "GLOBAL";
	 when HOST => return "HOST";
	 when HOSTID => return "HOSTID";
	 when KEY => return "KEY";
	 when EQ => return "EQ";
	 when ERR => return "ERR";
	 when EOF => return "EOF";
	 when others => return "OTHER";
      end case;
   end Tok2Str;
   
   
   procedure Bail (ErrorMsg : in String; ErrorType : in Character) is
   begin
      --Put(ErrorMsg);
      --New_Line;
      if ErrorType = 'L' then
	 Put("ERR:L:");
	 Put(LineNumber, Width => 0);
	 New_Line;
      else
	 Put("ERR:P:");
	 Put(LineNumber, Width => 0);
	 New_Line;
      end if;
      abort Main;   
   end Bail;
   
   function CreateNewNode return TokenData_Ptr is
      RetT_Ptr : TokenData_Ptr;
   begin
      RetT_Ptr := new TokenDataSt;
      return RetT_Ptr;
   end CreateNewNode;
   
   procedure ScanNumber (StrPos : in out Integer; ParseState : in out CurParseState) is
      StartPos : Integer;   
   begin
      StartPos := StrPos;
      while ParseState.LexInput (StrPos) in '0' .. '9' or ParseState.LexInput(StrPos) = '.' or ParseState.LexInput(StrPos) = '-'
      loop
	 --Put(ParseState.LexInput(StrPos));
	 if ParseState.LexInput(StrPos) = '.' then
	    exit;  
	 else
	    StrPos := StrPos + 1;
	 end if;
      end loop;
      --Put("End Position: ");
      --Put(EPos);
      if ParseState.LexInput(StrPos) = '.' then
	 StrPos := StrPos + 1;
	 while ParseState.LexInput (StrPos) in '0'..'9'
	 loop
	    StrPos := StrPos + 1;
	 end loop;
	 ParseState.TopToken.TType := FLOAT;
      else
	 ParseState.TopToken.TType := INT;
      end if;
      
      ParseState.TopToken.TValue := new String'(ParseState.LexInput(StartPos..StrPos-1));
   end ScanNumber;
   
   procedure ScanString(StrPos : in out Integer; ParseState : in out CurParseState) is
      StartPos : Integer;    
   begin
      StartPos := StrPos;
      while ParseState.LexInput (StrPos) in '0'..'9' or ParseState.LexInput(StrPos) = '_' or  ParseState.LexInput(StrPos) = '/' or ParseState.LexInput(StrPos) = '.' or ParseState.LexInput(StrPos) = '-' or ParseState.LexInput(StrPos) in 'A'..'Z' or ParseState.LexInput(StrPos) in 'a'..'z' 
      loop
	 --Put(ParseState.LexInput(StrPos));
	 StrPos := StrPos + 1;
      end loop;
      --Put("End Position: ");
      --Put(EPos);
      ParseState.TopToken.TType := STR;
      ParseState.TopToken.TValue := new String'(ParseState.LexInput(StartPos..StrPos-1));
   end ScanString;
   
   procedure ScanQuote(StrPos : in out Integer; ParseState : in out CurParseState) is
      StartPos : Integer;    
      C : Natural;
      CNext : Natural;
      EndPos : Integer;
   begin
      
      StrPos := StrPos + 1; --Ignore first "
      StartPos := StrPos;
      EndPos := StrPos;

      C := Character'Pos(ParseState.LexInput(StrPos));
      CNext := Character'Pos(ParseState.LexInput(StrPos+1));
      
      while C in 1..127 and CNext in 1..127
      loop
	 --Put(ParseState.LexInput(StrPos));
	 --\ or " or \n 
	 if C /= 92 and C /= 34 and C /= 10 then
	    --Put(ParseState.LexInput(StrPos));
	    ParseState.LexInput(EndPos) := Character'Val(C);
	    StrPos := StrPos + 1;
	    EndPos := EndPos + 1;
	 elsif C = 92 then
	    if CNext = 110 then
	       --n
	       ParseState.LexInput(EndPos) := Character'Val(10);
	    elsif CNext = 114 then
	       --r
	       ParseState.LexInput(EndPos) := Character'Val(13);
	    elsif CNext = 92 then
	       ParseState.LexInput(EndPos) := Character'Val(92);
	    elsif CNext = 34 then
	       ParseState.LexInput(EndPos) := Character'Val(34);
	    else
	       ParseState.LexInput(EndPos) := Character'Val(CNext);
	    end if;
	    --Put("New String:");
	    --Put(ParseState.LexInput(StartPos..EndPos-1));
	    --New_Line;
	    StrPos := StrPos + 2;
	    EndPos := EndPos + 1;
	 elsif C = 10 then
	    bail("New Line in Quoted String",'L');
	    StrPos := StrPos + 1;
	    EndPos := EndPos + 1;
	 elsif C = 34 then
	    StrPos := StrPos + 1;
	    exit;
	 else
	    bail("Unexpected Char in Quoted String",'L');
	 end if;
	 C := Character'Pos(ParseState.LexInput(StrPos));
	 CNext := Character'Pos(ParseState.LexInput(StrPos+1));
      end loop;
      --Put("End Position: ");
      --Put(EPos);
      ParseState.TopToken.TType := QUOTE;
      ParseState.TopToken.TValue := new String'(ParseState.LexInput(StartPos..EndPos-1));
      --Put("Quoted String So Far:");
      --Put_Line(ParseState.TopToken.TValue.All);
   end ScanQuote;

   
   procedure ScanHostId(StrPos : in out Integer; ParseState : in out CurParseState) is
      StartPos : Integer;    
   begin
      StartPos := StrPos;
      while ParseState.LexInput(StrPos) in '0'..'9' or ParseState.LexInput(StrPos) = '_' or  ParseState.LexInput(StrPos) = '/' or ParseState.LexInput(StrPos) = '.' or ParseState.LexInput(StrPos) = '-' or ParseState.LexInput(StrPos) in 'A'..'Z' or ParseState.LexInput(StrPos) in 'a'..'z' 
      loop
	 --Put(ParseState.LexInput(StrPos));
	 StrPos := StrPos + 1;
      end loop;
      --Put("End Position: ");
      --Put(EPos);
      ParseState.TopToken.TType := HOSTID;
      ParseState.TopToken.TValue := new String'(ParseState.LexInput(StartPos..StrPos-1));
   end ScanHostId;
   
   procedure ScanKey(StrPos : in out Integer; ParseState : in out CurParseState) is
      StartPos : Integer;    
   begin
      StartPos := StrPos;
      while ParseState.LexInput(StrPos) in '0'..'9' or ParseState.LexInput(StrPos) = '_' or  ParseState.LexInput(StrPos) = '/' or ParseState.LexInput(StrPos) = '.' or ParseState.LexInput(StrPos) = '-' or ParseState.LexInput(StrPos) in 'A'..'Z' or ParseState.LexInput(StrPos) in 'a'..'z' 
      loop
	 --Put(ParseState.LexInput(StrPos));
	 StrPos := StrPos + 1;
      end loop;
      --Put("End Position: ");
      --Put(EPos);
      ParseState.TopToken.TType := KEY;
      ParseState.TopToken.TValue := new String'(ParseState.LexInput(StartPos..StrPos-1));
   end ScanKey;
   
   procedure LoadNextToken(ParseState : in out CurParseState) is 
      --ParseState : CurParseState;
      C : Natural;
      Len : Integer := 0;
      ExitCondition : Boolean := False;
      StrPos : Natural := 1;
      StartPos : Natural := 1;
      LastPos : Natural := 1;
   begin
      
      if ParseState.PrevToken = null then
	 ParseState.PrevToken := CreateNewNode;
      end if;
      
      ParseState.TopToken := CreateNewNode;
      
      StrPos := ParseState.LexInput'First;
      StartPos := StrPos;
      LastPos := ParseState.LexInput'Last;
      
      --Put_Line("Prev Token: " & Tok2Str(ParseState.PrevToken.TType));
      
      --New_Line;
      while not ExitCondition 
      loop
	 if StrPos <= LastPos then
	    C := Character'Pos(ParseState.LexInput(StrPos));
	 else 
	    ParseState.TopToken.TType := EOF;
	    exit;
	 end if;
	 --Put("Start Position: ");
	 --Put(StrPos);
	 
	 --New_Line;
	 if C = 32 or C = 9 or C = 10 then
	    null;
	 else
	    null;
	    --Put("Lexing begins with =>" & Character'Val(C) & "<=");
	 end if;
	 case C is
	    when 0 =>
	       if StrPos <= LastPos then
		  StrPos := StrPos + 1;
		  bail("Null char in unexpected place", 'L');
	       else 
		  ParseState.TopToken.TType := EOF;
		  exit;
	       end if;
	    when 32 | 9 => 
	       --Space, \t
	       if C = 32 or C = 9 then
		  while C = 32 or C = 9
		  loop
		     StrPos := StrPos + 1;
		     C := Character'Pos(ParseState.LexInput(StrPos));
		  end loop;
	       else
		  StrPos := StrPos + 1;
	       end if;
	       
	    when 10 =>
	       --\n
	       --Put("New line");
	       
	       if ParseState.PrevToken.TType = KEY or ParseState.PrevToken.TType = EQ then
		  ParseState.TopToken.TType := ERR;
		  --exit;
		  StrPos := StrPos + 1;
	       end if;
	       NewLine := True;
	       StrPos := StrPos + 1;
	       NewLine := True;
	       LineNumber := LineNumber + 1;
	    when 46 =>
	       --'.'
	       if ParseState.PrevToken.TType = HOST then
		  ScanHostId(StrPos, ParseState);
		  --Put(ParseState.TopToken.TValue.all & ":");
		  --New_Line;
	       else
		  ParseState.TopToken.TType := ERR;
		  --exit;
		  StrPos := StrPos + 1;
	       end if;
	       exit;
	    when 95 =>
	       --'_'
	       if  ParseState.PrevToken.TType = OBRACE or  ParseState.PrevToken.TType = INT or  ParseState.PrevToken.TType = FLOAT or  ParseState.PrevToken.TType = STR or  ParseState.PrevToken.TType = QUOTE then
		  ScanKey(StrPos, ParseState);

		  --Put("    " & ParseState.TopToken.TValue.all & ":");
	       elsif ParseState.PrevToken.TType = HOST then
		  ScanHostId(StrPos, ParseState);
		  --Put(ParseState.TopToken.TValue.all & ":");
		  --New_Line;
	       else
		  ParseState.TopToken.TType := ERR;
		  StrPos := StrPos + 1;
		  bail("Unexpected '_'", 'P');
		  exit;
	       end if;
	       exit;
	    when 47 =>
	       --'/'
	       ScanString(StrPos,ParseState);
	       --Put(":" & ParseState.TopToken.TValue.All);
	       exit;
	    when 34 =>
	       --'"'
	       ScanQuote(StrPos,ParseState);
	       --Put(":" & ParseState.TopToken.TValue.All);
	       --New_Line;
	       exit;
	    when 61 =>
	       --'='
	       StrPos := StrPos + 1;
	       ParseState.TopToken.TType := EQ;
	       exit;
	    when 123 =>
	       StrPos := StrPos + 1;
	       ParseState.TopToken.TType := OBRACE;
	       exit;
	    when 125 =>
	       StrPos := StrPos + 1;
	       ParseState.TopToken.TType := CBRACE;
	       exit;
	    when 59 =>
	       --';'
	       --Put_Line("SCOLON");
	       if ParseState.PrevToken.TType = CBRACE and SCOLON = False then
		  SCOLON := True;
		  --Put_Line("Good SCOLON");
		  StrPos := StrPos + 1;
	       else
		  --Put_Line("Bad SCOLON");
	       	  ParseState.PrevToken.TType := ERR;
		  StrPos := StrPos + 1;
		  bail("Unexpected ';'", 'P');
		  exit;
	       end if;
	    when 35 =>
	       --#
	       --Put("Discarding Comment: ");
		    
	       while C /= 10 and StrPos < ParseState.LexInput'Last
		 --\n
		 loop
		    StrPos := StrPos + 1;
		    C := Character'Pos(ParseState.LexInput(StrPos));
		    --Put(Character'Val(C));
	       end loop;
	       --New_Line;
	       
	    when 103 =>
	       --g
	       --New_Line;
	       if ParseState.PrevToken.TType = ERR and ParseState.LexInput(StrPos..StrPos+5) = "global" then
		  --New_Line;
		  --Put_Line("GLOBAL:");
		  ParseState.TopToken.TType := GLOBAL;
		  --New_Line;
		  StrPos := StrPos+6; 
	       elsif ParseState.PrevToken.TType = EQ then
		  ScanString(StrPos, ParseState);
		  --Put(":" & ParseState.TopToken.TValue.All);
	       else
		  ScanKey(StrPos, ParseState);
		  --New_Line;
  		  --Put("    " & ParseState.TopToken.TValue.all & ":");
	       end if;
	       exit;
	    when 104 =>
	       --h
	       --New_Line;
	       --Put_Line("Checking if HOST or KEY");
	       
	       if ParseState.PrevToken.TType = CBRACE and ParseState.LexInput(StrPos..StrPos+3) = "host" then
		  --New_Line;
		  --Put_Line("HOST ");
		  ParseState.TopToken.TType := HOST;
		  StrPos := StrPos+4; 
		  SColon := False;
	       elsif ParseState.PrevToken.TType = EQ then
		  ScanString(StrPos, ParseState);
		  --Put(":" & ParseState.TopToken.TValue.All);
	       else
		  ScanKey(StrPos, ParseState);
  		  --New_Line;
  		  --Put("    " & ParseState.TopToken.TValue.all & ":");
	       end if;
	       exit;
	    when 45 | 48 | 49 | 50 | 51 | 52 | 53 | 54 | 55 | 56 | 57 =>
	       -- '-', 0..9
	       --New_Line;
	       if ParseState.PrevToken.TType = EQ then
		  ScanNumber(StrPos,ParseState);
		  --Put("I:" & ParseState.TopToken.TValue.All);
	       elsif ParseState.PrevToken.TType = HOST then
		  ScanHostId(StrPos,ParseState);
		  --Put(ParseState.TopToken.TValue.All & ":");
		  --New_Line;
	       else
		  StrPos := StrPos + 1;
		  ParseState.TopToken.TType := ERR;
		  bail("Unexpected Place for digit", 'P');
	       end if;
	       exit;
	    when others =>
	       --New_Line;
	       if ParseState.LexInput(StrPos) in 'A'..'Z' or ParseState.LexInput(StrPos) in 'a'..'z' then
		  if ParseState.PrevToken.TType = EQ then
		     ScanString(StrPos, ParseState);
		     --Put(":" & ParseState.TopToken.TValue.All);
		  elsif ParseState.PrevToken.TType = HOST then
		     ScanHostId(StrPos, ParseState);
		     --Put(ParseState.TopToken.TValue.All & ":");
		     --New_Line;
		  else
		     ScanKey(StrPos, ParseState);
		     --New_Line;
		     --Put("    " & ParseState.TopToken.TValue.all & ":");
		  end if;
	       else
		  --Put("Invalid Character");
		  StrPos := StrPos + 1;
		  bail("Invalid Character", 'L');
	       end if;
	       exit;      
	 end case;
      end loop;
      
      ParseState.LexInput := new String'(ParseState.LexInput(StrPos..LastPos));
      --New_Line;
      --Put(Tok2Str(ParseState.TopToken.TType));
      --New_Line;
      --return PState;
   end LoadNextToken;
   
   procedure PrintGroupTree is
      Override : Boolean := False;
   begin
      CurGroupTree.KeyValPairsPtr := TopKeyValPtr;
      --Put("Linked Keys to " & CurGroupTree.HostId.All);
      TmpGroupTree := CurGroupTree;
      TmpKeyValPtr := TmpGroupTree.KeyValPairsPtr;
      
      if TmpGroupTree.GroupType = 'G' then
	 Put("GLOBAL:");
      else
	 Put("HOST " & TmpGroupTree.HostId.all & ":");
      end if;
      
      New_Line;
      while TmpKeyValPtr /= null
      loop
	 Put("    " & TmpKeyValPtr.KType & ":");
	 if TmpGroupTree.GroupType = 'H' then
	    TmpGloKeyValPtr := TopGroupTree.KeyValPairsPtr;
	    while TmpGloKeyValPtr /= null
	    loop
	       if TmpGloKeyValPtr.Key.all = TmpKeyValPtr.Key.all then  
		 Override := True;
	       end if;
	       TmpGloKeyValPtr := TmpGloKeyValPtr.NextKeyVal;
	    end loop;
	 end if;
	 TmpHostKeyValPtr := CurGroupTree.KeyValPairsPtr;
	 
	 while TmpHostKeyValPtr /= null and TmpHostKeyValPtr /= TmpKeyValPtr
	 loop
	    if TmpHostKeyValPtr.Key.all = TmpKeyValPtr.Key.all then
	       Override := True;
	    end if;
	    TmpHostKeyValPtr := TmpHostKeyValPtr.NextKeyVal;
	 end loop;
	 
	 if Override = True then
	    Put("O");
	    Override := False;
	 end if;
	 Put(":");
	 Put(TmpKeyValPtr.Key.all & ":");
	 if TmpKeyValPtr.KType = 'Q' then
	    Put("""""""");
	 end if;
	 Put(TmpKeyValPtr.Value.All);
	 if TmpKeyValPtr.KType = 'Q' then
	    Put("""""""");
	 end if;
	 New_Line;
	 TmpKeyValPtr := TmpKeyValPtr.NextKeyVal;
      end loop;
	
   end PrintGroupTree;
   
   procedure Consume(S: in out CurParseState) is
      Ret : TokenData_Ptr;   
   begin
      Ret := S.TopToken;
      S.PrevToken := S.TopToken;   
      LoadNextToken(S);
   end Consume;
   
   procedure CreateGroupTree(GroupTypePassed : in Character; HostIdPassed: in Str_Ptr) is
   begin
      TmpGroupTree := new GroupTree;
      TmpGroupTree.GroupType := GroupTypePassed;
      --TmpGroupTree.NextGroup := null;
      
      TopKeyValPtr := null;
      TmpGroupTree.KeyValPairsPtr := TopKeyValPtr;
      
      if GroupTypePassed = 'G' then
	 TopGroupTree := TmpGroupTree;
	 CurGroupTree := TmpGroupTree;
      else
	 TmpGroupTree.HostId := HostIdPassed;
	 CurGroupTree.NextGroup := TmpGroupTree;
	 CurGroupTree := CurGroupTree.nextGroup;
      end if;
   end CreateGroupTree;
   
   procedure CreateKeyValPair(KeyNamePassed : in Str_Ptr; KeyValuePassed : in Str_Ptr; KeyTypePassed : in Character) is
      NewKeyValPtr : KeyValTree_Ptr;
   begin
      NewKeyValPtr := new KeyValTree;
      NewKeyValPtr.Key := KeyNamePassed;
      NewKeyValPtr.Value := KeyValuePassed;
      NewKeyValPtr.KType := KeyTypePassed;
      NewKeyValPtr.NextKeyVal := null;
      
      if TopKeyValPtr = null then
	 TopKeyValPtr := NewKeyValPtr;
	 CurKeyValPtr := TopKeyValPtr;
      else
	 CurKeyValPtr.NextKeyVal := NewKeyValPtr;
	 CurKeyValPtr := CurKeyValPtr.NextKeyVal;
      end if;	 
      --return newKeyValPtr;
      end CreateKeyValPair;
    
   procedure ParseKeyValuePairs(S:in out CurParseState) is
      KeyName : Str_Ptr;
      KeyVal : Str_Ptr;
      KeyType : Character;
   begin
      
      if S.TopToken.TType /= Key then
	 bail("Expected Key",'P');
      end if;
      
      KeyName := S.TopToken.TValue;
      Consume(S);
      
      if S.TopToken.TType /= EQ then
	 bail("Expected =", 'P');
      end if;
      Consume(S);
      
      if S.TopToken.TType = INT then
	 KeyVal := S.TopToken.TValue;
	 KeyType := 'I';
      elsif S.TopToken.TType = FLOAT then
	 KeyVal := S.TopToken.TValue;
	 KeyType := 'F';
      elsif S.TopToken.TType = STR then
	 KeyVal := S.TopToken.TValue;
	 KeyType := 'S';
      elsif S.TopToken.TType = QUOTE then
	 KeyVal := S.TopToken.TValue;
	 KeyType := 'Q';
      else
	 bail("Expected Value", 'P');
      end if;      
      
      
      CreateKeyValPair(KeyName, KeyVal, KeyType);
      Consume(S);
      if S.TopToken.TType = KEY then
	 ParseKeyValuePairs(S);
      elsif S.TopToken.TType = CBRACE then
	 null;
      else
	 bail("Expected CBRACE/KeyVal",'P');
      end if;
	 
      
      --return Retl   
   end ParseKeyValuePairs;
   
   procedure ParseGlobalBlock (S: in out CurParseState) is
   begin
      CreateGroupTree('G',null);
      Consume(S);
      
      if S.TopToken.TType /= OBRACE then
	 bail("Expected {",'P');
      end if;
      
      Consume(S);
      
      if S.TopToken.TType = KEY then
	 ParseKeyValuePairs(S);
      elsif S.TopToken.TType = CBRACE then
	null;
      else
	 bail("Expected Key or {",'P');
      end if;
      
      PrintGroupTree;
   end ParseGlobalBlock;
   
  
   procedure ParseHostBlocks(S: in out CurParseState) is
      Ret : TokenData_Ptr;   
   begin
      Ret := CreateNewNode;
      Ret.TType := S.TopToken.TType;
      
      case S.TopToken.TType is
	 when EOF =>
	    null;
	 when HOST =>
	    Consume(S);
	    if S.TopToken.TType /= HOSTID then
	       bail("Expected HOSTID",'P');
	    end if;
	    CreateGroupTree('H',S.TopToken.TValue);
	    Consume(S);
	    if S.TopToken.TType /= OBRACE then
	       bail("Expected {", 'P');
	    end if;
	    --Put("Checking KeyVals in HOST");
	    Consume(S);
	    if S.TopToken.TType = KEY then
	       ParseKeyValuePairs(S);
	    elsif S.TopToken.TType = CBRACE then
	       null;
	    else 
	       bail("Expected }",'P');
	    end if;
	    
	    PrintGroupTree;
	    Consume(S);
	    ParseHostBlocks(S);
	    --exit;
	 when others =>
	    bail("Unexpected token", 'P');
	    --exit;
      end case;
      --return Ret;   
   end ParseHostBlocks;
   
   procedure ParseProg(S: in out CurParseState) is
   begin
      case S.TopToken.TType is
	 when EOF =>
	    if S.PrevToken.TType = ERR then
	       return;
	    else
	       bail("File without Global block.",'P');
	    end if; 
	 when GLOBAL =>
	    --Put("Global");
	    --New_Line;
	    ParseGlobalBlock(S);
	    Consume(S);
	    ParseHostBlocks(S);
	 when others =>
	    --Put("Unexpected token ");
	    --Put(Tok2Str(S.TopToken.TType));
	    bail("Unexpected token",'P');
	    --exit;
      end case;
    
   end ParseProg;
      
   procedure Parse(Input: in out Str_Ptr) is 
      ParseState : CurParseState;
   begin
      StartInput := Input;
      ParseState.LexInput := Input;
      ParseState.TopToken := null;
      ParseState.PrevToken := null;
      LoadNextToken(ParseState);
      ParseProg(ParseState);
   end Parse;
  
   
   procedure ReadFile(FileName: String) is
      Line : Str_Ptr;   
      LineSize : Integer:=0;
      LineNum : Integer:=0;
   begin
      loop
	 begin
	    Open (File, Mode => In_File, Name => FileName);
	    exit;
	 exception
	    when Name_Error | Use_Error =>
	       Put_Line ("ERR:F:");
	       New_Line;
	       abort Main;
	 end;
      end loop;
      
      LineNum := 0;
      FileSize:=0;
      while not End_Of_File (File) 
      loop
	 begin
	    Line := New String'(Get_Line (File));
	    LineNum := LineNum + 1;
	    LineSize := Line.All'Last - Line.All'First + 1;
	    --Put(Integer'Image(LineNum));
	    --Put("->");
	    --Put(Integer'Image(LineSize));
	    --New_Line;
	    FileSize := FileSize + LineSize;
	 end;
      end loop;

      --Put (FileSize);
      --Put_Line (" Characters");
      FileSize := FileSize + LineNum; 
      -- Should be FileSize + LineNum -1 because Num of Lines = Num of '\n' -1
      --Put (FileSize);
      --Put_Line (" Total File Size (Including \n)");
      
      
      Reset(File);
      
      FileRead := new String(1..FileSize);
      
      while not End_Of_File (File) and CurPos <= FileSize
      loop
	 begin
	    Line := New String'(Get_Line (File));	    
	    LineSize := Line.All'Last - Line.All'First + 1;
	    FileRead(CurPos..CurPos+LineSize-1) := Line.All;
	    CurPos := CurPos + LineSize;
	    FileRead(CurPos) := Character'Val(10);
	    CurPos := CurPos + 1;
	 end;
      end loop;
      Close (File);
      
      --New_Line(4);
      --Put(">>>>>>>>>>>>File Read Start<<<<<<<<<<<<");
      --New_Line;
      --Put(FileRead.All);
      --Put(">>>>>>>>>>>>File Read End<<<<<<<<<<<<");
      --New_Line;
      
   end ReadFile;
   
   task body Main is
   begin
      -- Open input file
      FileName := new String'("test/test.cfg");
      ReadFile(FileName.All);
      Parse(FileRead);
   end Main;
begin
   null;
end Parser;
