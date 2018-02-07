;
; BNROM driver for NES
; Copyright 2011-2018 Damian Yerrick
;
; Copying and distribution of this file, with or without
; modification, are permitted in any medium without royalty provided
; the copyright notice and this notice are preserved in all source
; code copies.  This file is offered as-is, without any warranty.
;

.include "bnrom.inc"  ; implements a subset of the same interface
.import reset_handler, nmi_handler, bankcall_table
.export nmi_handler_epilog

.segment "INESHDR"
  .byt "NES",$1A  ; magic signature
  .byt 8          ; size of PRG ROM in 16384 byte units
  .byt 0          ; size of CHR ROM in 8192 byte units
  .byt $21        ; lower mapper nibble, vertical mirroring
  .byt $20        ; upper mapper nibble
  
.segment "ZEROPAGE"
bankcallsaveA: .res 1

; Each bank has 32768 bytes: 32512 for you to use as you wish and
; a 256-byte footer for mapper interfacing.  This includes switching
; to the correct bank at power-on and to let subroutines in one bank
; call subroutines in another.
;
; This macro creates a 256-byte bank footer.
.macro resetstub_in segname
.segment segname

; To avoid bus conflicts, bankswitch needs to write a value
; to a ROM address that already contains that value.
identity16:
  .repeat 16, I
    .byte I
  .endrepeat

; The currently loaded bank, for use by code running in RAM
curPRGBank: .byte <.bank(*)

; Inter-bank method call gate.  The file bankcalltable.s contains a
; table of up to 85
; different methods that can be called from a different PRG bank.
; Typical usage:
;   ldx #move_character
;   jsr bankcall
.proc bankcall
  sta bankcallsaveA
  lda #<.bank(*)  ; Push the current bank
  pha
  lda #<.bank(bankcall_table)  ; Switch in the bank call table
  sta *-1
  lda bankcall_table+1,x  ; Push the address of the code
  pha
  lda bankcall_table,x
  pha
  lda bankcall_table+2,x
  tax
  sta identity16,x
  lda bankcallsaveA
  rts
.endproc

; Functions in the bankcall_table MUST NOT exit with 'rts'.
; Instead, they MUST exit with 'jmp bankrts'.
.proc bankrts
  sta bankcallsaveA
  pla
  tax
  sta identity16,x
  lda bankcallsaveA
  rts
.endproc

; The only IRQs on a discrete mapper are APU frame IRQ, which is
; deprecated, and DMC IRQ, which is primarily used for advanced
; split-screen techniques.  If you're using either, you probably
; know what you doing.
irq_handler:
  rti

; Save CPU registers and PRG bank, then switch to the bank containing
; the NMI handler.
.proc nmi_handler_prolog
  pha
  txa
  pha
  tya
  pha
  lda #<.bank(*)
  pha
  lda #<.bank(nmi_handler)
  sta *-1
  jmp nmi_handler
.endproc

; Restore PRG bank and CPU registers.
; NMI handler must end with 'jmp nmi_handler_epilog', not 'rti'
.proc nmi_handler_epilog
  pla
  tax
  sta identity16,x
  pla
  tay
  pla
  tax
  pla
  rti
.endproc

; Other critical subroutines that must go in all banks can go here.
; TODO: fill in

.res identity16 + $F0 - *

; On most discrete logic mappers (AOROM 7, BNROM 34, GNROM 66, and
; Crazy Climber UNROM 180), writing a value with bits 5-0 true
; (that is, $3F, $7F, $BF, $FF) switches in the last PRG bank, but
; it has to be written to a ROM address that has the same value.
resetstub_entry:
  sei
  ldx #$FF
  txs
  stx resetstub_entry + 2
  jmp reset_handler
  .addr nmi_handler_prolog, resetstub_entry, irq_handler
.endmacro

; Now put one copy of the bank footer in each bank.  Wrap all but
; one copy in a .scope to suppress errors about duplicate symbols.
.scope
resetstub_in "STUB00"
.endscope
.scope
resetstub_in "STUB01"
.endscope
.scope
resetstub_in "STUB02"
.endscope
resetstub_in "STUB03"

.segment "CODE"
