Keyboard:

!start: ldx #$00
!loop:  stx $e810
        lda $e812
        and #%01000000
        beq !exit+
        lda $e812
        and #%10000000
        beq !exit_2+
        lda $e812
        and #%00100000
        beq !exit_3+
!cont:  inx
        cpx #$0a
        bne !loop-
        jmp !start-
!exit:  cpx #$07
		bne !next+
		lda #$32     // 2
		rts
!next:  cpx #$06
		bne !next+
		lda	#$31     // 1  
		rts 
!next:  cpx #$05
		bne !next+
		lda	#$35     // 5
		rts   
!next:  cpx #$04
		bne !cont-
		lda	#$34     // 4   
		rts

!exit_2: cpx #$06
		 bne !next+  // 3
		 lda #$33
		 rts
!next:	 cpx #$04    // 6
		 bne !cont-
		 lda #$36
		 rts

!exit_3: cpx #$06
	     bne !cont-  // return
	     lda #$0d
	     rts
