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

; TODO : PLACE YOUR CODE HERE
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
            MOVE.L  (GRDSRC),A0
            MOVE.L  (GRDDST),A1
            MOVE.L  A0,(GRDDST)
            MOVE.L  A1,(GRDSRC)
            ; * CHECKS THE NEIGHBORS USING THE NEW SOURCE MATRIX (POINTER BY GRDDSRC)
            ;bucle que recorre todas las casillas del grid src
            ;la grid tiene (GRDWIDTH * GRDHEIGH) casillas <=>(2^6 * 2^5)
            CLR.W  #0,D0                   ;D0 iterador fila
.FOR1       ;FOR1------------------
            CLR.W  #0,D1                   ;reset D1 iterador COLUMNA a 0
.FOR2       ;FOR2--------
           
            JSR GRDOBTN
            
            ;ENDFOR2-----
            ADD.W #1,D1
            CMP.W #GRDWIDTH-1,D1
            BNE   .FOR2
            ;ENDFOR1------------------
            ADD.W #1,D0
            CMP.W #GRDHEIGH-1,D0
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
            MOVEM.L D0-D3/A0-A2,-(A7)

            CLR.W  #0,D2                   ;reset D2 num P1=0
            CLR.W  #0,D3                   ;reset D3 num P2=0
            
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
            SUB.W   #1,D0                   ;bajar fila
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;DOWN
            ADD.W   #1,D1                   ;mover derecha
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            ;DOWNRIGHT
            ADD.W   #1,D1                   ;mover derecha
            JSR     CNTPLY                  ;miramos el valor de la casilla P1,P2,0
            
            ;APLICAR LAS NORMAS EN FUNCION DEL VALOR DE LA CASILLA(D2 num P1,D3 num P2)
            
            MOVEM.L (A7)+,D0-D3/A0-A2
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
            MOVEM.L D0-D1/A1,-(A7)

            ;segun la formula posicionEnVectorMemoria = columna + fila * NumFilas
            MULU.W  #GRDWIDTH,D0
            ADD.W   D1,D0                   ;D0 = columna + fila * NumFilas
            ADD.W   D0,A1
            ;Comprobamos el valor de la celda
            CMP.B   #1,(A1)                 
            BEQ     .ESP1
            CMP.B   #2,(A1)                 
            BEQ     .ESP2
            BRA     .FIN
.ESP1       ADDQ.W  #1,D2
            BRA     .FIN
.ESP2       ADDQ.W  #1,D3
.FIN        MOVEM.L (A7)+,D0-D1/A1
            RTS


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

; TODO : PLACE YOUR CODE HERE
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            CLR.W (GRDNPLR1)
            CLR.W (GRDNPLR2)
            CLR.W D4
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
            MOVE.W  #GRDWIDTH/2-1,D2        ;ONLY ANALYZES HALF OF THE COLUMNS
.COPY       MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            CMP.W #2,D0
            BNE .NOCH
            MOVE.B #1,D0                    ;ANYTHING IN 1ST HALF HAS TO BE P1
.NOCH       MOVE.B  D0,(A0)+                ; STORE DATA
            ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            ADDQ.W #1,D4                    ;COUNTER OF ROWS
            ;SKIPS A ROW:
            MOVE.W D4,D5
            ;@ POSITION OF NEXT ROW = 
            ;ACTUAL ROW * NUM OF COLUMNS + POINTER INITIAL @
            MULU.W #GRDWIDTH,D5
            ADD.L (GRDDST),D5              
            MOVE.L D5,A0
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

; TODO : PLACE YOUR CODE HERE
            MOVEM.L D0-D7/A0-A6,-(A7)       ; TO BE OPTIMIZED
            CLR.W (GRDNPLR1)
            CLR.W (GRDNPLR2)
            CLR.W D4
            MOVE.W #1,D5
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
            ADD.W #GRDWIDTH,A1              ; ANALYZES 2ND HALF OF THE GRID
            ;@ POSITION OF NEXT ROW = 
            ;ACTUAL ROW * NUM OF COLUMNS + POINTER INITIAL @
            MOVE.W D4,D5
            MULU.W #GRDWIDTH,D5
            ADD.W #GRDWIDTH/2,D5 ;SKIPS TO THE SECOND HALF OF COLUMNS
            ADD.L (GRDDST),D5              
            MOVE.L D5,A0
            MOVE.W  #GRDWIDTH/2-1,D2        ;ONLY ANALYZES HALF OF THE COLUMNS
.COPY       
            MOVE.B  (A1)+,D0                ; PICK ONE LOADED CHARACTER
            SUB.B   #'0',D0                 ; CONVERT FROM ASCII TO NUMBER
            CMP.W #1,D0
            BNE .NOCH
            MOVE.B #2,D0                    ;ANYTHING IN 2ND HALF HAS TO BE P2
.NOCH       MOVE.B  D0,(A0)+                ; STORE DATA
            ADDQ.L  #1,A1                   ; SKIP THE COMMA
            DBRA.W  D2,.COPY
            ADDQ.W #1,D4
            MOVE.W  #GRDWIDTH/2-1,D2        ;ONLY ANALYZES HALF OF THE COLUMNS
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

