; =============================================================================
; TITLE    : BUTTON MANAGEMENT
; AUTHOR   : ANTONI BURGUERA
; HISTORY  : 05-JULY-2021 - CREATION
; COMMENTS : * A BUTTON IS DEFINED BY A STATIC DATA BLOCK (SDB), WHICH DOES NOT
;              CHANGE OVER TIME, AND A VARIABLE DATA BLOCK (VDB), THAT CAN
;              CHANGE OVER TIME. CHANGES IN THE VDB ARE PRODUCED WHEN CALLING
;              SUBROUTINE BTNUPD.
;
;            * THE BUTTON SDB (CAN BE IN ROM) HAS THE FOLLOWING FIELDS. THE
;              NUMBER DENOTES THE OFFSET WITH RESPECT TO THE SDB START:
;
;                +0  - WORD - YTOP COORDINATE (PIXELS)
;                +2  - WORD - XLEFT COORDINATE (PIXELS)
;                +4  - WORD - HEIGHT (PIXELS)
;                +6  - WORD - WIDTH (PIXELS)
;                +8  - LONG - CALLBACK POINTER
;                +12 - BYTE STRING - ZERO TERMINATED STRING. TEXT TO SHOW.
;
;            * THE BUTTON VDB (MUST BE IN RAM) IS:
;
;                +0 - LONG - POINTER TO THE STATIC DATABLOCK
;                +4 - BYTE - STATUS WITH FORMAT XXXXXCPI WHERE:
;                            - I (BIT 0) - 1=MOUSE INSIDE, 0=MOUSE OUTSIDE
;                            - P (BIT 1) - 1=MOUSE PRESSED INSIDE
;                                          0=MOUSE NOT PRESSED INSIDE
;                            - C (BIT 2) - 1=MOUSE CLICKED INSIDE
;                                          0=MOUSE NOT CLICKED INSIDE
;                            NOTE THAT IF I=0 THEN P=C=0, IF I=1 AND P=0
;                            THEN C=0.
; =============================================================================

; -----------------------------------------------------------------------------
BTNINIT
; INITIALIZES THE BUTTON BY:
;  * COPYING THE SDB POINTER INTO THE VDB.
;  * CLEARING THE STATUS BYTE.
; INPUT    : A0 - POINTER TO THE VARIABLE DATABLOCK
;            A1 - POINTER TO THE STATIC DATABLOCK
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------

; TODO : PLACE YOUR CODE HERE
            ;Guardamos los registros en la pila
            MOVEM.L A0-A1,-(A7) 
            ;* COPYING THE SDB POINTER INTO THE VDB.
            MOVE.L A1,(A0)+
            ;* CLEARING THE STATUS BYTE.
            CLR.B (A0)
            ;Restauramos los registros utilizados
            MOVEM.L (A7)+,A0-A1 
            RTS
     
; -----------------------------------------------------------------------------
BTNUPD
; UPDATES THE BUTTON VDB AND EXECUTES THE CALLBACK IF REQUIRED
; INPUT    : A0 - POINTER TO THE VARIABLE DATABLOCK
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------

; TODO : PLACE YOUR CODE HERE
            ;Guardamos registros en la pila
            MOVEM.L D1-D5/A0-A1,-(A7)   
            
            ;UPDATES THE BUTTON
            MOVE.L (A0),A1                  ;Obtenemos el puntero SDB
            ADDA.W #4,A0                    ;Aumentamos en 4 bytes A0                  
            MOVE.B (A0),D5                  ;Obtenemos el status (D5)
            MOVE.W (A1)+,D1                 ;UY (D1)
            MOVE.W (A1)+,D2                 ;LX (D2)
            MOVE.W (A1)+,D3                 
            ADD.W D1,D3                     ;LY (D3)
            MOVE.W (A1),D4
            ADD.W #2,A1
            MOVE.L (A1),A1                                  
            ADD.W D2,D4                     ;RX (D4)
            
            ;Comprobamos si el ratón está dentro del botón
            ;Eje horizontal del ratón
            CMP.W (MOUX),D2                 ;LEFT
            BPL .NOMOUIN
            CMP.W (MOUX),D4                 ;RIGHT
            BMI .NOMOUIN
            ;Eje vertical del ratón
            CMP.W (MOUY),D1                 ;TOP
            BPL .NOMOUIN
            CMP.W (MOUY),D3                 ;DOWN
            BMI .NOMOUIN
            ;Si se llega aquí, el ratón está dentro
            BSET #0,D5                      ;MOUSE INSIDE = 1
            
            ;Comprobamos si el ratón está pulsado 
            BTST.B #MOUBITLF,(MOUVAL)
            BEQ .MOUNOPR
.MOUPR:     
            BSET #1,D5                      ;MOUSE PRESSED=1
            BRA .ISCLCK
