;;; conway's game of life
;;; memory:
;;; 0xA0-0xBF fb1
;;; 0xC0-0xDF fb2
;;; registers:
;;; R9 new page
init:
  ;; I'm not going to use OUT/IN for I/O
  mov R0,0b0010                 ;
  mov [0xF3],R0                 ; WRFLAGS
  ;; todo: set up sync
  mov R0, 15
  mov [0xF2], R0                ; sample code on 0xFC page puts this in F4?
  mov R0,0b0001                 ; low bit starts sync
  mov [0xFC], R0                ; KeyStatus bit zero is handshaking bit for sync

  ;; page
  mov R8,0xA                   ;next page to draw
  ;; loop
loop:
  ;; todo: set old page register and new page register
  mov R9,0xA

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

  ;; todo: swap active page
  mov R0,R9
  mov [0xF0],R0

  ;; wait for sync
  mov R0, [244]                 ; RdFlags
  bit R0,0                      ; test user sync bit
  skip NZ,1                      ;
  jr -4                         ; loop
  goto loop
