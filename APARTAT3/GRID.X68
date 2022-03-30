; =============================================================================
; TITLE    : GRID MANAGEMENT
; AUTHOR   : ANTONI BURGUERA
; HISTORY  : 05-JULY-2021 - CREATION
; COMMENTS : * THERE ARE TWO MATRICES (GRDMATR0 AND GRDMATR1) AND TWO POINTERS
;              TO THESE MATRICES (GRDSRC AND GRDDST).
;
;            * THE MATRIX TO BE PLOTTED IS ALWAYS THE ONE POINTED BY GRDDST.
;
;            * THE MATRIX TO BE UPDATED BY THE MOUSE (GRDMUPD) IS ALWAYS THE
;              ONE POINTED BY GRDDST.
;
;            * THE RULES-UPDATE (GRDRUPD) SWITCHES THE POINTERS AND THEN READS
;              THE NEW SOURCE MATRIX (GRDSRC) TO DETERMINE THE NUMBER OF
;              NEIGHBORS. THE RESULTING CELL VALUE IS WRITTEN TO THE DESTINA-
;              TION MATRIX, POINTED BY GRDDST.
; =============================================================================

; -----------------------------------------------------------------------------
GRDINIT
; INITIALIZE THE GRID AS FOLLOWS:
; * POINTS THE SOURCE GRID POINTER TO GRDMATR0.
; * POINTS THE DESTINATION GRID POINTER TO GRDMATR1.
; * RESETS THE COUNTERS (GRDNPLR1, GRDNPLR2, GRDNGEN).
; * FILLS THE TWO MATRICES (GRDMATR0 AND GRDMATR1) WITH ZEROS.
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L A0/D0,-(A7)
            MOVE.L  #GRDMATR0,(GRDSRC)
            MOVE.L  #GRDMATR1,(GRDDST)
            CLR.W   (GRDNPLR1)
            CLR.W   (GRDNPLR2)
            CLR.W   (GRDNGEN)
            LEA     GRDMATR0,A0
            MOVE.W  #GRDWIDTH*GRDHEIGH*2-1,D0
.LOOP       CLR.B   (A0)+
            DBRA.W  D0,.LOOP
            MOVEM.L (A7)+,A0/D0
            RTS

; -----------------------------------------------------------------------------
GRDMUPD
; GRID UPDATE USING MOUSE. THE INTERFACE IS AS FOLLOWS:
; * IF MOUSE IS NOT PRESSED OR IS OUTSIDE THE PLOTTED GRID, DOES NOTHING.
; * IF LEFT MOUSE BUTTON IS PRESSED INSIDE THE GRID:
;   - A PLAYER 1 (VALUE=1) CELL IS CREATED AT THE MOUSE POSITION IF THE MOUSE
;     IS ON THE LEFT HALF OF THE GRID.
;   - A PLAYER 2 (VALUE=2) CELL IS CREATED AT THE MOUSE POSITION IF THE MOUSE
;     IS ON THE RIGHT HALF OF THE GRID.
; * IF RIGHT MOUSE BUTTON IS PRESSED INSIDE THE GRID, THE CELL WHERE THE MOUSE
;   IS IS CLEARED (VALUE=0).
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------

            MOVEM.L  D0-D4/A0,-(A7)
            
            ; * CHECK IF MOUSE IS NOT PRESSED OR IS OUTSIDE THE PLOTTED GRID, DOES NOTHING. 
            BTST.B #MOUBITRT,(MOUVAL) ;miramos click izquierdo
            BNE .PRESSED
            BTST.B #MOUBITLF,(MOUVAL) ;miramos click derecho
            BNE .PRESSED
            BRA .OUTNTPRS             ;NOT PRESSED
