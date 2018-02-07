.export bankcall_table

.macro bankcall_entry callid, entrypoint
  .exportzp callid
  .import entrypoint
  callid = <(*-bankcall_table)
  .assert callid < 256, error, "too many interbank calls"
  .addr entrypoint-1
  .byt <.bank(entrypoint)
.endmacro

.segment "RODATA"
; The macro takes two arguments:
; the external name of the method (loaded into X before bankcall)
; and the entry point within the bank.
bankcall_table:
  bankcall_entry load_chr_ram,       load_chr_ram_far
  bankcall_entry init_player,        init_player_far
  bankcall_entry move_player,        move_player_far
  bankcall_entry draw_player_sprite, draw_player_sprite_far