; TODO : PLACE YOUR CODE HERE
            MOVEM.L D0-D6/A1,-(A7)
            CLR.W (GRDNPLR1)
            CLR.W (GRDNPLR2)
            MOVE.L (GRDDST), A1
            
            ;WIDTH:
            MOVE.B #93,D0
            MOVE.B #1,D1
            TRAP #15
            ;CONTOUR COLOR:
            MOVE.B #80,D0
            MOVE.L #CLRMDGRN,D1
            TRAP #15
            ;DRAWS THE GRID:
            MOVE.W #GRDYOFF,D2
            MOVE.W D2,D4
            ADD.W #GRDSZCEL,D4
            MOVE.W #GRDXOFF,D1
            MOVE.W D1,D3
            MOVE.W #GRDHEIGH-1,D6
            MOVE.W #GRDWIDTH-1,D5
            BRA .LOOP
            
.LOOPY      MOVE.W D4,D2
            ADD.W #GRDSZCEL,D4 ;NEXT Y CELL
            MOVE.W #GRDXOFF,D1 ;COLUMNS START BACK AGAIN (NEW ROW)
            MOVE.W D1,D3
            MOVE.W #GRDWIDTH-1,D5
            
            ;SELECTS FILL COLOUR OF THE CELL
.LOOP       CMP.B #0,(A1)
            BEQ .PAINTB
            BTST.B #0,(A1)
            BNE .BLUE
            BRA .RED
            
            ;DRAWS CELL
.PAINT      MOVE.W D3,D1
            MOVE.B #87,D0
            ADD.W #GRDSZCEL,D3 ;NEXT X CELL
            TRAP #15
            BRA .N
.PAINTB     ;DRAWS EMPTY CELL
            MOVE.W D3,D1
            MOVE.B #90,D0
            ADD.W #GRDSZCEL,D3 ;NEXT X CELL
            TRAP #15
.N          ADD.W #1,A1 ;NEXT CELL IN MATRIX
            ;ITERATES EACH COLUMN
            DBRA D5,.LOOP
            ;ITERATES EACH ROW
            DBRA D6,.LOOPY
            BRA .GEN
            
            ;TAGS TO CHANGE THE COLOR FILL:      
.BLUE       MOVE.B #81,D0
            MOVE.L #CLRLTBLU,D1
            TRAP #15
            ADDQ.W #1,(GRDNPLR1)
            BRA .PAINT
            
.RED        MOVE.B #81,D0
            MOVE.L #CLRLTRED,D1
            TRAP #15
            ADDQ.W #1,(GRDNPLR2)
            BRA .PAINT
            
            ;DRAWS THE NUMBER OF GENERATION AND P2 AND P1 SCORES:
            ;FILL COLOR P2:
.GEN        MOVE.B #81,D0
            MOVE.L #GRDCOLP2,D1
            TRAP #15
            CLR.L D1 ;CLEARS D1 IN CASE OF MIX WITH LONGWORD HIGH WORD
            ;SETS COORDINATES P2:
            MOVE.B #11,D0
            MOVE.B #GRDSCP2X,D1
            LSL.W #8,D1
            MOVE.B #GRDSCP2Y,D1
            TRAP #15         
            ;DRAWS SCORE NUMBER P2:
            MOVE.B #20,D0
            MOVE.W (GRDNPLR2),D1
            MOVE.B #4,D2 ;ADDS SPACE
            TRAP #15
            
            ;FILL COLOR GENERATIONS:
            MOVE.B #81,D0
            MOVE.L #CLRLTGRN,D1
            TRAP #15
            CLR.L D1 ;CLEARS D1 IN CASE OF MIX WITH LONGWORD HIGH WORD
            ;SETS COORDINATES GENERATIONS:
            MOVE.B #11,D0
            MOVE.B #GRDSCNGX,D1
            LSL.W #8,D1
            MOVE.B #GRDSCNGY,D1
            TRAP #15         
            ;DRAWS NUMBER OF GENERATIONS:
            MOVE.B #20,D0
            MOVE.W (GRDNGEN),D1
            MOVE.B #4,D2 ;ADDS SPACE
            TRAP #15
            
            ;FILL COLOR P1:
            MOVE.B #81,D0
            MOVE.L #GRDCOLP1,D1
            TRAP #15
            CLR.L D1 ;CLEARS D1 IN CASE OF MIX WITH LONGWORD HIGH WORD
            ;SETS COORDINATES P1;
            MOVE.B #11,D0
            MOVE.B #GRDSCP1X,D1
            LSL.W #8,D1
            MOVE.B #GRDSCP1Y,D1
            TRAP #15
            ;DRAWS SCORE NUMBER P1:
            MOVE.B #20,D0
            MOVE.W (GRDNPLR1),D1
            MOVE.B #4,D2 ;ADDS SPACE
            TRAP #15
            
            LEA .WINR,A1 ;ASSIGNS ASTERISK STRING TO A1 
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
            
.END        MOVEM.L (A7)+,D0-D6/A1
            RTS      
            
.WINR       DC.B    '*',0
            DS.W    0










































*~Font name~Courier New~
*~Font size~10~
*~Tab type~0~
*~Tab size~4~