.PRESSED
            MOVE.L (GRDDST), A0
            ;calculamos las 4 ecucaciones que definen la GRID
            ; LeftX=XPOSGRID , RX = XPOS_TOPLEFT_GRID+WIDTH-1 , UY=YPOS_TOPLEFT_GRID , LowY= YPOS_TOPLEFT_GRID+HEIGTH-1
            MOVE.W #GRDXOFF,D0              ;D0 <- LeftX
            MOVE.W #GRDPXWID-1,D2
            ADD.W D0,D2                     ;D2 <- RX
            
            MOVE.W #GRDYOFF,D1              ;D1 <- UY            
            MOVE.W #GRDPXHEI-1,D3
            ADD.W D1,D3                     ;D3 <- LowY
            
            ;si MOUX no esta en el intervalo (D0,D2) esta fuera del grid 
            CMP.W (MOUX),D0
            BPL .OUTNTPRS
            CMP.W (MOUX),D2
            BMI .OUTNTPRS
            ;si MOUY no esta en el intervalo (D1,D3) esta fuera del grid
            CMP.W (MOUY),D1
            BPL .OUTNTPRS
            CMP.W (MOUY),D3
            BMI .OUTNTPRS
            ;MOUpos esta dentro del grid y pasamos de coordenadas del raton a coord de matriz (video)
            MOVE.W (MOUX),D3
            MOVE.W (MOUY),D4
            SUB.W #GRDXOFF,D3               ;Xm - Xg
            SUB.W #GRDYOFF,D4               ;Ym - Yg
            DIVS.W #GRDSZCEL,D3             ;columna
            DIVS.W #GRDSZCEL,D4             ;fila
            ;convertimos las coordenadas(fila,columna) en posición  
            ;ej (0,0) es la pos 0 ,si nos desplazamos una columna estaremos en la pos 1 etc..
            ;la formula es COL+(fila * numColumnasGrid) <=> D3 + (D4*GRDWIDTH)
            MULU.W #GRDWIDTH,D4
            ADD.W D3,D4 
            ADD.W D4,A0                     ;sumamos la posicion a la pos de Memoria de la primera celda del grid
            BTST.B #MOUBITRT,(MOUVAL)       ;miramos si el pulsado es el click derecho
            BNE .CLEAR
            CMP.W #GRDWIDTH/2,D3            ;miramos en que lado del grid esta
            BGE .P2
            BRA .P1
            
            
.P1         MOVE.B #1,(A0)
            BRA .OUTNTPRS
        
.P2         MOVE.B #2,(A0)
            BRA .OUTNTPRS
     
.CLEAR      MOVE.B #0,(A0)
            BRA .OUTNTPRS
            




.OUTNTPRS   MOVEM.L (A7)+,D0-D4/A0

            RTS
; -----------------------------------------------------------------------------
GRDRUPD
; UPDATES THE GRID ACCORDING TO 2-PLAYER GAME OF LIFE RULES AS FOLLOWS:
; * ADDS 1 TO THE NUMBER OF GENERATIONS (GRDNGEN)
; * SWITCHES THE MATRIX POINTERS (GRDDST AND GRDSRC).
; * CHECKS THE NEIGHBORS USING THE NEW SOURCE MATRIX (POINTER BY GRDDSRC)
; * THE RESULTS OF APPLYING THE RULES ARE WRITTEN INTO THE NEW DESTINATION
;   MATRIX (POINTED BY GRDDST).
; * THE RULES ARE THE FOLLOWING, WHERE P1 AND P2 ARE 1 AND 2 RESPECTIVELY,
;   DEAD CELLS ARE REPRESENTED BY 0 AND NP1 AND NP2 DENOTE THE NUMBER OF
;   PLAYER 1 AND PLAYER 2 NEIGHBORS RESPECTIVELY:
;   + SURVIVAL RULES
;     - IF CELL IS P1 AND NP1-NP2 IS 2 OR 3 -> NEW VALUE IS P1
;     - IF CELL IS P1 AND NP1-NP2 IS 1 AND NP1>=2 -> NEW VALUE IS P1
;     - OTHERWISE -> NEW VALUE IS 0
;     - IF CELL IS P2 AND NP2-NP1 IS 2 OR 3 -> NEW VALUE IS P2
;     - IF CELL IS P2 AND NP2-NP1 IS 1 AND NP2>=2 -> NEW VALUE IS P2
;     - OTHERWISE -> NEW VALUE IS 0
;   + BIRTH RULES
;     - THE CELL HAS EXACTLY THREE P1 NEIGHBOURS AND THE NUMBER
;       OF P2 NEIGHBOURS IS DIFFERENT FROM THREE. IN THIS CASE A
;       P1 TOKEN IS BORN IN THE CELL.
;     - THE CELL HAS EXACTLY THREE P2 NEIGHBOURS AND THE NUMBER
;       OF P1 NEIGHBOURS IS DIFFERENT FROM THREE. IN THIS CASE A
;       P2 TOKEN IS BORN IN THE CELL.
;     - THE CELL HAS EXACTLY THREE WHITE AND THREE BLACK NEIGHBOURS.
;       IN THIS CASE AN UNBIASED COIN DETERMINES WHETHER A WHITE OR
;       BLACK TOKEN IS BORN IN THE CELL.
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------

