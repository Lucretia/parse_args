-- generic_example_options
-- An example of the use of parse_args with generic option types

-- Copyright (c) 2015, James Humphry
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

with Parse_Args;
use Parse_Args;
with Parse_Args.Generic_Discrete_Options;
with Parse_Args.Generic_Options;

package Generic_Example_Options is

   type Compass is (North, South, East, West);

   package Compass_Option is new Generic_Discrete_Options(Element => Compass,
                                                         Fallback_Default => North);

   procedure Is_Even(Arg : in Integer; Result : in out Boolean);

   package Even_Option is new Generic_Discrete_Options(Element => Natural,
                                                      Fallback_Default => 0,
                                                      Valid => Is_Even);

   package Float_Option is new Generic_Options(Element => Float,
                                               Fallback_Default => 0.0,
                                               Value => Float'Value,
                                               Image => Float'Image);

end Generic_Example_Options;
