;;; conway's game of life
;;; memory:
;;; 0x0: registers
;;; 0x1: available
;;; 0x2: fb0-a
;;; 0x3; fb0-b
;;; 0x4: fb1-a
;;; 0x5: fb2-b
;;; 0x6-0xE: conway counters
;;; 0xF: flags
;;; registers:
;;; R8: "free"
;;; R9: currently displayed page 0x4 or 0x2 (xor with 0b0110 to get the other)
;;; R9 next page to display
init:
  ;; 0b1010 to turn off ALU display
  ;; 0b0010 to just relocate IN/OUT to last page
  ;; (it seems like they still talk to IO. don't become general purpose registers)
  mov R0,0b0010
  mov [0xF3],R0                 ; WRFLAGS
  ;; set up sync
  mov R0, 15
  mov [0xF2], R0                ; sample code on 0xFC page puts this into 0xF4?
  mov R0,0b0001                 ; low bit starts sync
  mov [0xFC], R0                ; KeyStatus bit zero is handshaking bit for sync

  ;; page
  mov R9,0x2                   ;next page to draw

  ;; fill page at R9 with random
  mov R1,R9
  mov R2,0
fill0:
  ;;  mov r0, [0xFF]
  mov r0,r2
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill0
  ;; fill page at R9+1 with random
  inc R1
  mov R2,0
fill1:
  ;;   mov r0, [0xFF]
  mov r0,r2
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill1

  ;; fill page not at R9 with random
  mov R0,R9
  xor R0,0b0110
  mov R1,R0
  mov R2,0
fill2:
  mov r0,0
  ;;   mov r0, [0xFF]
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill2
  ;; fill page not at R9+1 with random
  inc R1
  mov R2,0
fill3:
  mov r0, 0
  ;;   mov r0, [0xFF]
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill3

  ;; set display page to R9
  mov R0,R9
  mov [0xF0],R0

loop:
  ;; zero neighbor counters in 0x60-0xEF
  mov R2,0x6
zero_neighbor_page_loop:
  mov R0,0x0
  mov R1,0                      ; entry in page
  ;; inner:
  mov [R2:R1],R0
  inc r1
  skip c,1
  jr -4
  inc r2
  mov r0,r2
  cp r0,0xF
  skip z,2
  goto zero_neighbor_page_loop

  ;; active bit
  ;; R7:R6 stores previous bits
  mov r0,R9                     ; find previous page
  xor r0,0b0110
  mov r7,r0
  mov R6,0                      ; in-page addr
  ;; R4:R3 stores count of living neighbors
  mov r4,0x6
inc_neighbor_page_loop:
  mov r3,0x0
  mov r0,[R7:R6]
  mov r5,r0
  ;; unrolled 4x
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  ;; second page
  inc r7
  mov r0,[R7:R6]
  mov r5,r0
  ;; unrolled 4x
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3
  rrc r5
  skip nc,2
  gosub do_increment
  inc r3

  ;; move to next row
  inc r4
  dec r7
  inc r6
  skip c,2
  goto inc_neighbor_page_loop


  ;; swap R8/R9 registers
  mov r0,R9
  xor r0,0b0110
  mov r9,r0

  ;; update page display
  mov R0,R9
  mov [0xF0],R0

  ;; wait for sync
  mov R0, [244]                 ; RdFlags
  bit R0,0                      ; test user sync bit
  skip NZ,1                     ;
  jr -4                         ; loop
  goto loop

;;; increment counters at 8 addresses centered at [R4:R3]
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
  ;; increment the value at [R4:R3]
  ;; 0x6 <= R4 <= 0xD
  ;; 0x0 <= R3 <= 0xF
  mov R0,[R4:R3]
  inc R0
  mov [R4:R3],R0
  ret R0,0

north:
  ;; subtract 1 with wrapping
  mov r0, 0b1111
  add r3, r0
  ret R0,0
south:
  ;; add 1 with wrapping
  mov r0, 0b0001
  add r3, r0
  ret R0,0
west:
  mov r0,r4
  add r0, 0b1101                ; -5
  and r0, 0b0111
  add r0, 0x6
  mov r4,r0
  ret R0,0
east:
  mov r0,r4
  add r0, 1
  and r0, 0b0111
  add r0, 0x6
  mov r4,r0
  ret R0,0

do_conway:
  ;; set carry flag based on:
  ;;  - existing carry flag (c: alive, nc: dead)
  ;;  - R2 number of neighbors
  ret R0,0
