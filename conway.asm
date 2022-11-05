;;; conway's game of life
;;; memory:
;;; 0xA0-0xBF fb1
;;; 0xC0-0xDF fb2
;;; registers:
;;; R9 next page to display
;;; R8 previous page
;;; display pages toggle between 0x2 and 0x4
R8it:
  ;; 0b1010 to turn off ALU display
  ;; 0b0010 to just relocate R9/R8 to last page
  mov R0,0b0010
  mov [0xF3],R0                 ; WRFLAGS
  ;; set up sync
  mov R0, 15
  mov [0xF2], R0                ; sample code on 0xFC page puts this into 0xF4?
  mov R0,0b0001                 ; low bit starts sync
  mov [0xFC], R0                ; KeyStatus bit zero is handshakR8g bit for sync

  ;; page
  mov R9,0x2                   ;next page to draw
  mov R8,0x4

  ;; fill page at R9 with random
  mov R1,R9
  mov R2,0
fill0:
  mov r0, [0xFF]
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill0
  ;; fill page at R9+1 with random
  inc R1
  mov R2,0
fill1:
  mov r0, [0xFF]
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill1

  ;; fill page at R8 with random
  mov R1,R8
  mov R2,0
fill2:
  mov r0, [0xFF]
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill2
  ;; fill page at R8+1 with random
  inc R1
  mov R2,0
fill3:
  mov r0, [0xFF]
  mov [R1:R2], R0
  inc r2
  skip c,2
  goto fill3

  ;; set display page to R9
  mov R0,R9
  mov [0xF0],R0

loop:
  ;; swap R8/R9 registers
  mov r0,R9
  mov R9,R8
  mov R8,r0

  ;; update page display
  mov R0,R9
  mov [0xF0],R0

  ;; wait for sync
  mov R0, [244]                 ; RdFlags
  bit R0,0                      ; test user sync bit
  skip NZ,1                      ;
  jr -4                         ; loop
  goto loop
