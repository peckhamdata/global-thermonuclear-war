.import source "vars.asm"

* = $4000

start:

.var target_blank = $2d
.var target_name_len = $0b
.var target_data_len = target_name_len + $0b
.var num_cities = $06
.var blast_radius = $06
.var screen = $8000

// Display the two sides - with thanks to George Phillips
// http://48k.ca/wgascii.html

two_tribes:     
                lda #$00
                sta plot_color_difference // No color on PET
                lda #$ff
                sta plot_delay

                ldx #$12
                lda #<intro_text
                sta text_src
                lda #>intro_text
                sta text_src+1
!loop:          jsr text_plot
                jsr delay
                jsr delay            
                lda text_src
                sec
                adc #$27
                sta text_src
                bcc !next+
                inc text_src+1
!next:          dex
                bne !loop-            

                jsr delay
                jsr delay

                lda #$00
                sta plot_delay

                lda #<two_tribes_map
                sta copy_mem_source_lo
                lda #>two_tribes_map
                sta copy_mem_source_hi

                lda #<screen
                sta copy_mem_dest_lo
                lda #>screen
                sta copy_mem_dest_hi

                lda #$00
                sta copy_mem_dest_length_lo
                lda #$04    
                sta copy_mem_dest_length_hi

                jsr copy_mem

                lda #<main_menu_text
                sta text_src
                lda #>main_menu_text
                sta text_src+1

                jsr text_plot
!menu_loop:		
                jsr Keyboard
                // bcs !next+
                // cmp #$ff
                // beq !next+
                // Check A for Alphanumeric keys
                cmp #$31
                bcc !next+
                cmp #$32
                beq !do+
                bcs !next+
!do:
                sta side
!next:
                lda side
                bne !next+
		        jmp !menu_loop-
!next:          
                // Display map
                clc
                sbc #$30
                sta side
                tax
                lda #$01
                sta (human),x

!turn:          lda side      
                tax
                lda (maps_low),x                
                sta copy_mem_source_lo
                lda (maps_hi),x
                sta copy_mem_source_hi
                lda #<screen
                sta copy_mem_dest_lo
                lda #>screen
                sta copy_mem_dest_hi

                jsr copy_mem
                ldx side
                lda (cities_lo),x
                sta text_src
                lda (cities_hi),x
                sta text_src+1

                ldx #$00
!loop:          
                ldy #$00
                lda text_src
                sta $02
                lda text_src+1
                sta $03
                lda ($02),y
                sta p0
                dec p0
                iny
                lda ($02),y
                sta p1
                lda #$2e
                sta plot_char
                jsr plot_point
                dec p0
                txa
                clc
                adc #$31
                sta plot_char
                jsr plot_point
                jsr text_plot
                lda text_src
                clc
                adc #target_data_len // #$0d
                sta text_src
                bcc !next+
                inc text_src+1
!next:                
                inx
                cpx #num_cities
                bne !loop-

                lda #<turn_text
                sta text_src
                lda #>turn_text
                sta text_src+1

                jsr text_plot

                lda #<selected_targets_text
                sta text_src
                lda #>selected_targets_text
                sta text_src+1

                jsr text_plot

// Is it a human player this round?
                ldx side
                lda human,x
                sta auto

// Could factor this out into a function

                ldx #$00
                clc
!menu_loop:              
                lda auto
                bne !next+
                // set on auto pilot
                lda (mad_targets),x
                sta (targets),x
                jmp do_targets
!next:                
                txa
                pha
!again:         jsr Keyboard
                // bcs !next+
                // cmp #$ff
                // beq !next+
                // Check A for Alphanumeric keys
                cmp last_key
                beq !again-
                sta last_key
                cmp #$31
                bcc !next+
                cmp #$36
                beq !do+
                bcs !next+
!do:
                tay
                pla
                tax
                tya
                sec
                sbc #$31
                sta (targets),x 
do_targets:
                jsr set_target

                lda #<selected_targets_text
                sta text_src
                lda #>selected_targets_text
                sta text_src+1

                jsr text_plot

                inx
                jmp !cont+
!next:
                pla
                tax
!cont:          cpx #$02
                bne !menu_loop-
!next:          
                jsr launch_missiles
                // Switch sides
                lda side
                eor #$01
                sta side

                // Clear targets
                tya
                pha
                lda #target_blank
                ldy #target_name_len