; TODO : PLACE YOUR CODE HERE
            MOVEM.L D0-D5/A0-A2,-(A7)
            ; * ADDS 1 TO THE NUMBER OF GENERATIONS (GRDNGEN)
            ADDQ.W  #1,(GRDNGEN)
            ; * SWITCHES THE MATRIX POINTERS (GRDDST AND GRDSRC).            
            MOVE.L (GRDSRC), A0
            MOVE.L (GRDDST), A1
            MOVE.L A1,(GRDSRC)
            MOVE.L A0,(GRDDST)
            MOVE.L A1,A2 ;(A1,A2= (GRDSRC),A0(GRDDST))
            ; * CHECKS THE NEIGHBORS USING THE NEW SOURCE MATRIX (POINTER BY GRDDSRC)
            ;bucle que recorre todas las casillas del grid src
            ;la grid tiene (GRDWIDTH * GRDHEIGH) casillas <=>(2^6 * 2^5)
            CLR.W  D0                   ;D0 iterador fila
.FOR1       ;FOR1------------------
            CLR.W  D1                   ;reset D1 iterador COLUMNA a 0
.FOR2       ;FOR2--------
           
            JSR GRDOBTN
            
            ;ENDFOR2-----
            ADD.W #1,D1
            CMP.W #GRDWIDTH,D1
            BNE   .FOR2
            ;ENDFOR1------------------
            ADD.W #1,D0
            CMP.W #GRDHEIGH,D0
            BNE   .FOR1
            
            MOVEM.L (A7)+,D0-D5/A0-A2
            
            RTS
;------------------------------------------------------------------------------
GRDOBTN
; OBTIENE LOS VECINOS DE LA CELDA EN CUESTION ,CALCULA LOS P1 Y P2 ,APLICA LAS REGLAS
; INPUT     : A0 = GRDDST
;             A1 = GRDSRC
;             D0 = FILA
;             D1 = COLUMNA
; OUTPUT    : NONE

; MODIFIES  : NONE
;------------------------------------------------------------------------------
            MOVEM.L D0-D6,-(A7)

            CLR.W  D2                   ;reset D2 num P1=0
            CLR.W  D3                   ;reset D3 num P2=0
            
            ;UP
            SUB.W   #1,D0                   ;Subo fila
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;UPLEFT  
            SUB.W   #1,D1                   ;mover Izqierda
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;UPRIGHT
            ADD.W   #2,D1                   ;mover 2 veces derecha
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;RIGHT
            ADD.W   #1,D0                   ;bajar fila
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;LEFT
            SUB.W   #2,D1                   ;mover 2 veces izquierda
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;DOWNLEFT
            ADD.W   #1,D0                   ;bajar fila
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;DOWN
            ADD.W   #1,D1                   ;mover derecha
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;DOWNRIGHT
            ADD.W   #1,D1                   ;mover derecha
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            
            ;APLICAR LAS NORMAS EN FUNCION DEL VALOR DE LA CASILLA(D2 num P1,D3 num P2)
            ;Comprobamos el valor de la celda
            CMP.B   #0,(A1)                 
            BEQ     .BRULES
            CMP.B   #1,(A1)                 
            BEQ     .PLYR1
            BRA     .PLYR2     
            
