-- parse_args_suite-parse_args_tests.adb
-- Unit tests for the Parse_Args project

-- Copyright (c) 2016, James Humphry
--
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH
-- REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
-- AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT,
-- INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
-- LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
-- OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
-- PERFORMANCE OF THIS SOFTWARE.

with System.Assertions;
with AUnit.Assertions;

with Parse_Args;
with Parse_Args.Testable;

package body Parse_Args_Suite.Parse_Args_Tests is

   use AUnit.Assertions;

   use Parse_Args;
   use Parse_Args.Testable;

   --------------------
   -- Register_Tests --
   --------------------

   procedure Register_Tests (T: in out Parse_Args_Test) is
      use AUnit.Test_Cases.Registration;
   begin
       Register_Routine (T, Check_Basics'Access,
                        "Check basic functionality");
      Register_Routine (T, Check_Boolean_Usage'Access,
                        "Check Boolean option functionality");
   end Register_Tests;

   ----------
   -- Name --
   ----------

   function Name (T : Parse_Args_Test) return Test_String is
      pragma Unreferenced (T);
   begin
      return Format ("Tests of Parse_Args package functionality");
   end Name;

   ------------
   -- Set_Up --
   ------------

   procedure Set_Up (T : in out Parse_Args_Test) is
      pragma Unreferenced (T);
   begin
      null;
   end Set_Up;

   ------------------
   -- Check_Basics --
   ------------------

   procedure Check_Basics (T : in out Test_Cases.Test_Case'Class) is
      pragma Unreferenced(T);

      function Setup_AP return Testable_Argument_Parser is
      begin
         return Result : Testable_Argument_Parser do
            Result.Add_Option(O => Make_Boolean_Option(False),
                              Name => "foo",
                              Short_Option => 'f');
            Result.Add_Option(O => Make_Boolean_Option(False),
                              Name => "bar",
                              Short_Option => 'b');
            Result.Add_Option(O => Make_Boolean_Option(False),
                              Name => "baz",
                              Short_Option => 'z');
            Result.Set_Command_Name("parse_args_tests");
         end return;
      end Setup_AP;
   begin

      declare
         AP : Testable_Argument_Parser := Setup_AP;
         Catch_Message_Too_Soon : Boolean := False;
         Catch_Repeated_Parsing : Boolean := False;
         Catch_No_Such_Argument : Boolean := False;
      begin
         AP.Clear_Arguments;
         AP.Append_Arguments((+"--foo",
                             +"-b"));

         Assert(AP.Ready, "New Argument_Parser not ready for use");

         begin
            declare
               Dummy : String := AP.Parse_Message;
            begin
               null;
            end;
         exception
            when Program_Error | System.Assertions.Assert_Failure =>
               Catch_Message_Too_Soon := True;
         end;

         Assert(Catch_Message_Too_Soon,
                "Returned a parse message before the parse has taken place");

         AP.Parse_Command_Line;

         Assert(AP.Parse_Success, "Argument_Parser did not parse successfully: " &
                  AP.Parse_Message);

         begin
            AP.Parse_Command_Line;
         exception
            when Program_Error | System.Assertions.Assert_Failure =>
               Catch_Repeated_Parsing := True;
         end;

         Assert(Catch_Repeated_Parsing,
                "Did not object to Parse_Command_Line being called twice");

         Assert(AP.Command_Name = "parse_args_tests",
                "Cannot retrieve command name");

         Assert(AP.Get("foo").Set,
                "Boolean option bar incorrectly not marked as set");
         Assert(AP.Get("bar").Set,
                "Boolean option bar incorrectly not marked as set");
         Assert(not AP.Get("baz").Set,
                "Boolean option baz incorrectly marked as set");

         begin
            declare
               Dummy : Boolean := AP.Boolean_Value("nosuch");
            begin
               null;
            end;
         exception
            when Constraint_Error =>
               Catch_No_Such_Argument := True;
         end;

         Assert(Catch_No_Such_Argument,
                "Returned a value for a non-existent option");

      end;

   end Check_Basics;

   -------------------------
   -- Check_Boolean_Usage --
   -------------------------

   procedure Check_Boolean_Usage (T : in out Test_Cases.Test_Case'Class) is
      pragma Unreferenced(T);

      function Setup_AP return Testable_Argument_Parser is
      begin
         return Result : Testable_Argument_Parser do
            Result.Add_Option(O => Make_Boolean_Option(False),
                              Name => "foo",
                              Short_Option => 'f',
                              Usage => "Foo option");
            Result.Add_Option(O => Make_Boolean_Option(True),
                              Name => "bar",
                              Short_Option => 'b',
                              Usage => "Bar option");
            Result.Add_Option(O => Make_Boolean_Option(False),
                              Name => "baz",
                              Short_Option => 'z',
                              Long_Option => "-",
                              Usage => "Baz option");
            Result.Add_Option(O => Make_Boolean_Option(False),
                              Name => "bork",
                              Short_Option => '-',
                              Long_Option => "borkable",
                              Usage => "Borkable option");
            Result.Set_Command_Name("parse_args_tests");
         end return;
      end Setup_AP;
   begin

      declare
         AP : Testable_Argument_Parser := Setup_AP;
      begin
         AP.Clear_Arguments;
         AP.Append_Arguments((+"--foo",
                             +"-b",
                             +"--borkable"));

         AP.Parse_Command_Line;
         Assert(AP.Parse_Success, "Argument_Parser did not parse successfully: " &
                  AP.Parse_Message);

         Assert(AP.Boolean_Value("foo"),
                "Boolean option foo (default false) not toggled");
         Assert(not AP.Boolean_Value("bar"),
                "Boolean option bar (default true) not toggled via short option");
         Assert(AP.Boolean_Value("bork"),
                "Boolean option bork (default false) not toggled via renamed long option");
      end;

      declare
         AP : Testable_Argument_Parser := Setup_AP;
      begin
         AP.Clear_Arguments;
         AP.Append_Argument("-bz");

         AP.Parse_Command_Line;
         Assert(AP.Parse_Success, "Argument_Parser did not parse successfully");

         Assert(not AP.Boolean_Value("foo"),
                "Boolean option foo (default false) set despite not being present in option group");

         Assert(not AP.Boolean_Value("bar"),
                "Boolean option bar (default true) not toggled via short option group");
         Assert(AP.Get("baz").Set,
                "Boolean option baz (default false) not toggled via short option group");
      end;

      declare
         AP : Testable_Argument_Parser := Setup_AP;
      begin
         AP.Clear_Arguments;
         AP.Append_Arguments((+"--nonesuch", +"--foo"));
         AP.Parse_Command_Line;
         Assert(not AP.Parse_Success,
                "Parse successful despite passing non-existent option");
      end;

      declare
         AP : Testable_Argument_Parser := Setup_AP;
      begin
         AP.Clear_Arguments;
         AP.Append_Arguments((+"--foo", +"invalidarg"));
         AP.Parse_Command_Line;
         Assert(not AP.Parse_Success,
                "Parse successful despite passing an argument to a Boolean option");
      end;

      declare
         AP : Testable_Argument_Parser := Setup_AP;
      begin
         AP.Clear_Arguments;
         AP.Append_Argument("--baz");
         AP.Parse_Command_Line;
         Assert(not AP.Parse_Success,
                "Parse successful despite using a long option name on a short-name only option");
      end;

      declare
         AP : Testable_Argument_Parser := Setup_AP;
      begin
         AP.Clear_Arguments;
         AP.Append_Argument("--bork");
         AP.Parse_Command_Line;
         Assert(not AP.Parse_Success,
                "Parse successful despite using the underlying option name for a renamed long option");
      end;

   end Check_Boolean_Usage;

end Parse_Args_Suite.Parse_Args_Tests;