!loop:          sta target_1+4,y
                sta target_2+4,y
                dey
                bne !loop-
                lda #<selected_targets_text
                sta text_src
                lda #>selected_targets_text
                sta text_src+1

                dec game_round
                lda game_round
                bne !cont+
                // end of game
                lda #$ff
                sta delay_outer
                lda #$ff
                sta delay_inner
                jsr delay
                jsr delay
                jsr dialogue
                pla
                tay
!end:           jsr Keyboard
                cmp #$0d
                bne !end-
                rts

!cont:          
                pla
                tay
                jmp !turn-
                rts


launch_missiles: ldx #$00
                lda #$01
                sta plot_delay

!loop:          lda target_x1,x
                sta curve_p1_x
                lda target_y1,x
                sta curve_p1_y

                lda target_x2,x
                sta curve_p2_x
                lda target_y2,x
                sta curve_p2_y

                lda target_x3,x
                sta curve_p3_x
                lda target_y3,x
                sta curve_p3_y

                jsr delay
                jsr telemetry
                jsr delay


                // Launch

                lda #$2b
                sta plot_char
                lda #$0a
                sta curve_num_segments

                jsr curve_plot

                lda #$00
                sta plot_delay

                lda curve_p3_x
                sta circ_x
                lda curve_p3_y
                sta circ_y
                jsr bang

                lda #$01
                sta plot_delay

                inx
                cpx #$02
                bne !loop-
                rts 

set_target:   
                tya
                pha
                txa
                pha
                lda (targets),x
                beq !next+
                tax
                lda #$00
!loop:          clc
                adc #target_data_len
                dex
                bne !loop-
!next:          sta tmp_offset

                ldx side
                lda (cities_lo),x
                sta $02
                lda (cities_hi),x
                sta $03
                ldy tmp_offset
                iny
                iny
                pla
                tax
!loop:          lda ($02),y
                pha
                tya
                sec
                sbc tmp_offset
                tay
                pla
                cpx #$01
                beq !slot_2+
                sta target_1+3,y // stick it in the right targets box
                jmp !cont+
!slot_2:        sta target_2+3,y
!cont:          iny
                cpy #target_name_len+2
                beq !next+
                tya
                clc
                adc tmp_offset
                tay
                jmp !loop-
!next:          tya
                clc
                adc tmp_offset
                tay
                iny
                iny
                cpx #$01
                beq !slot_2+
                lda ($02),y
                sta target_x1
                iny      
                lda ($02),y
                sta target_y1
                iny      
                lda ($02),y
                sta target_x2
                iny      
                lda ($02),y
                sta target_y2
                iny      
                lda ($02),y
                sta target_x3
                iny      
                lda ($02),y
                sta target_y3  
                iny      
                lda ($02),y
                sta mad_targets  
                jmp !exit+
!slot_2:                    
                lda ($02),y
                sta target_x1+1
                iny      
                lda ($02),y
                sta target_y1+1
                iny      
                lda ($02),y
                sta target_x2+1
                iny      
                lda ($02),y
                sta target_y2+1
                iny      
                lda ($02),y
                sta target_x3+1
                iny      
                lda ($02),y
                sta target_y3+1
                iny      
                lda ($02),y
                sta mad_targets+1  
!exit:          pla
                tay

                rts

tmp_offset: .byte $00

TempX: .byte $00
TempY: .byte $00

side:           .byte $00
human:          .byte $00, $00
auto:           .byte $00
last_key:       .byte $ff

game_round:     .byte $06

cities_lo:      .byte <ussr_cities, <usa_cities
cities_hi:      .byte >ussr_cities, >usa_cities

// x,y, name (9 chars)

usa_cities:     .byte $03, $04
                .text "seattle    \0"
                .byte $1c, $00
                .byte $0f, $08
                .byte $03, $04
                .byte $00

                .byte $24, $07
                .text "nyc        \0"
                .byte $00, $00
                .byte $14, $03
                .byte $24, $07
                .byte $01

                .byte $0f, $09
                .text "norad      \0"
                .byte $27, $00
                .byte $14, $15
                .byte $0f, $09
                .byte $05

                .byte $07, $0b
                .text "las vegas  \0"
                .byte $20, $00
                .byte $09, $0a
                .byte $07, $0b
                .byte $02

                .byte $1c, $0b
                .text "washington \0"
                .byte $00, $00
                .byte $09, $08
                .byte $1c, $0b
                .byte $03

                .byte $14, $12
                .text "houston    \0"
                .byte $00, $00
                .byte $18, $05
                .byte $14, $12
                .byte $04