.MOUNOPR:   
            BCLR #1,D5                      ;MOUSE PRESSED=0
.ISCLCK:    
            BTST.B #MOUBITLF,(MOUEDGE)
            BEQ .NOTCLCK
.CLCK:      
            BSET #2,D5
            JSR (A1)                         ;REPRODUCIR SONIDO
            BRA .END  
.NOTCLCK:   
            BCLR #2,D5                      ;MOUSE CLICKED=0
            BRA .END
.NOMOUIN:   
            BCLR #0,D5                      ;MOUSE IN = 0
.END:       
            MOVE.B D5,(A0)
            ;Restauramos los registros utilizados
            MOVEM.L (A7)+,D1-D5/A0-A1
            RTS

; -----------------------------------------------------------------------------
BTNPLOT
; PLOTS THE BUTTON. A RECTANGLE IS DRAWN WITH THICKNESS BTNPENWD. THE CONTOUR
; COLOR IS BTNPENCL. THE FILL COLOR IS BLACK IF THE MOUSE IS NOT INSIDE,
; BTNSELCL IF THE MOUSE IS INSIDE BUT THE MOUSE BUTTON IS NOT PRESSED AND
; BTNPRSCL IF THE MOUSE BUTTON IS PRESSED INSIDE.
; INPUT    : A0 - POINTER TO THE VARIABLE DATABLOCK
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------

; TODO : PLACE YOUR CODE HERE
            ;Guardamos los registros en la pila
            MOVEM.L D0-D6/A0-A1,-(A7)
         
            MOVE.L (A0)+,A1      ;Obtenemos el puntero SDB  
            MOVE.B (A0),D6       ;Status (D6)
               
            ;BORDERS COLOR
            MOVE.B #80,D0
            MOVE.L #BTNPENCL,D1
            TRAP #15
                      
            ;WIDTH
            MOVE.B #93,D0
            MOVE.B #BTNPENWD,D1
            TRAP #15
        
            ;BACKGROUND COLOR
            MOVE.B #81,D0
            BTST #0,D6
            BNE .MOUSEIN
            MOVE.L #CLRBLACK,D1
            TRAP #15
            BRA .DRAWRL
            ;Si el mouse está en el botón          
.MOUSEIN:   
            BTST #1,D6
            BNE .MOUSEPRESS
            MOVE.L #BTNSELCL,D1
            TRAP #15
            BRA .DRAWRL
            ;Si el botón del mouse está apretado
.MOUSEPRESS: 
            MOVE.L #BTNPRSCL,D1
            TRAP #15
            
.DRAWRL:    
            ;Dibujamos el rectángulo del botón

            MOVE.B #87,D0                   
            ;UP Y
            MOVE.W (A1),D6                  
            MOVE.W (A1),D2
            ADD.W #2,A1
            ;LEFT X
            MOVE.W (A1),D5
            MOVE.W (A1),D1
            ADD.W #2,A1
            ;Guardamos altura y anchura
            MOVE.W A1,A0                    
            ;LOW Y
            ADD.W (A1),D6
            ADD.W #2,A1
            MOVE.W D6,D4
            ;RIGHT X
            ADD.W (A1),D5
            MOVE.W D5,D3
            TRAP #15                        ;Dibujamos el rectángulo 
            
            ;Dibujamos el texto del botón
            
            ADD.W #6,A1                     ;Apuntamos al texto del botón
            JSR UTLSTRLN                    ;Obtenemos la longitud de texto(D0)
            MOVE.W #CHRWIDTH,D2             ;Obtenemos el ancho del caracter
            ;ALTURA DEL STRING (D1) = Altura del char
            MOVE.W #CHRHEIGH,D1                        
            
            MOVE.W (A0),D4                  ;Alto rectángulo (D4)
            ADD.W #2,A0
            MOVE.W (A0),D3                  ;Ancho rectángulo (D3)
            
            SUB.W D3,D5                     ;LX (D5)
            SUB.W D4,D6                     ;UY (D6)        
            ;ANCHO DEL STRING (D2) = Ancho caracter (D2) * nº caracteres (D0)
            MULU.W D0,D2                    
            ;Obtención de las coordenadas del texto en el rectángulo    
            SUB.W D2,D3
            LSR.W #1,D3
            SUB.W D1,D4
            LSR.W #1,D4
            ADD.W D3,D5                     ;D5 = COORDENADA X  
            ADD.W D4,D6                     ;D6 = COORDENADA Y
            ;Guardamos la información y ejecutamos el TRAP
            MOVE.B #95,D0                   ;Task 95 (dibujar String)    
            MOVE.W D6,D2
            MOVE.W D5,D1  
            TRAP #15
            
                       
            ;Restauramos los registros
            MOVEM.L (A7)+,D0-D6/A0-A1
            RTS
            
            
         


















































*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