.PLYR1      
            ;+ SURVIVAL RULES P1 (D2=NP1 , D3=NP2)
            MOVE.W D2,D4                    ;aux NP1
            SUB.W D3,D4                     ;calculamos NP1-NP2 (D2=NP1 , D3=NP2 ,D4=NP1-NP2)
            ;- IF CELL IS P1 AND NP1-NP2 IS 2 OR 3 -> NEW VALUE IS P1
            CMP.W   #2,D4
            BEQ     .SETP1
            CMP.W   #3,D4
            BEQ     .SETP1
            ;- IF CELL IS P1 AND NP1-NP2 IS 1 AND NP1>=2 -> NEW VALUE IS P1
            CMP.W   #1,D4
            BEQ     .SEG
            BRA .SET0
.SEG
            CMP.W   #2,D2
            BEQ .SETP1
            BPL .SETP1
            ;- OTHERWISE -> NEW VALUE IS 0
            BRA     .SET0

.PLYR2
            ;+ SURVIVAL RULES P2
            MOVE.W D3,D4                    ;aux NP2
            SUB.W D2,D4                     ;calculamos NP2-NP1 (D2=NP1 , D3=NP2 ,D4=NP2-NP1)
            ;- IF CELL IS P2 AND NP2-NP1 IS 2 OR 3 -> NEW VALUE IS P2
            CMP.W   #2,D4
            BEQ     .SETP2
            CMP.W   #3,D4
            BEQ     .SETP2
            ;- IF CELL IS P2 AND NP2-NP1 IS 1 AND NP2>=2 -> NEW VALUE IS P2
            CMP.W   #1,D4
            BEQ     .SEG2
            BRA .SET0
.SEG2
            CMP.W   #2,D3
            BEQ .SETP2
            BPL .SETP2
            ;- OTHERWISE -> NEW VALUE IS 0
            BRA     .SET0

     
.BRULES     ;   + BIRTH RULES
            ;     - THE CELL HAS EXACTLY THREE P1 NEIGHBOURS AND THE NUMBER
            ;       OF P2 NEIGHBOURS IS DIFFERENT FROM THREE. IN THIS CASE A
            ;       P1 TOKEN IS BORN IN THE CELL.
            CMP.W   #3,D2
            BNE     .BRULE1
            CMP.W   #3,D3
            BEQ     .BRULE2
            BRA     .SETP1     
.BRULE1            ;     - THE CELL HAS EXACTLY THREE P2 NEIGHBOURS AND THE NUMBER
            ;       OF P1 NEIGHBOURS IS DIFFERENT FROM THREE. IN THIS CASE A
            ;       P2 TOKEN IS BORN IN THE CELL.
            CMP.W   #3,D3
            BNE     .SET0
            BRA     .SETP2
            
.BRULE2            ;     - THE CELL HAS EXACTLY THREE WHITE AND THREE BLACK NEIGHBOURS.
            ;       IN THIS CASE AN UNBIASED COIN DETERMINES WHETHER A WHITE OR
            ;       BLACK TOKEN IS BORN IN THE CELL.
            BRA     .RANDOM

             
.SETP1      MOVE.B #1,(A0)+                 ;ponemos un 1 en la matriz de destino e iteramos
            ADD.W #1,A1                     ;iteramos una casilla en el puntero a la matriz src
            BRA     .NONE2

.SETP2      MOVE.B #2,(A0)+                 ;ponemos un 2 en la matriz de destino e iteramos
            ADD.W #1,A1                     ;iteramos una casilla en el puntero a la matriz src

            BRA     .NONE2

.SET0       MOVE.B #0,(A0)+                 ;ponemos un 0 en la matriz de destino e iteramos
            ADD.W #1,A1                     ;iteramos una casilla en el puntero a la matriz src
            BRA .NONE2

.RANDOM      MOVE.W D1,D5
            JSR UTLRAND
            MOVE.B D1,(A0)+
            ADD.W #1,A1                     ;iteramos una casilla en el puntero a la matriz src
            MOVE.W D5,D1


.NONE2            
            MOVEM.L (A7)+,D0-D6
            RTS

