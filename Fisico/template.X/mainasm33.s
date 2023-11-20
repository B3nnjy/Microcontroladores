/*
 * File:   template.s
 * Author: Baltazar Jim�nez 
 *
 * Created on March 13th, 2023
 */

    .include "p33FJ128MC802.inc"
    
    ;User program memory is not write-protected
    #pragma config __FGS, GWRP_OFF & GSS_OFF & GCP_OFF
    
    ;Internal Fast RC (FRC)
    ;Start-up device with user-selected oscillator source
    #pragma config __FOSCSEL, FNOSC_FRC & IESO_ON
    
    ;Both Clock Switching and Fail-Safe Clock Monitor are disabled
    ;XT mode is a medium-gain, medium-frequency mode that is used to work with crystal
    ;frequencies of 3.5-10 MHz
  ; #pragma config __FOSC, FCKSM_CSDCMD & POSCMD_XT
    
    ;Watchdog timer enabled/disabled by user software
    #pragma config __FWDT, FWDTEN_OFF
    
    ;POR Timer Value
    #pragma config __FPOR, FPWRT_PWR128
   
    ; Communicate on PGC1/EMUC1 and PGD1/EMUD1
    ; JTAG is Disabled
    #pragma config __FICD, ICS_PGD1 & JTAGEN_OFF


;..............................................................................
;Program Specific Constants (literals used in code)
;..............................................................................

    .equ SAMPLES, 64         ;Number of samples



;..............................................................................
;Global Declarations:
;..............................................................................

    .global _wreg_init       ;Provide global scope to _wreg_init routine
                                 ;In order to call this routine from a C file,
                                 ;place "wreg_init" in an "extern" declaration
                                 ;in the C file.

    .global __reset          ;The label for the first line of code.
    
    .global __U1RXInterrupt	;Interrupcion de recepcion de UART

;..............................................................................
;Constants stored in Program space
;..............................................................................

    .section .myconstbuffer, code
    .palign 2                ;Align next word stored in Program space to an
                                 ;address that is a multiple of 2
ps_coeff:
    .hword   0x0002, 0x0003, 0x0005, 0x000A




;..............................................................................
;Uninitialized variables in X-space in data memory
;..............................................................................

    .section .xbss, bss, xmemory
x_input: .space 2*SAMPLES        ;Allocating space (in bytes) to variable.



;..............................................................................
;Uninitialized variables in Y-space in data memory
;..............................................................................

    .section .ybss, bss, ymemory
y_input:  .space 2*SAMPLES




;..............................................................................
;Uninitialized variables in Near data memory (Lower 8Kb of RAM)
;..............................................................................

    .section .nbss, bss, near
var1:     .space 2               ;Example of allocating 1 word of space for
                                 ;variable "var1".




;..............................................................................
;Code Section in Program Memory
;..............................................................................

.text                             ;Start of Code section
__reset:
    MOV #__SP_init, W15       ;Initalize the Stack Pointer
    MOV #__SPLIM_init, W0     ;Initialize the Stack Pointer Limit Register
    MOV W0, SPLIM
    NOP                       ;Add NOP to follow SPLIM initialization

    CALL _wreg_init           ;Call _wreg_init subroutine
                                  ;Optionally use RCALL instead of CALL




        ;<<insert more user code here>>


    SETM    AD1PCFGL  ;PORTB AS DIGITAL
    
    MOV #0x0000, W1
    MOV W1, TRISB	;Configurar PORTB como salida
    
    ;PORTB15 entrada
    BSET TRISB, #TRISB15    
    
    MOV	    #400,   W9	    ;PARAMETER FOR DELAY_ms(w9)
    
    ;Mapeo de puerto RX
    CALL MAPEAR_PIN_UART_RX
    
    ;Configuracion de la interrupcion de UART
    CALL INTERRUPT_UART_CONF
    
    ;Configuracion de UART
    CALL UART_CONF
    
    CALL FILLING_LINE

done:
    MOV W8, PORTB
    ;MODO INACTIVO
    PWRSAV #IDLE_MODE	  
BRA     done              ;Place holder for last line of executed code
    
    
    
;******************************************************************************
;DESCRIPTION:	SECTION OF CODE FOR A 1s DELAY
;PARAMETER: 	NINGUNO
;RETURN: 	NINGUNO
;******************************************************************************		    
    
;FOSC = 7.3725 MHz -> this is the internal clock source (FRC) and we are using it. 
    ;If you use another clock source you have to modify "config __FOSC" section 
    
