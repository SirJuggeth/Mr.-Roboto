;;;;;;;; assembler directives 
	LIST	P=PIC18F452, F=INHX32, C=160, N=0, ST=OFF, MM=OFF, X=ON
	#include	P18F452.inc


	CONFIG	OSC=HS			;select HS oscillator
	CONFIG	PWRT=ON, BOR=ON, BORV=42	
	CONFIG	WDT=OFF, LVP=OFF	;disable watchdog timer
					; and low voltage power
;;;;;;; variables and constants ;;;;;;;

	shiftr_count EQU d'1'
	cblock		0x000
	tmr1h_c
	tmr1l_c
	max_loops
	max_count
	turn_count
	endc

;;;;;; macro definitions ;;;;;;;

;movlf - command to move a literal value into a file register
movlf	macro	imm,dest
	movlw	imm
	movwf	dest
	endm
	
LED_ON  macro
        movlf	b'11101111',LATA    ;Alive, Right, Center, Left LEDs on
        endm
	
LED_OFF macro
        movlf	b'00000000',LATA    ;Alive, Right, Center, Left LEDs off
        endm

ALIVE   macro
        btg	LATA, 4         ;toggle bit for Alive LED
        endm
	
;;;;;;; vectors ;;;;;;;

	org	0x0000	;reset vector
	goto	start	;start of program

	org	0x0008	;high priority interrupt vector
	goto	$	;none for now

	org	0x0018	;low priority interrupt vector
	goto	$	;none for now

;;;;;;; Start of the actual program ;;;;;;;

start

;;;;;;;Initializing PORTS;;;;;;;
	movlf	b'01100001',TRISA	;set data direction
	movlf	b'10001110',ADCON1	;set digital/analog functions
	clrf	PORTA			;initialize L, C, R LEDs to off

	movlf	b'10000001',T1CON	;set data direction
	movlf	b'00000100',TRISB	;set data direction
	movlf	b'00110000',PORTB	;set data direction
	
;;;;;;; Main of the program ;;;;;;;
main_l
	;rcall	forward
	;rcall	left
	;rcall	right
	;rcall	stop1
	LED_ON

	;;;;;;; Trigger Code for Ultrasonic sensor;;;;;;;
	bsf		LATB,3
	rcall	ten_us	
	bcf		LATB,3
	
	;;;;;;; Reading Echo ;;;;;;;;
	;-CCP1 will be configured to capture a rising edge
	;-whenever that occurs TMR3 will be cleared and start to count
	;-CCP2 instead will listen for falling edge inputs in which case TMR3 will stop and its value will be saved into CCPR2H:CCPR2L registers
	;-that value will represent the duration of the high signal on pin Echo, which is proportional to the distance to the objrct

	movlw d'.5'			; divide values by .32
	movwf shiftr_count
shiftr_again	
	bcf STATUS,C		; we want the Carry to be 0 right now
	rrcf CCPR2High,F 	; shift right CCPR2High with Carry
	rrcf CCPR2Low,F		; shift right CCPR2Low with Carry
	decf shiftr_count,F	; is this the fith time we rotate right?
	bnz shiftr_again	; no: shift right again
				; yes: raw data CCPR2High and CCPR2Low should be divided to .32 now
	movf CCPR2Low,W		; 
	call DivisionByX	; We divided by .32, but to get a better result raw data should be divided by .35 ;;;;;;;;;;;;;;;Insert Actual functions;;;;;;
	movf quotient,W		; So, we remove 10% off CCPR2Low (.35/.32=0,1)
	subwf CCPR2Low,F	;


	;;;;;;;Get the Robot to do Something;;;;;;;
	;btfss	PORTB,2
	ALIVE
	LED_OFF

	bra	main_l
	
	
;;;;;;;;;;;;;;WHEELS;;;;;;;;;;;;;;
	
;;;;;;;Turns Robot left for 3/4 seconds;;;;;;;
left	movlf	h'1A',turn_count
l_loop	movlf	b'00110000',TRISB
	rcall	delay3
	clrf	TRISB
	decfsz	turn_count
	bra	l_loop
	return
	