;------------------------------------------------------------------------------
CNTPLY
; OBTIENE LOS VECINOS DE LA CELDA EN CUESTION ,CALCULA LOS P1 Y P2 ,APLICA LAS REGLAS
; INPUT     : A1 = GRDSRC
;             D0 = FILA
;             D1 = COLUMNA
;             D2 = CURRENT P1 NUMBER
;             D3 = CURRENT P2 NUMBER
;
; OUTPUT    : D2 = CURRENT P1 NUMBER
;             D3 = CURRENT P2 NUMBER
; MODIFIES  : D2,D3
;              
;------------------------------------------------------------------------------
            MOVEM.L D0-D1/A2,-(A7)
            ANDI.W #GRDMSWID,D1 ;columna
            ANDI.W #GRDMSHEI,D0 ;fila
            ;segun la formula posicionEnVectorMemoria = columna + fila * NumFilas
            MULU.W  #GRDWIDTH,D0
            ADD.W   D1,D0                   ;D0 = columna + fila * NumFilas
            ADD.W   D0,A2
            ;Comprobamos el valor de la celda
            CMP.B   #1,(A2)                 
            BEQ     .ESP1
            CMP.B   #2,(A2)                 
            BEQ     .ESP2
            BRA     .FIN
.ESP1       ADDQ.W  #1,D2
            BRA     .FIN
.ESP2       ADDQ.W  #1,D3
.FIN        MOVEM.L (A7)+,D0-D1/A2
            RTS
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
GRDSAVE
; SAVES THE GRID INTO A FILE IN CSV FORMAT
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            MOVE.L  #1,D1                   ; DISPLAY SAVE DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #52,D0                  ; CREATE NEW FILE
            TRAP    #15
            TST.W   D0                      ; CHECK CREATION ERROR
            BNE     .END                    ; DO NOTHING MORE IF ERROR
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; A0: POINTER TO THE DATA TO WRITE
            MOVE.W  #GRDHEIGH-1,D3          ; D3: NUMBER OF ROWS - 1
.LOOPY      MOVE.W  #GRDWIDTH-1,D2          ; D2: NUMBER OF COLUMNS - 1
.LOOP       MOVE.B  #'0',D0                 ; ADD CHAR '0' AND THE CELL VALUE
            ADD.B   (A0)+,D0
            MOVE.B  D0, (A6)+               ; STORE IT IN THE BUFFER
            MOVE.B  #',',(A6)+              ; NOW PUT THE COMMA
            DBRA.W  D2,.LOOP
            MOVE.B  #$0D,-1(A6)             ; STORE CARRIAGE RETURN (REMOVE ',')
            MOVE.B  #$0A,(A6)               ; STORE LINE FEED
            MOVE.B  #54,D0                  ; WRITE TO FILE TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO WRITE
            TRAP    #15                     ; WRITE (A1 IS ALREADY THERE)
            MOVE.L  A1,A6                   ; GO BACK TO THE BUFFER START
            DBRA.W  D3,.LOOPY
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO SAVE',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0

; -----------------------------------------------------------------------------
GRDLOAD
; LOADS THE GRID FROM A CSV FORMATTED FILE
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            CLR.W (GRDNPLR1)
            CLR.W (GRDNPLR2)
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            CLR.L   D1                      ; DISPLAY LOAD DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #51,D0                  ; OPEN EXISTING FILE
            TRAP    #15
            TST.W   D0                      ; CHECK ERRORS
            BNE     .END                    ; IF ERRORS, DO NOTHING MORE
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; POINTER TO STORE PROCESS. DATA
            MOVE.W  #GRDHEIGH-1,D3
.LOOP       MOVE.L  A6,A1
            MOVE.B  #53,D0                  ; READ DATA TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO READ
            TRAP    #15                     ; READ THE DATA
            MOVE.W  #GRDWIDTH-1,D2
.COPY       MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            MOVE.B  D0,(A0)+                ; STORE DATA
            ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            DBRA.W  D3,.LOOP
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO LOAD',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0

; -----------------------------------------------------------------------------
GRDLLEFT
; LOADS THE LEFT PART OF THE GRID FROM A CSV FORMATTED FILE
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; NOTE     : ALL THE ACTIVE CELLS ARE STORED AS PLAYER 1 INDEPENDLY OF THEIR
;            ACTUAL VALUE.
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            CLR.W (GRDNPLR1)
            CLR.W (GRDNPLR2)
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            CLR.L   D1                      ; DISPLAY LOAD DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #51,D0                  ; OPEN EXISTING FILE
            TRAP    #15
            TST.W   D0                      ; CHECK ERRORS
            BNE     .END                    ; IF ERRORS, DO NOTHING MORE
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; POINTER TO STORE PROCESS. DATA
            MOVE.W  #GRDHEIGH-1,D3