ussr_cities:    
                .byte $0a, $06
                .text "archangel  \0"
                .byte $00, $00
                .byte $04, $06
                .byte $0a, $06
                .byte $00

                .byte $07, $09
                .text "moscow     \0"
                .byte $00, $00
                .byte $04, $07
                .byte $07, $09
                .byte $03

                .byte $1d, $0b
                .text "vladivostok\0"
                .byte $00, $00
                .byte $0f, $0f
                .byte $1d, $0b
                .byte $02

                .byte $03, $0d
                .text "minsk      \0"
                .byte $00, $00
                .byte $02, $09
                .byte $03, $0d
                .byte $01

                .byte $13, $0d
                .text "tomsk      \0"
                .byte $00, $00
                .byte $02, $09
                .byte $13, $0d
                .byte $05

                .byte $03, $11
                .text "sevastopol \0"
                .byte $00, $00
                .byte $02, $0a
                .byte $03, $11
                .byte $04

targets:        .byte $00, $00
mad_targets:    .byte $00, $00

target_x1:      .byte $00, $00
target_y1:      .byte $00, $00

target_x2:      .byte $00, $00
target_y2:      .byte $00, $00

target_x3:      .byte $00, $00
target_y3:      .byte $00, $00


maps_low:       .byte <ussr_map, <usa_map
maps_hi:        .byte >ussr_map, >usa_map 

main_menu_text:	.byte $08, $14
                .text "which side do you want?\n"
                .byte $08, $16
                .text "1.   united states\n"
                .byte $08, $17
                .text "2.   soviet union\0"

turn_text:      .byte $04, $14
                .text "awaiting first strike command\n"
                .byte $00, $16
                .text "please list primary targets by number\0"

selected_targets_text:

                target_1:
                .byte $02, $18
                .text " i:-----------\n"
                target_2:
                .byte $13, $18
                .text "ii:-----------\0"


// city
// inbound co-ords
// seattle, las vegas, nyc, washington, texas
// moscow, minsk, kyev, st petersburg, sevastopol


telemetry:
                tya
                pha
                lda #$20 // <screen+(40*20)
                sta fill_mem_from
                lda #$83 // >screen+(40*20)
                sta fill_mem_from+1
                lda #$20
                sta fill_mem_char
                lda #$c8
                sta fill_mem_size
                jsr fill_mem

                lda #<tele_text
                sta text_src
                lda #>tele_text
                sta text_src+1

                jsr text_plot

                // update data
                lda new_data_prt
                clc
                adc #$84
                sta new_data_prt
                bcc !next+
                inc new_data_prt+1
!next:                
                lda new_data_prt
                sta $02
                lda new_data_prt+1
                sta $03
                ldy #$00
!loop:          lda ($02),y
                sta trajectory_data,y
                iny
                cpy #$85
                bne !loop- 
                pla
                tay
                rts
new_data_prt:   .byte <trajectory_data, >trajectory_data

tele_text:
                .byte $01, $14
                .text "trajectory heading\n"
                .byte $01, $15
                .byte $77, $77, $77, $77, $77, $77, $77, $77, $77, $77, $77, $77
                .byte $77, $77, $77, $77, $77, $77
                .text "\n"
                .byte $15, $14
                .text "trajectory heading\n"
                .byte $15, $15
                .byte $77, $77, $77, $77, $77, $77, $77, $77, $77, $77, $77, $77
                .byte $77, $77, $77, $77, $77, $77
                .text "\n"

trajectory_data:
                .byte $01, $16
                .text "a-5214-a "
                .text "9226 5234\n"
                .byte $01, $17
                .text "       b "
                .text "6824 5132\n"
                .byte $01, $18
                .text "       c "
                .text "2196 7261\n"

                .byte $15, $16
                .text "a-5212-a "
                .text "1282 1214\n"
                .byte $15, $17
                .text "       b " 
                .text "1534 1232\n"
                .byte $15, $18
                .text "       c "
                .text "0096 8261\0"
///
                .byte $01, $16
                .text "z-af12-b "
                .text "9116 5a34\n"
                .byte $01, $17
                .text "       e "
                .text "1324 5122\n"
                .byte $01, $18
                .text "       2 "
                .text "2001 1971\n"

                .byte $15, $16
                .text "x-201a-2 "
                .text "1142 31a4\n"
                .byte $15, $17
                .text "       3 " 
                .text "1214 1032\n"
                .byte $15, $18
                .text "       4 "
                .text "0096 8afs\0"
