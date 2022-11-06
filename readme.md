# Assembly code written for 2022 Hackaday Superconference 6 badge

I wrote Conways Game of Life

It starts filled with random and iterates forward. If it gets into a 2-cycle or stops iterating for a bit it will reset to a new random pattern.

Buttons:
* opocde 8 restarts with random pattern
* opcode 4 runs simulation slower
* opcode 2 runs simulation faster
* opcode 1 restarts with glider
* operand X 8 restarts with r-pentomino

To upload to badge, download tools from [Hackday Github](https://github.com/Hack-a-Day/2022-Supercon6-Badge-Tools/) compile to hex, switch badge to dir mode and press load button, then upload over 3v uart serial.