.LOOP       MOVE.L  A6,A1
            MOVE.B  #53,D0                  ; READ DATA TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO READ
            TRAP    #15                     ; READ THE DATA
            MOVE.W  #(GRDWIDTH/2)-1,D2
.COPY       MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            CMP.B   #0,D0
            BNE     .PONERP1
            MOVE.B  #0,(A0)+
            BRA     .LISTO
.PONERP1    MOVE.B  #1,(A0)+            
 
.LISTO      ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            ADD.W   #(GRDWIDTH/2),A0        ;SALTAMOS LA MITAD DE LA FILA
            DBRA.W  D3,.LOOP
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO LOAD',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0

            

; -----------------------------------------------------------------------------
GRDLRGT
; LOADS THE RIGHT PART OF THE GRID FROM A CSV FORMATTED FILE
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; NOTE     : THE LOCAL BUFFER SIZE MUST BE MAX(512,2*GRDWIDTH+1). PLEASE CHANGE
;            IT ACCORDINGLY IF GRDWIDTH*2+1 IS LARGER THAN 512.
; NOTE     : ALL THE ACTIVE CELLS ARE STORED AS PLAYER 2 INDEPENDLY OF THEIR
;            ACTUAL VALUE.
; -----------------------------------------------------------------------------
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            CLR.W (GRDNPLR1)
            CLR.W (GRDNPLR2)
            MOVE.B  #50,D0                  ; CLOSE ALL FILES (RECOMMENDED)
            TRAP    #15
            SUB.L   #512,A7                 ; ROW BUFFER IN LOCAL MEMORY
            MOVE.B  #58,D0                  ; SHOW FILE DIALOG TASK
            CLR.L   D1                      ; DISPLAY LOAD DIALOG
            LEA     .MSG,A1                 ; STANDARD MESSAGE
            LEA     .FILTER,A2              ; NO FILTER
            MOVE.L  A7,A3                   ; FILE NAME BUFFER
            CLR.W   (A3)                    ; ENSURE THERE IS NO STRING
            TRAP    #15
            TST.B   D1
            BEQ     .END                    ; IF CANCELLED, DO NOTHING
            MOVE.L  A3,A1                   ; PLACE THE FILENAME INTO A1
            MOVE.B  #51,D0                  ; OPEN EXISTING FILE
            TRAP    #15
            TST.W   D0                      ; CHECK ERRORS
            BNE     .END                    ; IF ERRORS, DO NOTHING MORE
            MOVE.L  A7,A6                   ; PUT A6 INTO START OF BUFFER
            MOVE.L  A7,A1                   ; PUT A1 INTO START OF BUFFER
            MOVE.L  (GRDDST), A0            ; POINTER TO STORE PROCESS. DATA
            MOVE.W  #GRDHEIGH-1,D3
.LOOP       MOVE.L  A6,A1
            MOVE.B  #53,D0                  ; READ DATA TASK NUMBER
            MOVE.L  #GRDWIDTH*2+1,D2        ; NUMBER OF BYTES TO READ
            TRAP    #15                     ; READ THE DATA
            MOVE.W  #(GRDWIDTH/2)-1,D2
            ADD.W   #(GRDWIDTH/2),A0        ;SALTAMOS LA MITAD DE LA FILA
.COPY       MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            CMP.B   #0,D0
            BNE     .PONERP2
            MOVE.B  #0,(A0)+
            BRA     .LISTO
.PONERP2    MOVE.B  #2,(A0)+            
 
.LISTO      ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            DBRA.W  D3,.LOOP
            MOVE.B  #56,D0                  ; CLOSE FILE
            TRAP    #15
.END        ADD.L   #512,A7                 ; RESTORE STACK
            MOVEM.L (A7)+,D0-D7/A0-A6       ; TO BE OPTIMIZED
            RTS
.MSG        DC.B    'SELECT A CSV FILE TO LOAD',0
.FILTER     DC.B    '*.CSV',0
            DS.W    0