///
                .byte $01, $16
                .text "a-w254-a "
                .text "1114 5132\n"
                .byte $01, $17
                .text "       c "
                .text "2324 51x2\n"
                .byte $01, $18
                .text "       x "
                .text "2021 177a\n"

                .byte $15, $16
                .text "b-1110-1 "
                .text "1142 31a4\n"
                .byte $15, $17
                .text "       5 " 
                .text "4254 1212\n"
                .byte $15, $18
                .text "       7 "
                .text "0126 842s\0"
///
                .byte $01, $16
                .text "c-cccp-1 "
                .text "1004 1212\n"
                .byte $01, $17
                .text "       2 "
                .text "1214 xx12\n"
                .byte $01, $18
                .text "       3 "
                .text "3421 aa1a\n"

                .byte $15, $16
                .text "b-c120-4 "
                .text "1192 12a4\n"
                .byte $15, $17
                .text "       5 " 
                .text "4124 1221\n"
                .byte $15, $18
                .text "       6 "
                .text "3xa6 812s\0"

///
                .byte $01, $16
                .text "a-usz1-2 "
                .text "1204 1ad2\n"
                .byte $01, $17
                .text "       7 "
                .text "0001 xd2a\n"
                .byte $01, $18
                .text "       4 "
                .text "1212 bf1a\n"

                .byte $15, $16
                .text "b-tra0-2 "
                .text "1001 99a4\n"
                .byte $15, $17
                .text "       1 " 
                .text "2112 12af\n"
                .byte $15, $18
                .text "       3 "
                .text "300x ffff\0"

///
                .byte $01, $16
                .text "1-1121-3 "
                .text "101a 1112\n"
                .byte $01, $17
                .text "       2 "
                .text "0001 xd2a\n"
                .byte $01, $18
                .text "       8 "
                .text "1212 bf1a\n"

                .byte $15, $16
                .text "b-tra0-4 "
                .text "1215 99a4\n"
                .byte $15, $17
                .text "       2 " 
                .text "0012 12af\n"
                .byte $15, $18
                .text "       6 "
                .text "211x fdaf\0"

///
                .byte $01, $16
                .text "4-21af-2 "
                .text "1022 99ff\n"
                .byte $01, $17
                .text "       2 "
                .text "0312 xf21\n"
                .byte $01, $18
                .text "       8 "
                .text "17ad 993a\n"

                .byte $15, $16
                .text "5-cca--4 "
                .text "1215 1124\n"
                .byte $15, $17
                .text "       2 " 
                .text "0752 123f\n"
                .byte $15, $18
                .text "       6 "
                .text "671a 1213\0"

///
                .byte $01, $16
                .text "1-21---3 "
                .text "1022 99ff\n"
                .byte $01, $17
                .text "       9 "
                .text "0312 xf21\n"
                .byte $01, $18
                .text "       a "
                .text "1aa7 123a\n"

                .byte $15, $16
                .text "5-dfa--4 "
                .text "1005 6714\n"
                .byte $15, $17
                .text "       6 " 
                .text "2112 ffff\n"
                .byte $15, $18
                .text "       7 "
                .text "99xa 2113\0"

///
                .byte $01, $16
                .text "1-1111-0 "
                .text "1000 0010\n"
                .byte $01, $17
                .text "       1 "
                .text "0001 x111\n"
                .byte $01, $18
                .text "       0 "
                .text "1212 x101\n"

                .byte $15, $16
                .text "0-0000-0 "
                .text "1101 1101\n"
                .byte $15, $17
                .text "       0 " 
                .text "001x 0011\n"
                .byte $15, $18
                .text "       1 "
                .text "010x 0010\0"

///
                .byte $01, $16
                .text "1-1111-0 "
                .text "---0 0--0\n"
                .byte $01, $17
                .text "       1 "
                .text "---1 x--1\n"
                .byte $01, $18
                .text "       0 "
                .text "-err 0---\n"

                .byte $15, $16
                .text "1-ffff-f "
                .text "11-- -fff\n"
                .byte $15, $17
                .text "       x " 
                .text "xxxx ----\n"
                .byte $15, $18
                .text "       x "
                .text "xxxx xxxx\0"

///
                .byte $01, $16
                .text "1----1- 0 "
                .text "--  0--0\n"
                .byte $01, $17
                .text "       0 "
                .text "00 1 x-ff\n"
                .byte $01, $18
                .text "       0 "
                .text "-err   f-\n"

                .byte $15, $16
                .text "1-ff---f "
                .text "11-- -x f\n"
                .byte $15, $17
                .text "       x " 
                .text "xxxx -xx-\n"
                .byte $15, $18
                .text "       x "
                .text "xxxx xeol\0"