;;;;;;;Turns Robot right for 3/4 seconds;;;;;;;	
right	movlf	h'1A',turn_count
r_loop	movlf	b'00110000',TRISB
	rcall	delay3
	clrf	TRISB
	rcall	delay2
	decfsz	turn_count
	bra	r_loop
	return
	
;;;;;;;Moves Robot Forwards;;;;;;;
forward movlf	h'100',turn_count
f_loop	movlf	b'00010000',TRISB
	rcall	delay2
	movlf	b'00100000',TRISB
	rcall	delay1
	clrf	TRISB
	decfsz	turn_count
	bra	f_loop
	return
	
;;;;;;;Loops through Forward roll but LEDs and such do not work;;;;;;;
f_main	rcall	forward
	bra	f_main
	return

;;;;;;;Stops Robot for 2 seconds;;;;;;;
stop1	movlf	h'10',turn_count
s_loop	clrf	TRISB
	rcall	delay3
	decfsz	turn_count
	bra	s_loop
	return

;;;;;;;;;;;;;;DELAYS;;;;;;;;;;;;;;
	
;;;;;;;1ms dela;;;;;;;
delay1	movlf	h'1',max_loops
del_out1    movlf	h'1',max_count
del_in1	rcall	ten_ms			;kill some time
	decfsz	max_count		;decrement count
	bra	del_in1			;loop if not zero
	decfsz	max_loops		;   else decrement loop number
	bra	del_out1			; loop if not zero
	return				;   else return

;;;;;;; 2ms delay;;;;;;;
delay2	movlf	h'2',max_loops
del_out2    movlf	h'1',max_count
del_in2	rcall	ten_ms			;kill some time
	decfsz	max_count		;decrement count
	bra	del_in2			;loop if not zero
	decfsz	max_loops		;   else decrement loop number
	bra	del_out2			; loop if not zero
	return	

;;;;;;;10ms delay;;;;;;;
delay3	movlf	h'A',max_loops
del_out3    movlf	h'A',max_count
del_in3	rcall	ten_ms			;kill some time
	decfsz	max_count		;decrement count
	bra	del_in3			;loop if not zero
	decfsz	max_loops		;   else decrement loop number
	bra	del_out3		; loop if not zero
	return		

;;;;;;;One Second Delay;;;;;;;
One_Sec	    movlf   D'100',max_count	;set count to 10
oneth_start rcall   ten_ms		;call 10ms delay
	    decfsz  max_count		;decrement count, skip next command if zero
	    bra	    oneth_start		;loop if not zero - relative branch, back 2 lines
		
	    return			;  else return	 

;;;;;;; Delay time adjustment equations;;;;;;;
time_adj_ten_ms	equ	d'65536'-d'2500'+d'12'+2
time_adj_ten_us	equ	d'65536'-d'2500'+d'12'+2

	
;;;;;;;Ten us Delay;;;;;;;
ten_us	btfss	PIR1,TMR1IF	;test timer0 rollover flag
	bra	ten_ms		;... polling loop

	movff	TMR1L,tmr1l_c	;read 16 bit counter
	movff	TMR1H,tmr1h_c	;get buffered high half 
	movlw	low time_adj_ten_us	;add time adjustment
	addwf	tmr1l_c,F
	movlw	high time_adj_ten_us
	addwfc	tmr1h_c,F
	movff	tmr1h_c,TMR1H	;pre-load high half first
	movff	tmr1l_c,TMR1L	;write the 16 bit counter

	bcf	PIR1,TMR1IF	;clear timer0 rollover flag
	return			;and return	

	
;;;;;;;Ten ms Delay;;;;;;;
ten_ms	btfss	PIR1,TMR1IF	;test timer0 rollover flag
	bra	ten_ms		;... polling loop

	movff	TMR1L,tmr1l_c	;read 16 bit counter
	movff	TMR1H,tmr1h_c	;get buffered high half 
	movlw	low time_adj_ten_ms	;add time adjustment
	addwf	tmr1l_c,F
	movlw	high time_adj_ten_ms
	addwfc	tmr1h_c,F
	movff	tmr1h_c,TMR1H	;pre-load high half first
	movff	tmr1l_c,TMR1L	;write the 16 bit counter

	bcf	PIR1,TMR1IF	;clear timer0 rollover flag
	return			;and return

	end
	