; -----------------------------------------------------------------------------
GRDPLOT
; PLOTS THE GRID
; INPUT    : NONE
; OUTPUT   : NONE
; MODIFIES : NONE
; -----------------------------------------------------------------------------
            MOVEM.L D0-D6/A0,-(A7)
            ;DIBUJAMOS ZONA MARCADORES ( P1 SCORE ---- GENERATIONS ---- P2 SCORE )
            ;P1 SCORE            
            ;sabiendo que D1.W(xxxx xxxx yyyy yyyy)
            MOVE.B  #11,D0                  ;Task 11 para situar el cursor
            MOVE.W #(GRDSCP1X<<8|GRDSCP1Y),D1
            TRAP #15                        ;cursor posicionado
            ;seleccionamos el fill color
            MOVE.B  #81,D0                  ;Task 81 para seleccionar el color de subrayado
            ;sabiendo que D1.L($00BBGGRR)
            MOVE.L  #GRDCOLP1,D1
            TRAP    #15
            ;seleccionamos el draw color
            MOVE.B  #80,D0                  ;Task 80 para seleccionar el color de trazado
            MOVE.L  #CLRWHITE,D1
            TRAP    #15
            ;Escribimos el numero en la posicion
            MOVE.B  #20,D0                  ;Task 20 para escribir signed number
            ;D1.L el numero en decimal  y D2.B el ancho que ocupara
            CLR.L   D1
            MOVE.W  (GRDNPLR1),D1
            MOVE.B  #5,D2                   ;El valor de ancho ha sido calculado euristicamente           
            TRAP    #15
            
            ;GEN            
            ;sabiendo que D1.W(xxxx xxxx yyyy yyyy)
            MOVE.B  #11,D0                  ;Task 11 para situar el cursor
            MOVE.W #(GRDSCNGX<<8|GRDSCNGY),D1
            TRAP #15                        ;cursor posicionado
            ;seleccionamos el fill color
            MOVE.B  #81,D0                  ;Task 81 para seleccionar el color de subrayado
            ;sabiendo que D1.L($00BBGGRR)
            MOVE.L  #CLRLTGRN,D1
            TRAP    #15
            ;seleccionamos el draw color
            MOVE.B  #80,D0                  ;Task 80 para seleccionar el color de trazado
            MOVE.L  #CLRWHITE,D1
            TRAP    #15
            ;Escribimos el numero en la posicion
            MOVE.B  #20,D0                  ;Task 20 para escribir signed number
            ;D1.L el numero en decimal  y D2.B el ancho que ocupara
            CLR.L   D1
            MOVE.W  (GRDNGEN),D1
            MOVE.B  #5,D2                   ;El valor de ancho ha sido calculado heuristicamente           
            TRAP    #15
            
            
            ;P2 SCORE            
            ;sabiendo que D1.W(xxxx xxxx yyyy yyyy)
            MOVE.B  #11,D0                  ;Task 11 para situar el cursor
            MOVE.W #(GRDSCP2X<<8|GRDSCP2Y),D1
            TRAP #15                        ;cursor posicionado
            ;seleccionamos el fill color
            MOVE.B  #81,D0                  ;Task 81 para seleccionar el color de subrayado
            ;sabiendo que D1.L($00BBGGRR)
            MOVE.L  #GRDCOLP2,D1
            TRAP    #15
            ;seleccionamos el draw color
            MOVE.B  #80,D0                  ;Task 80 para seleccionar el color de trazado
            MOVE.L  #CLRWHITE,D1
            TRAP    #15
            ;Escribimos el numero en la posicion
            MOVE.B  #20,D0                  ;Task 20 para escribir signed number
            ;D1.L el numero en decimal  y D2.B el ancho que ocupara
            CLR.L   D1
            MOVE.W  (GRDNPLR2),D1
            MOVE.B  #5,D2                   ;El valor de ancho ha sido calculado euristicamente           
            TRAP    #15
            
            ;DIBUJAMOS LA GRID
            ;se pintara celda a celda , cada celda es un rectangulo donde su color de fondo viene determinado por su valor
            MOVE.L (GRDDST), A0             ;se utilizará para iterar a traves de la matriz
            CLR.W   (GRDNPLR1)
            CLR.W   (GRDNPLR2)
            ;seleccionamos el draw color
            MOVE.B  #80,D0                  ;Task 80 para seleccionar el color de trazado
            MOVE.L  #CLRMDGRN,D1
            TRAP    #15
            ;ajustamos el grosor del pen
            MOVE.B  #93,D0 
            MOVE.B  #1,D1                   ;grosor calculado heuristicamente
            TRAP    #15

            CLR.W  D6                   ;D0 iterador fila