///
                .byte $01, $16
                .text "-----n- 0"
                .text "--  ---- \n"
                .byte $01, $17
                .text "       0 "
                .text "00      f\n"
                .byte $01, $18
                .text "       0"
                .text "-      f-\n"

                .byte $15, $16
                .text "  ..---f "
                .text "1 -- -0 f\n"
                .byte $15, $17
                .text "       x " 
                .text "x x -. .-\n"
                .byte $15, $18
                .text "       x "
                .text "x  x     \0"

dialogue:       
                lda #$05
                sta nine_slice_x
                lda #$02
                sta nine_slice_y

                lda #$1d
                sta nine_slice_w
                lda #$14
                sta nine_slice_h

                jsr nine_slice_plot

                ldx #$07
                lda #<dialogue_text
                sta text_src
                lda #>dialogue_text
                sta text_src+1
!loop:          jsr text_plot
                jsr delay
                jsr delay            
                lda text_src
                sec
                adc #$1d
                sta text_src
                bcc !next+
                inc text_src+1
!next:          dex
                bne !loop-            
                rts

intro_text:

.byte $00,$00
.text "                                    \0"
.byte $00,$00
.text "logon: joshua                       \0"
.byte $00,$02
.text "greetings professor falken.         \0"
.byte $00,$04
.text "hello.                              \0"
.byte $00,$06
.text "how are you feeling today?          \0"
.byte $00,$08
.text "i'm fine how are you?               \0"
.byte $00,$09
.text "excellent. it's been a long time.   \0"
.byte $00,$0a
.text "can you explain the removal of your \0"
.byte $00,$0b
.text "user account on 6/23/73?            \0"
.byte $00,$0d
.text "people sometimes make mistakes.     \0"
.byte $00,$0e
.text "yes they do. shall we play a game?  \0"
.byte $00,$10
.text "love to.                            \0"
.byte $00,$11
.text "how about global thermonuclear war? \0"
.byte $00,$12
.text "wouldn't you prefer                 \0"
.byte $00,$13
.text "a good game of chess?               \0"
.byte $00,$15
.text "later.                              \0"
.byte $00,$17
.text "let's play global thermonuclear war.\0"
.byte $00,$18
.text "fine.                               \0"

dialogue_text:

.byte $06, $03
.text "greetings professor falken\0"
.byte $06, $07
.text "hello                     \0"
.byte $06, $0b
.text "a strange game.           \0"
.byte $06, $0d
.text "the only winning move is  \0"
.byte $06, $0f
.text "not to play               \0"
.byte $06, $11
.text "how about a nice game of  \0"
.byte $06, $13
.text "chess?                    \0"

delay_outer:     .byte $9f
delay_inner:     .byte $ff

delay:
                txa 
                pha
                tya
                pha
                ldx #$4f
!loop_i:        ldy #$ff
!loop_ii:       nop
                dey
                bne !loop_ii-
                dex
                bne !loop_i-
                pla
                tay
                pla
                tax
                rts

bang:
                txa
                pha
                lda #$a0
                sta plot_char
                lda #$14
                sta plot_buffer_y
                lda #$10
                sta delay_outer
                lda #$10
                sta delay_inner

                ldx #$01
!loop:          stx circ_radius
                jsr circ_plot
                jsr delay
                inx
                cpx #blast_radius
                bne !loop-

                lda #$20
                sta plot_char

                lda #$2e
                sta plot_char
                ldx #$01
!loop:          stx circ_radius
                jsr circ_plot

                // update the map for the next round

                txa
                pha
                lda plot_buffer_lo
                pha
                lda plot_buffer_hi
                pha
                ldx side
                lda (maps_low),x                
                sta plot_buffer_lo
                lda (maps_hi),x
                sta plot_buffer_hi

                jsr circ_plot
                pla
                sta plot_buffer_hi
                pla
                sta plot_buffer_lo

                pla
                tax

                jsr delay
                inx
                cpx #blast_radius
                bne !loop-
                lda #$19
                sta plot_buffer_y

                pla
                tax
                rts

.import source "curve.asm"
.import source "copy_mem.asm"
.import source "text.asm"
.import source "line.asm"
.import source "plot_point.asm"
.import source "math.asm"
.import source "maps.asm"
.import source "keys.asm"
.import source "circ.asm"
.import source "fill.asm"
.import source "nine_slice.asm"
