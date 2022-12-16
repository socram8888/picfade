
processor 10F202
radix dec
config WDTE = ON
config CP = OFF
config MCLRE = OFF

#include <xc.inc>

psect udata

; Current brightness, range [0, 127]
brightness: ds 1
global brightness

; Brightness increment delay
brightdelay: ds 1
global brightdelay

; PWM period, range [1, 33] (1 = 0%, 33 = 100%)
pwmperiod: ds 1
global pwmperiod

; PWM counter value, range [1, 32]
pwmcounter: ds 1
global pwmcounter

; Timer value at the beginning of the delay loop
tmrstartval: ds 1
global tmrstartval

psect code,abs
start:
	; Jump to main code
	goto main

sintable:
	; Log-sine table. Valid for W in range [0, 63]
	; Must be in the first 256 words of memory, hence the above goto
	;
	; Generated using:
	; sinpow = [round(32 * (sin(x * pi / 63 - pi / 2) / 2 + 0.5)) + 1 for x in range(64)]
	; '\n'.join(['\tretlw %d' % x for x in sinpow])
	addwf PCL
	retlw 1
	retlw 1
	retlw 1
	retlw 1
	retlw 1
	retlw 1
	retlw 2
	retlw 2
	retlw 2
	retlw 3
	retlw 3
	retlw 3
	retlw 4
	retlw 4
	retlw 5
	retlw 5
	retlw 6
	retlw 6
	retlw 7
	retlw 8
	retlw 8
	retlw 9
	retlw 10
	retlw 10
	retlw 11
	retlw 12
	retlw 13
	retlw 13
	retlw 14
	retlw 15
	retlw 16
	retlw 17
	retlw 17
	retlw 18
	retlw 19
	retlw 20
	retlw 21
	retlw 21
	retlw 22
	retlw 23
	retlw 24
	retlw 24
	retlw 25
	retlw 26
	retlw 26
	retlw 27
	retlw 28
	retlw 28
	retlw 29
	retlw 29
	retlw 30
	retlw 30
	retlw 31
	retlw 31
	retlw 31
	retlw 32
	retlw 32
	retlw 32
	retlw 33
	retlw 33
	retlw 33
	retlw 33
	retlw 33
	retlw 33

main:
	; On reset, W contains the oscillator calibration value. Use it.
	movwf OSCCAL

	; Configure GP0 as output
	movlw 0xFE
	tris GPIO

	; Configure OPTION register:
	;  - Disable wakeups on pin change, as we will not be sleeping
	;  - Enable weak pull ups
	;  - Select timer source as Fosc/4
	;  - Set prescaler to WDT and divide by 1
	movlw 0b10001000
	option

	; Init brightness
	clrf brightness
	movlw 16
	movwf brightdelay

	; Init PWM values
	clrf pwmperiod
	movlw 32
	movwf pwmcounter
loop:
	clrwdt

	; Set GP0 if pwmcounter - pwmperiod >= 0
	movf pwmperiod, W
	subwf pwmcounter, W
	btfsc CARRY
	bsf GP0
	btfss CARRY
	bcf GP0

	; Decrease PWM value and keep going if not zero
	decfsz pwmcounter
	goto waittmr

	; Reset PWM value
	movlw 32
	movwf pwmcounter

	; Increment brightness delay, and keep going if not yet zero
	decfsz brightdelay
	goto waittmr

	; Reset brightness delay
	movlw 16
	movwf brightdelay

	; Increment brightness with wrap around
	movlw 1
	addwf brightness, W
	andlw 0x7F
	movwf brightness

	; Get sin(brightness)
	; Since sin is symmetrical, calculate sin(x) for x in [64, 128] by
	; inversion
	btfsc brightness, 6
	xorlw 0x7F
	call sintable

	; Store value
	movwf pwmperiod

	; Wait for timer 0 to wrap around
waittmr:
	movf TMR0, W
	movwf tmrstartval
waittmrwrap:
	movf tmrstartval, W
	subwf TMR0, W
	btfsc CARRY
	goto waittmrwrap

	; Run loop again
	goto loop
end start
