;;; Conway's game of life
;;; Nick Winters (sphereinabox) 2022
;;;
;;; Buttons:
;;;  - opcode 8: reset to random
;;;  - opcode 4: slower delay before next step
;;;  - opcode 2: faster
;;;  - opcode 1: reset to glider
;;;  - operand x 8: reset to r-pentomino
;;;
;;; memory:
;;; 0x0: registers
;;; 0x10-0x1E: stack (I think only 2 levels used)
;;; 0x1F "stuck" counter
;;; 0x2: fb0-a
;;; 0x3; fb0-b
;;; 0x4: fb1-a
;;; 0x5: fb2-b
;;; 0x6-0xE: conway counters
;;; 0xF: special function registers
;;;
;;; registers:
;;; r0: various temporary uses
;;; r2: only used for "stuck/blinker" check flag
;;; r3 address high of neighbor count in memory
;;; r4 address low of neighbor count in memory
;;; r5 "current" bits in "conway" loop
;;; r6 low destination address for output display
;;; r7 high destination address for output display
;;; r8: only used to accumulate output bits in "conway" loop
;;; r9: currently displayed page 0x4 or 0x2 (xor with 0b0110 to get the other)
;;; r9 next page to display
;;;
;;; implementation notes:
;;;  - the display toggles between two pages: 4 and 6.
;;;  - the count of neighbors are made in memory, on pages 0xF-0xD
;;;  - to detect stuck just blinkers I check for changes with 2-generations ago. I reset after 16 more generations.
;;;
init:
  ;; 0b1010 to turn off ALU display
  ;; 0b0010 to just relocate IN/OUT to last page
  ;; (it seems like they still talk to IO. don't become general purpose registers)
  mov r0,0b1010
  mov [0xF3],r0                 ; WRFLAGS
  ;; set up sync
  mov r0, 13
  mov [0xF2], r0                ; sample code on 0xFC page puts this into 0xF4?
  mov r0,0b0001                 ; low bit starts sync
  mov [0xFC], r0                ; KeyStatus bit zero is handshaking bit for sync

fillrandom:
  ;; page
  mov r9,0x4                  ;next page to draw

  ;; fill page at r9 with random
  mov r1,r9
  mov r2,0
fill0:
  mov r0, [0xFF]
  ;; mov r0,r2
  ;; mov r0,0xF
  mov [r1:r2], r0
  inc r2
  skip c,2
  goto fill0
  ;; fill page at r9+1 with random
  inc r1
  mov r2,0
fill1:
  mov r0, [0xFF]
  ;; mov r0,r2
  ;; mov r0,0xf
  mov [r1:r2], r0
  inc r2
  skip c,2
  goto fill1

  ;; fill page not at r9 with random
  mov r0,r9
  xor r0,0b0110
  mov r1,r0
  mov r2,0
fill2:
  ;; mov r0,0xF
  mov r0, [0xFF]
  ;; mov r0,r2
  mov [r1:r2], r0
  inc r2
  skip c,2
  goto fill2
  ;; fill page not at r9+1 with random
  inc r1
  mov r2,0
fill3:
  ;; mov r0, 0xF
  mov r0, [0xFF]
  ;; mov r0,r2
  mov [r1:r2], r0
  inc r2
  skip c,2
  goto fill3

afterfill:
  ;; zero "stuck" counter
  mov r0,0
  mov [0x1F],r0
  ;; page
  mov r9,0x4                  ;next page to draw
  ;; set display page to r9
  mov r0,r9
  mov [0xF0],r0


loop:
  ;; zero neighbor counters in 0x60-0xEF
  mov r2,0x6
zero_neighbor_page_loop:
  mov r0,0x0
  mov r1,0                      ; entry in page
  ;; inner:
  mov [r2:r1],r0
  inc r1
  skip c,1
  jr -4
  inc r2
  mov r0,r2
  cp r0,0xF
  skip z,2
  goto zero_neighbor_page_loop


  ;; active bit
  ;; r7:r6 stores previous bits
  mov r0,r9                     ; find previous page
  xor r0,0b0110
  mov r7,r0
  mov r6,0                      ; in-page addr
  ;; r4:r3 stores count of living neighbors
  mov r3,0x0                    ; copies r6?
inc_neighbor_page_loop:
  mov r4,0x6
  mov r0,[r7:r6]
  mov r5,r0
  ;; unrolled 4x
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  ;; second source page
  inc r7
  mov r0,[r7:r6]
  mov r5,r0
  ;; unrolled 4x
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4
  rrc r5
  skip nc,2
  gosub do_increment
  inc r4

  ;; move to next row
  inc r3
  dec r7
  inc r6
  skip c,2
  goto inc_neighbor_page_loop

  ;; conway loop
  mov r2,0x0                    ; flag set to 1 when we change bits
  ;; r7:r6 stores previous bits
  mov r0,r9                     ; find previous page
  xor r0,0b0110
  mov r7,r0
  mov r6,0                      ; in-page addr
  ;; r4:r3 stores count of living neighbors
  mov r3,0x0                    ; copies r6?
conway_page_loop:
  mov r4,0x6
  mov r0,[r7:r6]                ; read previous bits
  mov r5,r0
  ;; unroll 4x
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  ;; save 4 results
  mov r0,r7
  xor r0,0b0110
  mov r7,r0
  mov r0,[r7:r6]                ; load old bits to r5
  mov r5,r0
  mov r0,r8
  mov [r7:r6],r0
  sub r0,r5                     ; compare old/new bits
  skip z,1
  mov r2,1                      ; bits changed
  mov r0,r7
  xor r0,0b0110
  mov r7,r0
  ;; second page
  inc r7
  mov r0,[r7:r6]
  mov r5,r0
  ;; unroll 4x
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  gosub do_conway
  rrc r0
  rrc r8
  inc r4
  ;; save 4 results
  mov r0,r7
  xor r0,0b0110
  mov r7,r0
  mov r0,[r7:r6]                ; load old bits to r5
  mov r5,r0
  mov r0,r8
  mov [r7:r6],r0
  sub r0,r5                     ; compare old/new bits
  skip z,1
  mov r2,1                      ; bits changed
  mov r0,r7
  xor r0,0b0110
  mov r7,r0
  ;; move to next row
  inc r3
  dec r7
  inc r6
  skip c,2
  goto conway_page_loop

  ;; swap r9 to next page
  mov r0,r9
  xor r0,0b0110
  mov r9,r0

  ;; update page display
  mov r0,r9
  mov [0xF0],r0

  ;; wait for sync
  mov r0, [244]                 ; RdFlags
  bit r0,0                      ; test user sync bit
  skip NZ,1                     ;
  jr -4                         ; loop

  ;; test keypresses
  mov r0,[0xFC]
  bit r0,0                      ;new keypress will set z to nz
  skip nz,2
  goto no_buttons_pressed
  mov r0,[0xFD]                 ;load number of keypress
  cp r0,1                       ; leftmost opcode button
  skip nz,2
  goto fillrandom               ; new pattern
  cp r0,2                       ; '4' opcode/sync button
  skip nz,2
  goto fastersync
  cp r0,3                       ; '2' opcode/sync button
  skip nz,2
  goto slowersync
  cp r0,4                       ; '1' opcode/sync button
  skip nz,2
  goto initglider
  cp r0,5                       ; '8' X/clock button
  skip nz,2
  goto init_r_pentomino

no_buttons_pressed:
  ;; r2 is zero when no changes were made
  bit r2,0
  skip z,2
  goto loop

  ;; increment stuck counter 0x1F
  mov r0,[0x1F]
  inc r0
  mov [0x1F],R0
  ;; when counter overflows, fill random
  skip nc,2
  goto fillrandom

  goto loop

slowersync:
  mov r0,[0xF2]
  cp r0,0x0
  skip z,1
  dec r0
  mov [0xF2],R0
  goto loop

fastersync:
  mov r0,[0xF2]
  cp r0,0xF
  skip z,1
  inc r0
  mov [0xF2],R0
  goto loop

;;; increment counters at 8 addresses centered at [r4:r3]
do_increment:
  gosub north
  gosub do_increment_single
  gosub east
  gosub do_increment_single
  gosub south
  gosub do_increment_single
  gosub south
  gosub do_increment_single
  gosub west
  gosub do_increment_single
  gosub west
  gosub do_increment_single
  gosub north
  gosub do_increment_single
  gosub north
  gosub do_increment_single
  gosub east
  gosub south
  ret r0,0

do_increment_single:
  ;; increment the value at [r4:r3]
  ;; 0x6 <= r4 <= 0xD
  ;; 0x0 <= r3 <= 0xF
  mov r0,[r4:r3]
  inc r0
  mov [r4:r3],r0
  ret r0,0

north:
  ;; subtract 1 with wrapping
  mov r0, 0b1111
  add r3, r0
  ret r0,0
south:
  ;; add 1 with wrapping
  mov r0, 0b0001
  add r3, r0
  ret r0,0
west:
  ;; decrement r4, but wrap to 0xD if passing 0x6
  mov r0, 0b1010                ; -6
  add r0, r4
  dec r0
  and r0, 0b0111
  add r0, 0x6
  mov r4, r0
  ret r0,0
east:
  ;;  increment r4, but wrap to 0x6 passing 0xD
  mov r0, 0b1010                ; -6
  add r0, r4
  inc r0
  and r0, 0b0111
  add r0, 0x6
  mov r4, r0
  ret r0,0

do_conway:
  mov r0,[r4:r3]
  rrc r5

  ;; hax:
  ;; return based on previous value only
  ;; skip c,1
  ;; ret r0,1
  ;; ret r0,0

  ;; set r0 to indicate alive/dead, based on:
  ;;  - existing carry flag (c: alive, nc: dead)
  ;;  - r0 number of living neighbors
  skip c,0                      ; alive?
  cp r0,3                       ; dead, with 3 neighbors?
  skip nz,1
  ret r0,1                      ; alive
  ret r0,0                      ; dead
  ;; conway_alive:
  cp r0,2
  skip nz,1
  ret r0,1
  cp r0,3
  skip nz,1
  ret r0,1
  ret r0,0

initglider:
  ;; page
  mov r9,0x4                  ;next page to draw
  mov r0,r9
  xor r0,0b0110
  mov r1,r0
  mov r2,0
  mov r0,0
fillgliderzero:
  mov [r1:r2], r0
  inc r2
  skip c,2
  goto fillgliderzero
  inc r1
  mov r2,0
fillgliderzero2:
  mov [r1:r2], r0
  inc r2
  skip c,2
  goto fillgliderzero2

  ;; add glider
  mov r2,0x6
  mov r0,0b0111
  mov [r1:r2],r0
  inc r2
  mov r0,0b0001
  mov [r1:r2],r0
  inc r2
  mov r0,0b0010
  mov [r1:r2],r0

goto afterfill

init_r_pentomino:
  ;; page
  mov r9,0x4                  ;next page to draw
  mov r0,r9
  xor r0,0b0110
  mov r1,r0
  mov r2,0
  mov r0,0
  ;; loop: fill first page
  mov [r1:r2], r0
  inc r2
  skip c,1
  jr -4

  inc r1
  mov r2,0
  ;; loop: fill second page
  mov [r1:r2], r0
  inc r2
  skip c,1
  jr -4

  ;; add r-pentomino
  mov r2,0x6
  mov r0,0b0011
  mov [r1:r2],r0
  inc r2
  mov r0,0b0110
  mov [r1:r2],r0
  inc r2
  mov r0,0b0010
  mov [r1:r2],r0

goto afterfill