;FCY = FOSC/2 = 3686250 cycles p/sec.
;T(FCY) = 271.278 ns. This is the time for an internal instruction cycle clock (FCY).	

;"CYCLE1" will repeat 2^16 times = 65536 times
;DEC(1) + BRA(2) = 3 pulses in total
;(BRA uses 2 CLK pulses when it jumps and just one if it does not)

;65536 * 3 cycles * 271 ns = 53.28 ms
;Thus, "CYCLE1" must be repeated 56 times to delay 1s
DELAY_1s:
    PUSH	    W0
    PUSH	    W1	
	
    MOV	    #19,	    W1
CYCLE2:	
    CLR	    W0
	
CYCLE1:		
    DEC	    W0,		    W0
    BRA	    NZ,		    CYCLE1
	
    DEC	    W1,		    W1
    BRA	    NZ,		    CYCLE2
	
    POP	    W1
    POP	    W0
    RETURN	
    
    
    DELAY_1ms:
    PUSH    W0
    PUSH    W9	    ;ARGUMENT: HOW MANY MILISECONDS
    DEC	    W9,	    W9
    DO	    W9,	    B2
	MOV	    #3682,	W0	;1ms / 271ns = 3686 pulses - some of them
	REPEAT  W0			;for the call and return.
	NOP
    B2: NOP
    
    POP	    W9
    POP	    W0
    RETURN   
    
FILLING_LINE:
    PUSH W0
    PUSH W2
    
    MOV #7, W2
    
    CLR W0
    CALL DELAY_1s
    MOV W0, PORTB
    
    MOV #1, W0
    CALL DELAY_1ms
    MOV W0, PORTB
    
    DO W2, B3
	CALL DELAY_1ms 
	MUL.UU W0, #2, W0
	ADD #1, W0
	MOV W0, PORTB
    B3: NOP
    
    POP W2
    POP W0
    RETURN
    
    
MAPEAR_PIN_UART_RX:
    PUSH W0
    
    ;Mapear UART RX al pin RP15
    MOV #0x000F, W0
    MOV W0, RPINR18
    
    POP W0
    RETURN
    
UART_CONF:
    PUSH W0
    
    CLR U1MODE
    
    ;---Configurar cantidad de BAUDIOS---
    ;FCY = FCY = 3686250Hz = 3686250 ciclo/segundo
    ;Baudios deseados = 9600
    ;UxBRG = (Fcy/Baud)/16
    ;UxBRG = ((3686250/9600)/16)-1 = 22.9990234375 = 23
    ;Baud rate = 3686250/(16*(UxBRG + 1)) 
    ;Baud rate = 3686250/(16*(23 + 1)) = 9,599.6093
    
    MOV #23, W0
    MOV W0, U1BRG
    
    ;Bits de datos y paridad (8 bits de datos y sin paridad)
    BCLR U1MODE, #PDSEL0
    BCLR U1MODE, #PDSEL1
    
    ;Numero de bits de parada
    BCLR U1MODE, #STSEL
    
    ;Low speed mode baud rate
    BCLR U1MODE, #BRGH	
    
    ;Habilitar UART
    BSET U1MODE, #UARTEN	
    
    ;La bandera de interrupcion se activa cuando un caracter es recibido
    BCLR U1STA, #URXISEL1
    BCLR U1STA, #URXISEL0
    
    POP W0
    
    RETURN
    
INTERRUPT_UART_CONF:
    ;Interrupciones anidadas deshabilitadas
    BSET INTCON1, #NSTDIS
    
    ;Nivel de prioridad 100
    BSET IPC2, #U1RXIP2
    BCLR IPC2, #U1RXIP1
    BCLR IPC2, #U1RXIP0
    
    ;Limpiar la bandera de recepcion
    BCLR IFS0, #U1RXIF
    
    ;Habilitar la bandera de recepcion
    BSET IEC0, #U1RXIE
    
    RETURN
    
__U1RXInterrupt:
    ;Mueve el dato del buffer de recepcion a W8
    MOV U1RXREG, W8
    ;Limpiar la bandera de recepcion
    BCLR IFS0, #U1RXIF
    RETFIE



;..............................................................................
;Subroutine: Initialization of W registers to 0x0000
;..............................................................................

_wreg_init:
    CLR W0
    MOV W0, W14
    REPEAT #12
    MOV W0, [++W14]
    CLR W14
    RETURN




;--------End of All Code Sections ---------------------------------------------

.end                               ;End of program code in this file

    