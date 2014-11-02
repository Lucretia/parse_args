-- parse_args.adb

-- A simple command line option parser
-- Copyright James Humphry 2014

with Parse_Args.Concrete;
use Parse_Args.Concrete;

package body Parse_Args is

   ------------------------
   -- Parse_Command_Line --
   ------------------------

   procedure Parse_Command_Line (A : in out Argument_Parser) is

      -- Separating these out into expression functions keeps the mechanics
      -- of the state machine below a little cleaner.

      function is_short_option(A : String) return Boolean is
        (A'Length = 2 and then A(A'First) = '-' and then A(A'First+1) /= '-');

      function short_option(A : String) return Character is (A(A'Last));

      function is_short_option_group(A : String) return Boolean is
        (A'Length > 2 and then
         A(A'First) = '-' and then
             (for all I in A'First+1..A'Last => A(I) /= '-'));

      function short_option_group(A : String) return String is (A(A'First+1..A'Last));

      function is_long_option(A : String) return Boolean is
        (A'Length > 2 and then A(A'First..A'First+1) = "--");

      function long_option(A : String) return String is
         (A(A'First+2..A'Last));

      function is_options_end(A : String) return Boolean is
         (A = "--");

   begin
      if A.State /= Init then
         raise Program_Error with "Argument Parser has already been fed data!";
      end if;

      A.State := Ready;
      A.Current_Positional := A.Positional.First;
      A.Last_Option := null;
      -- Last_Option holds a pointer to the option seen in the previous loop
      -- iteration so we know where to direct any arguments.

      for I in 1..Ada.Command_Line.Argument_Count loop
         declare
            Arg : constant String := Argument_Parser'Class(A).Argument(I);
         begin
            case A.State is
               when Init | Finish_Success =>
                  raise Program_Error with "Argument Parser in impossible state!";

               when Ready =>
                  if is_options_end(Arg) then
                     A.State := Positional_Only;

                  elsif is_long_option(Arg) then
                     if A.Long_Options.Contains(long_option(Arg)) then
                        Set_Option(A.Long_Options.Element(long_option(Arg)).all, A);
                        A.Last_Option := A.Long_Options.Element(long_option(Arg));
                     else
                        A.Message := To_Unbounded_String("Unrecognised option: " & Arg);
                        A.State := Finish_Erroneous;
                     end if;

                  elsif is_short_option(Arg) then
                    if A.Short_Options.Contains(short_option(Arg)) then
                        Set_Option(A.Short_Options.Element(short_option(Arg)).all, A);
                        A.Last_Option := A.Short_Options.Element(short_option(Arg));
                     else
                        A.Message := To_Unbounded_String("Unrecognised option: " & Arg);
                        A.State := Finish_Erroneous;
                     end if;

                  elsif is_short_option_group(Arg) then
                     for C of short_option_group(Arg) loop
                        if A.State /= Ready then
                           -- If one of the options specified previously in the
                           -- option group takes an argument it will have left
                           -- the parser state as Required_Argument. The only
                           -- time this isn't a problem is if such an option is
                           -- the last one in the group.
                           A.Message := To_Unbounded_String("Option requiring an argument must be last in the group: " &
                                                              short_option_group(Arg));
                           A.State := Finish_Erroneous;
                           exit;

                        elsif A.Short_Options.Contains(C) then
                           Set_Option(A.Short_Options.Element(C).all, A);
                           A.Last_Option := A.Short_Options.Element(C);

                        else
                           A.Message := To_Unbounded_String("Unrecognised option: " & C);
                           A.State := Finish_Erroneous;
                           exit;

                        end if;
                     end loop;

                  elsif A.Current_Positional /= Positional_Lists.No_Element then
                     Set_Option_Argument(Positional_Lists.Element(A.Current_Positional).all, Arg, A);
                     Positional_Lists.Next(A.Current_Positional);

                  else
                     A.Message := To_Unbounded_String("Unrecognised option: " & Arg);
                     A.State := Finish_Erroneous;

                  end if;

               when Required_Argument =>
                  -- The parser can never get into the Required_Argument state
                  -- without going through the Ready state above, and all the
                  -- branches set Last_Option to a valid, non-null option.
                  Set_Option_Argument(A.Last_Option.all, Arg, A);
                  -- The state could be set to Finish_Erroneous
                  -- OTherwise it should go back to Ready
                  if A.State = Required_Argument then
                     A.State := Ready;
                  end if;

               when Positional_Only =>
                  if A.Current_Positional /= Positional_Lists.No_Element then
                     Set_Option_Argument(Positional_Lists.Element(A.Current_Positional).all, Arg, A);
                     Positional_Lists.Next(A.Current_Positional);

                  else
                     A.Message := To_Unbounded_String("Additional unused argument: " & Arg);
                     A.State := Finish_Erroneous;

                  end if;

               when Finish_Erroneous =>
                  -- When an problem is encountered, skip all subsequent arguments
                  -- Hopefully A.message has also been filled out with an informative
                  -- message.
                  null;

            end case;
         end;
      end loop;

      case A.State is
         when Init | Required_Argument | Finish_Success | Finish_Erroneous =>
            A.State := Finish_Erroneous;
         when Ready | Positional_Only =>
            A.State := Finish_Success;
      end case;

   end Parse_Command_Line;

   -------------------
   -- Parse_Success --
   -------------------

   function Parse_Success(A : in Argument_Parser) return Boolean is
   begin
      if A.State = Finish_Success then
         return True;
      else
         return False;
      end if;
   end Parse_Success;

   -------------------
   -- Parse_Message --
   -------------------

   function Parse_Message(A : in Argument_Parser) return String is
   begin
      case A.State is
         when Finish_Success | Finish_Erroneous =>
            return To_String(A.Message);
         when others =>
            raise Program_Error with "No parse yet taken place?";
      end case;
   end Parse_Message;

   -------------------
   -- Boolean_Value --
   -------------------

   function Boolean_Value(A : Argument_Parser; Name : String) return Boolean is
   begin
      if A.Arguments.Contains(Name) and then A.Arguments(Name).all in Boolean_Option'Class then
         return Boolean_Option'Class(A.Arguments(Name).all).Value;
      else
         raise Constraint_Error with "No suitable argument: " & Name & " with boolean result.";
      end if;
   end Boolean_Value;

   -------------------
   -- Natural_Value --
   -------------------

   function Natural_Value(A : Argument_Parser; Name : String) return Natural is
   begin
      if A.Arguments.Contains(Name) and then A.Arguments(Name).all in Natural_Option'Class then
         return Natural_Option'Class(A.Arguments(Name).all).Value;
      else
         raise Constraint_Error with "No suitable argument: " & Name & " with natural number result.";
      end if;
   end Natural_Value;

   -------------------
   -- Integer_Value --
   -------------------

   function Integer_Value(A : Argument_Parser; Name : String) return Integer is
   begin
      if A.Arguments.Contains(Name) and then A.Arguments(Name).all in Integer_Option'Class then
         return Integer_Option'Class(A.Arguments(Name).all).Value;
      else
         raise Constraint_Error with "No suitable argument: " & Name & " with integer result.";
      end if;
   end Integer_Value;

   -------------------
   -- String_Value --
   -------------------

   function String_Value(A : Argument_Parser; Name : String) return String is
   begin
      if A.Arguments.Contains(Name) and then A.Arguments(Name).all in String_Option'Class then
         return String_Option'Class(A.Arguments(Name).all).Value;
      else
         raise Constraint_Error with "No suitable argument: " & Name & " with string result.";
      end if;
   end String_Value;

   -----------------
   -- Has_Element --
   -----------------

   function Has_Element (Position : Cursor) return Boolean is
     (Option_Maps.Has_Element(Option_Maps.Cursor(Position)));

   -----------------
   -- Option_Name --
   -----------------

   function Option_Name(Position : Cursor) return String is
      (Option_Maps.Key(Option_Maps.Cursor(Position)));

   -------------
   -- Iterate --
   -------------

   function Iterate (Container : in Argument_Parser)
                     return Argument_Parser_Iterators.Forward_Iterator'Class is
   begin
      return Argument_Parser_Iterator'(Start => Option_Maps.First(Container.Arguments));
   end Iterate;

   ------------------------
   -- Constant_Reference --
   ------------------------

   function Constant_Reference
     (C : aliased in Argument_Parser;
      Name : in String)
      return Option_Constant_Ref
   is
   begin
      return Option_Constant_Ref'(Element => C.Arguments.Element(Name));
   end Constant_Reference;

   ------------------------
   -- Constant_Reference --
   ------------------------

   function Constant_Reference
     (C : aliased in Argument_Parser;
      Position : in Cursor)
      return Option_Constant_Ref
   is
   begin
      return Option_Constant_Ref'(Element => Option_Maps.Element(Option_Maps.Cursor(Position)));
   end Constant_Reference;

   ----------------
   -- Add_Option --
   ----------------

   procedure Add_Option(A : in out Argument_Parser;
                        O : in Option_Ptr;
                        Name : in String;
                        Short_Option : in Character := '-';
                        Long_Option : in String := ""
                        ) is
   begin
      A.Arguments.Insert(Name, O);
      if Short_Option /= '-' then
         A.Short_Options.Insert(Short_Option, O);
      end if;
      if Long_Option'Length > 0  then
         A.Long_Options.Insert(Long_Option, O);
      else
         A.Long_Options.Insert(Name, O);
      end if;
   end Add_Option;

   -----------------------
   -- Append_Positional --
   -----------------------

   procedure Append_Positional(A : in out Argument_Parser;
                            O : in Option_Ptr;
                            Name : in String
                           ) is
   begin
      A.Arguments.Insert(Name, O);
      A.Positional.Append(O);
   end Append_Positional;

   -------------------------
   -- Make_Boolean_Option --
   -------------------------

   function Make_Boolean_Option(Default : in Boolean := False) return Option_Ptr is
     (new Concrete_Boolean_Option'(Set => False,
                                   Value => Default,
                                   Default => Default
                                  ));
   -------------------------
   -- Make_Natural_Option --
   -------------------------

   function Make_Natural_Option(Default : in Natural := 0) return Option_Ptr is
     (new Concrete_Natural_Option'(Set => False,
                                   Value => Default,
                                   Default => Default
                                  ));

   --------------------------
   -- Make_Repeated_Option --
   --------------------------

   function Make_Repeated_Option(Default : in Natural := 0) return Option_Ptr is
     (new Repeated_Option'(Set => False,
                           Value => Default,
                           Default => Default
                          ));

   -------------------------
   -- Make_Integer_Option --
   -------------------------

   function Make_Integer_Option(Default : in Integer := 0) return Option_Ptr is
     (new Concrete_Integer_Option'(Set => False,
                                   Value => Default,
                                   Default => Default
                                  ));

   ------------------------
   -- Make_String_Option --
   ------------------------

   function Make_String_Option(Default : in String := "") return Option_Ptr
   is
      Default_US : Unbounded_String := To_Unbounded_String(Default);
   begin
      return new Concrete_String_Option'(Set => False,
                                         Value => Default_US,
                                         Default => Default_US
                                        );
   end Make_String_Option;

   -----------
   -- First --
   -----------

   function First (Object : Argument_Parser_Iterator) return Cursor is
     (Cursor(Object.Start));

   ----------
   -- Next --
   ----------

   function Next (Object : Argument_Parser_Iterator; Position : Cursor)
                  return Cursor is
      (Cursor(Option_Maps.Next(Option_Maps.Cursor(Position))));

end Parse_Args;