.FOR11       ;FOR1------------------
            CLR.W  D5                   ;reset D1 iterador COLUMNA a 0
.FOR22       ;FOR2--------
                 
            ;seleccionamos el fill color
            MOVE.B  #81,D0                  ;Task 81 para seleccionar el color de subrayado
            ;sabiendo que D1.L($00BBGGRR)
            CMP.B   #1,(A0)
            BEQ     .COLP1
            CMP.B   #2,(A0)
            BEQ     .COLP2
            MOVE.L  #CLRBLACK,D1
            BRA .ELEGIDO
.COLP1      MOVE.L  #GRDCOLP1,D1
            ADDQ.W #1,(GRDNPLR1)
            BRA .ELEGIDO
.COLP2      MOVE.L  #GRDCOLP2,D1
            ADDQ.W #1,(GRDNPLR2)
.ELEGIDO    TRAP    #15
            ;Dibujamos la celda
            MOVE.B  #87,D0                  ;Task 87 para dibujar rectangulo
            ;LX = D1.W, UY = D2.W, RX = D3.W, LY = D4.W 
            ;  X = xgrdoffset + Col*widthCelda  Y = ygrdoffset + Fila*heighCelda                        MOVE.W  D3,D5
            MOVE.W  D5,D1
            MOVE.W  D6,D2  
            MULU.W  #GRDSZCEL,D1
            ADD.W   #GRDXOFF,D1            ;LX
            MULU.W  #GRDSZCEL,D2
            ADD.W   #GRDYOFF,D2             ;UY
            MOVE.W  #GRDSZCEL,D3
            ADD.W   D1,D3                   ;LX+WIDTH = RX
            MOVE.W  #GRDSZCEL,D4
            ADD.W   D2,D4                   ;LX+WIDTH = RX
            TRAP    #15

            ;ENDFOR2-----
            ADD.W   #1,A0
            ADD.W   #1,D5
            CMP.W   #GRDWIDTH,D5
            BNE     .FOR22
            ;ENDFOR1------------------
            ADD.W   #1,D6
            CMP.W   #GRDHEIGH,D6
            BNE     .FOR11
            
            LEA .WINR,A1  ;ASTERISK STRING TO A1 
            MOVE.W (GRDNPLR2),D0
            CMP.W (GRDNPLR1),D0
            BGT .OP2 ;GRDNPLR2 > GRDNPLR1
            BLT .OP1 ;GRDNPLR2 < GRDNPLR1
            MOVE.W #1,D3 ;TO CHECK IF IT BRANCHED
            
.OP1        MOVE.B #81,D0
            MOVE.L #GRDCOLP1,D1
            TRAP #15

            MOVE.B #95,D0 ;PUTS ASTERISK ON TOP OF P1 SCORE
            MOVE.W #GRDSCP1X,D1
            MULU.W #CHRWIDTH,D1
            MOVE.W #GRDSCP1Y,D2
            MULU.W #CHRHEIGH,D2
            SUB.W #GRDSZCEL*2,D2
            TRAP #15
            
            CMP.W #1,D3
            BEQ .OP2
            BRA .END
       
.OP2        MOVE.B #81,D0
            MOVE.L #CLRLTRED,D1
            TRAP #15
            
            MOVE.B #95,D0 ;PUTS ASTERISK ON TOP OF P2 SCORE
            MOVE.W #GRDSCP2X,D1
            MULU.W #CHRWIDTH,D1
            MOVE.W #GRDSCP2Y,D2
            MULU.W #CHRHEIGH,D2
            SUB.W #GRDSZCEL*2,D2
            TRAP #15

.END                        
 
            MOVEM.L (A7)+,D0-D6/A0
            
            RTS
.WINR       DC.B    '*',0
            DS.W    0







































*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
