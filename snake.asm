INCLUDE		Irvine32.inc	
INCLUDELIB	user32.lib

mGoTo MACRO indexX:REQ, indexY:REQ
	PUSH edx
	MOV dl, indexX
	MOV dh, indexY
	call Gotoxy
	POP edx
ENDM

mWrite MACRO drawText:REQ
	LOCAL string
	.data
		string BYTE drawText, 0
	.code
		PUSH edx
		MOV edx, OFFSET string
		call WriteString
		POP edx
ENDM

SetColor MACRO color:REQ
    mov ah, 09 ; DOS中斷功能9：顯示字元並設置文字顏色
    mov al, color ; 高 4 位表示背景顏色，低 4 位表示前景顏色
    int 10h      ; 呼叫 BIOS 中斷
ENDM

; KeyCodes:
	VK_LEFT		EQU	000000025h
	VK_UP		EQU	000000026h
	VK_RIGHT	EQU	000000027h
	VK_DOWN		EQU	000000028h

.data
;Window setup
	maxX EQU 79
	maxY EQU 24
	wallHor EQU '='
	wallVerL EQU '|'
	wallverR EQU '|'
	maxSize EQU 255

	Left BYTE 0
	Right BYTE 1 
	Up BYTE 0
	Down BYTE 0

	currentX BYTE 40
	currentY BYTE 10
	FoodX BYTE 0
	FoodY BYTE 0
	bodyLength BYTE 6
	SnakeBody BYTE maxSize DUP(0,0)
	SnakeChar BYTE '@'
	foodChar BYTE '#'
	tailX BYTE 0
	tailY BYTE 0
	score DWORD 0
	speed DWORD 80 ;控制蛇的速度
	difficulty DWORD 9 ; 4 or 6 or 9;難度

	outputHandle DWORD 0
	inputHandle  DWORD 0
	bytesRead    DWORD 0 ; 偵測鼠標點擊位置
	firstScore DWORD 0 ;前三高分
	secondScore DWORD 0
	thirdScore DWORD 0


.code
main PROC
    CALL printStart
L1:
	mov bodyLength , 6
	mov speed , 80
	mov currentX, 40
	mov currentY, 10
	;INVOKE  SetDirection, 1, 0, 0, 0
	mov Right , 1
	mov Left , 0
	mov Up , 0
	mov Down , 0
	mov score , 0

    CALL printMenuDiff
    CALL ClrScr
    CALL showWalls
	.IF difficulty == 1
        CALL EasyGame
	.ELSEIF difficulty == 2
		CALL MediumGame
	.ELSEIF difficulty == 3
		CALL HardGame
	.ENDIF

    CMP difficulty,4
    JE ExitLoop
	JMP L1

ExitLoop:
    INVOKE ExitProcess, 0

    RET
main ENDP

EasyGame PROC
    CALL generateFood
L1:
    CALL Grow
    CALL KeySync
L2:
    CALL IsCollision
    CMP EAX, 0
    JE L3

    CMP EAX, 1
    JE L4
    CALL Across
L3:
    CALL moveSnake
    INVOKE Sleep, speed
    JMP L1

L4:
    INVOKE Sleep, 900
    CALL printGameOver

    RET
EasyGame ENDP

MediumGame PROC
    CALL generateFood
L1:
    CALL Grow
    CALL KeySync
L2:
    CALL IsCollision
    CMP EAX, 0
    JE L3
    JMP L4

L3:
    CALL moveSnake
    INVOKE Sleep, speed
    JMP L1

L4:
    INVOKE Sleep, 900
    CALL printGameOver

    RET
MediumGame ENDP

HardGame PROC
    CALL generateFood
L1:
    CALL Grow
    CALL KeySync
L2:
    CALL IsCollision
    CMP EAX, 0
    JE L3
    JMP L4

L3:
    CALL moveSnake
    INVOKE Sleep, speed
    JMP L1

L4:
    INVOKE Sleep, 900
    CALL printGameOver

    RET
HardGame ENDP


SetDirection PROC, R:BYTE, L:BYTE, U:BYTE, D:BYTE					; Values set in KeySync, either 0 or 1
	MOV	DL, R										
	MOV	RIGHT, DL
    
	MOV	DL, L									; Called when a key is pressed
	MOV	LEFT, DL								; Set Direction Bytes appropriately
    
	MOV	DL, U
	MOV	UP, DL
    
	MOV	DL, D
	MOV	DOWN, DL
	RET
SetDirection ENDP

moveSnake PROC
;Head moving
	MOV AL, currentX
	MOV AH, currentY
	
	MOV BX, 0
	MOV ESI, 0
	MOV BL, SnakeBody[ESI]
	MOV BH, SnakeBody[ESI+1]
	MOV SnakeBody[ESI], AL
	MOV SnakeBody[ESI+1], AH

	mgoTo SnakeBody[ESI], SnakeBody[ESI+1]	
	MOV AL, SnakeChar
	call WriteChar

;body moving
	MOV DL, bodyLength
	DEC bodyLength
	loopBody:
		CMP bodyLength, 0
		JE outLoopBody
		ADD ESI, 2
		MOV AL, BL
		MOV AH, BH
		MOV BL, SnakeBody[ESI]
		MOV BH, SnakeBody[ESI+1]
		MOV SnakeBody[ESI], AL
		MOV SnakeBody[ESI+1], AH
		DEC bodyLength
		JMP loopBody
	
	outLoopBody:
		MOV bodyLength, DL
;tail clear
	MOV tailX, BL
	MOV tailY, BH
	mgoTo tailX, tailY
	mWrite " "

	mgoTo	33, 0		; Displays all info on bottom of screen
	mWrite	"Score:  "    
	MOV	EAX, score	
	CALL	WriteInt	

	RET
moveSnake ENDP

KeySync PROC
	X00:
        MOV	AH, 0
        INVOKE GetKeyState, VK_DOWN						
        CMP	AH, 0									
        JE	X01									
        CMP	currentY, maxY					
        JNL	X01								
        INC	currentY
		MOV DL, SnakeBody[3]
		CMP currentY, DL
		JE Y00
        INVOKE	SetDirection, 0, 0, 0, 1						
        RET
		Y00:
			MOV DL, SnakeBody[2]
			CMP currentX, DL
			JE Y10
		Y10:
			DEC currentY
			JMP X04

  	X01:
        MOV     AH, 0									
        INVOKE  GetKeyState, VK_UP						
        CMP     AH, 0							
        JE      X02
        CMP     currentY, 0
        JNG     X02  
        DEC     currentY
		MOV DL, SnakeBody[3]
		CMP currentY, DL
		JE Y01
        INVOKE  SetDirection, 0, 0, 1, 0
        RET
		Y01:
			MOV DL, SnakeBody[2]
			CMP currentX, DL
			JE Y11
		Y11:
			INC currentY
			JMP X04

    X02:     
        MOV     AH, 0								
        INVOKE  GetKeyState, VK_LEFT						
        CMP     AH, 0   
        JE      X03
        CMP     currentX, 0
        JNG     X03 
        DEC     currentX
		MOV DL, SnakeBody[2]
		CMP currentX, DL
		JE Y02
        INVOKE  SetDirection, 0, 1, 0, 0
        RET
		Y02:
			MOV DL, SnakeBody[3]
			CMP currentY, DL
			JE Y12
		Y12:
			INC currentX
			JMP X04

    X03:  
        MOV		AH, 0								
        INVOKE  GetKeyState, VK_RIGHT
        CMP     AH, 0   
        JE      X04
        CMP     currentX, maxX
        JNL     X04 
        INC     currentX
		MOV DL, SnakeBody[2]
		CMP currentX, DL
		JE Y03
        INVOKE  SetDirection, 1, 0, 0, 0
        RET
		Y03:
			MOV DL, SnakeBody[3]
			CMP currentY, DL
			JE Y13
		Y13:
			DEC currentX
			JMP X04

	X04:     
        CMP     RIGHT, 0								
        JE      X05									
        CMP     currentX, maxX								
        JNL     X05								
        INC     currentX								
    
	X05:
        CMP     LEFT, 0									
        JE	X06
        CMP     currentX, 0
        JNG     X06
        DEC     currentX
    
	X06:
        CMP     UP, 0									
        JE      X07
        CMP     currentY, 0
        JNG     X07
        DEC     currentY

    X07:
        CMP     DOWN, 0									
        JE      X08
        CMP     currentY, maxY
        JNL     X08
        INC     currentY

    X08:													
        RET							
KeySync ENDP

;穿牆
Across PROC
	cmp EAX, 2
	JE X01
	cmp EAX, 3
	JE X02
	cmp EAX, 4
	JE X03
	cmp EAX, 5
	JE X04
	X01:
		MOV currentX, maxX-1
		RET
	X02:
		MOV currentY, maxY-1
		RET
	X03:
		MOV currentX, 1
		RET
	X04:
		MOV currentY, 2
		RET
Across ENDP

generateFood PROC
	CALL Randomize

	F00:
	CALL Random32
	XOR	EDX, EDX				;Quickly clears EDX
	MOV	ECX, maxX - 1							
	DIV	ECX									
	INC	DL
	MOV	foodX, DL

	CALL Random32								
	XOR	EDX, EDX
	MOV	ECX, maxY - 3
	DIV	ECX
	ADD	DL, 2
	MOV	foodY, DL

	MOV ESI, 0		;check if the food is generated on the sanke's body
	XOR EAX, EAX
	MOV BL, 2
	MOV AL, bodyLength
	DEC AL
	MUL BL
	loopF:
		CMP ESI, EAX
		JA F02
		MOV BL, SnakeBody[ESI]
		CMP foodX, BL
		JNE F01
		MOV BL, SnakeBody[ESI+1]
		CMP foodY, BL
		JE F00
		F01:
			ADD ESI, 2
			JMP loopF

	F02:
	mgoTo foodX, foodY
	MOV	AL, foodChar
	CALL WriteChar

	RET
generateFood ENDP

Grow PROC										
		MOV AH, currentX
        MOV AL, currentY

        CMP AH, foodX								
        JNE X00									
        CMP AL, foodY								
        JNE X00

        CALL generateFood								
        ADD bodyLength, 2	
		ADD score, 10
		MOV EDX, score
		.IF difficulty == 1
			JMP X00                   ;不加速
		.ELSEIF difficulty == 2
			cmp EDX, 200              ;如果超過200分後就不再加速
			JGE X00
			SUB speed, 2              ;每次吃到東西就增加速度
		.ELSEIF difficulty == 3
			 SUB speed, 3             ;每次吃到東西就增加速度
		.ENDIF

   
	X00:
        RET
Grow ENDP

IsCollision PROC									
	CMP	currentX, 0								
	JE	X02										
	CMP	currentY, 1								
	JE	X03
	CMP	currentX, maxX								
	JE	X04
	CMP	currentY, maxY								
	JE	X05

	MOV ESI, 2
	XOR EAX, EAX
	MOV BL, 2
	MOV AL, bodyLength
	DEC AL
	MUL BL
	loopHit:
		CMP ESI, EAX
		JA X01
		MOV DL, SnakeBody[ESI]
		CMP currentX, DL
		JNE L1
		MOV DL, SnakeBody[ESI+1]
		CMP currentY, DL
		JE X00
		L1:
			ADD ESI, 2
			JMP loopHit
	
    X00:
	MOV	EAX, 1									
	RET

    X01:
	MOV	EAX, 0									
	RET

	X02:
	MOV EAX, 2
	RET

	X03:
	MOV EAX, 3
	RET

	X04:
	MOV EAX, 4
	RET

	X05:
	MOV EAX, 5
	RET
IsCollision ENDP

showWalls PROC
	mgoTo 0, 1
	MOV al, maxX
	inc al
	loopWallH1:
		mWrite wallHor
		dec al
		CMP al,0
		loopnz loopWallH1

	mgoTo 0, maxY
	MOV al, maxX
	inc al
	loopWallH2:
		mWrite wallHor
		dec al
		CMP al,0
		loopnz loopWallH2

	MOV al, maxY
	dec al
	loopWall:
		CMP al, 1
		JE endloopWall
		mgoTo 0, al
		mWrite wallVerL
		mgoTo maxX, al
		mWrite wallVerR
		dec al
		JMP loopWall

	endloopWall:
		ret
showWalls ENDP

printStart PROC uses eax edx ebx
    LOCAL menuStartPosition:COORD,input_rec:INPUT_RECORD
    call Clrscr
    INVOKE GetStdHandle, STD_OUTPUT_HANDLE; Get the console ouput handle
    mov outputHandle, eax ; save console handle

    INVOKE GetStdHandle,STD_INPUT_HANDLE; Get the console input handle
    mov inputHandle, eax ; save console handle

    invoke SetConsoleMode, inputHandle, 090h;

    CALL DrawTitle
printStartread:
    INVOKE ReadConsoleInput,
        inputHandle,   ; handle to console-input buffer
        ADDR input_rec,  ; ptr to input buffer
        1,                           ; request number of records
        ADDR bytesRead               ; ptr to number of records read
    .IF input_rec.EventType!=2
        jmp printStartread;
    .ENDIF
    .IF input_rec.Event.dwButtonState!=1
        jmp printStartread;
    .ENDIF
    ret
printStart ENDP

printMenuDiff PROC uses eax edx ebx
    LOCAL input_rec:INPUT_RECORD
	call Clrscr
	INVOKE GetStdHandle, STD_OUTPUT_HANDLE; Get the console ouput handle
    mov outputHandle, eax ; save console handle

    INVOKE GetStdHandle,STD_INPUT_HANDLE; Get the console input handle
    mov inputHandle, eax ; save console handle

	invoke SetConsoleMode, inputHandle, 090h;

	CALL DrawMenu;

printMenuDiffread:
    INVOKE ReadConsoleInput,
        inputHandle,   ; handle to console-input buffer
        ADDR input_rec,  ; ptr to input buffer
        1,                           ; request number of records
        ADDR bytesRead               ; ptr to number of records read
    .IF input_rec.EventType!=2
        jmp printMenuDiffread;
    .ENDIF
    .IF input_rec.Event.dwButtonState!=1
        jmp printMenuDiffread;
    .ENDIF

    .IF (input_rec.Event.dwMousePosition.X>=34) && (input_rec.Event.dwMousePosition.X<=44) && (input_rec.Event.dwEventFlags == 0);
        movzx eax,input_rec.Event.dwMousePosition.X;
        call WriteInt;
		.IF input_rec.Event.dwMousePosition.Y==8
            mov difficulty,1;
            ret
        .ENDIF
        .IF input_rec.Event.dwMousePosition.Y==10
            mov difficulty,2;
            ret
        .ENDIF
        .IF input_rec.Event.dwMousePosition.Y==12
            mov difficulty,3;
            ret
        .ENDIF
     .ENDIF

    jmp printMenuDiffread;
printMenuDiff ENDP

printGameOver PROC uses eax edx ebx
    LOCAL input_rec:INPUT_RECORD
	call Clrscr
	INVOKE GetStdHandle, STD_OUTPUT_HANDLE; Get the console ouput handle
    mov outputHandle, eax ; save console handle

    INVOKE GetStdHandle,STD_INPUT_HANDLE; Get the console input handle
    mov inputHandle, eax ; save console handle

	invoke SetConsoleMode, inputHandle, 090h;

	CALL gameOver;

printGameOverread:
    INVOKE ReadConsoleInput,
        inputHandle,   ; handle to console-input buffer
        ADDR input_rec,  ; ptr to input buffer
        1,                           ; request number of records
        ADDR bytesRead               ; ptr to number of records read
    .IF input_rec.EventType!=2
        jmp printGameOverread;
    .ENDIF
    .IF input_rec.Event.dwButtonState!=1
        jmp printGameOverread;
    .ENDIF

    .IF (input_rec.Event.dwMousePosition.Y==19) && (input_rec.Event.dwEventFlags == 0);
        movzx eax,input_rec.Event.dwMousePosition.X;
        call WriteInt;
		.IF (input_rec.Event.dwMousePosition.X>=33) && (input_rec.Event.dwMousePosition.X<=47)
            ret
        .ENDIF
	.ENDIF
	.IF (input_rec.Event.dwMousePosition.Y==21) && (input_rec.Event.dwEventFlags == 0);
        movzx eax,input_rec.Event.dwMousePosition.X;
        call WriteInt;
		.IF (input_rec.Event.dwMousePosition.X>=36) && (input_rec.Event.dwMousePosition.X<=44)
            mov difficulty,4;
            ret
        .ENDIF
	.ENDIF

    jmp printGameOverread;
printGameOver ENDP

DrawTitle PROC
	CALL	ClrScr
	CALL	showWalls

	mgoTo 2, 4									
	mWrite	"                                                                        "	
	mgoTo 2, 5
	mWrite	"  .............      @@@@@  @   @    @    @  @   @@@@@      ............"
	mgoTo 2, 6
	mWrite	"    ...........      @      @@  @   @ @   @ @    @          ........... "
	mgoTo 2, 7
	mWrite	"     ..........      @@@@@  @ @ @  @@@@@  @@@    @@@@       ..........  "
	mgoTo 2, 8
	mWrite	"      .........          @  @  @@  @   @  @  @   @          .........   "
	mgoTo 2, 9
	mWrite	"       ........      @@@@@  @   @  @   @  @   @  @@@@@      ........    "
	mgoTo 2, 10
	mWrite	"        .......      --------------------------------       .......     "
	mgoTo 2, 11
	mWrite	"          .....           A  S  S  E  M  B  L  Y            ......      "
	mgoTo 2, 12
	mWrite	"           ....      --------------------------------       .....       "
	mgoTo 2, 13
	mWrite	"            ...      @@@@@@     @     @       @ @@@@@@      ...         "
	mgoTo 2, 14
	mWrite	"             ==      @         @ @    @@     @@ @           ==          "
	mgoTo 2, 15
	mWrite	"           __||__    @ @@@@   @   @   @ @   @ @ @@@@@     __||__        "
	mgoTo 2, 16
	mWrite	"          |      |   @    @  @@@@@@@  @  @ @  @ @        |      |       "
	mgoTo 2, 17
	mWrite	" _________|______|__ @@@@@@ @       @ @   @   @ @@@@@@ __|______|_______"
	mgoTo 2, 20
	mWrite	"                       click anywhere to continue...                    "
	mgoTo 54, 40
					
	RET
DrawTitle ENDP

DrawMenu PROC
	CALL	ClrScr
	CALL	showWalls

	mgoTo 2, 4
	mWrite "      ______________________ Choose Difficulty ______________________ "
	mgoTo 2, 6
	mWrite "                       ____________________________               "
	mgoTo 2, 7
	mWrite "                      |                            |              "
	mgoTo 2, 8
	mWrite "                      |         [  Easy  ]         |              "
	mgoTo 2, 9
	mWrite "                      |                            |              "
	mgoTo 2, 10
	mWrite "                      |         [ Medium ]         |              "
	mgoTo 2, 11
	mWrite "                      |                            |              "
	mgoTo 2, 12
	mWrite "                      |         [  Hard  ]         |              "
	mgoTo 2, 13 
	mWrite "                      |                            |              "
	mgoTo 2, 14 
	mWrite "                      |____________________________|              "
	mgoTo 25, 20					
	   
	RET
DrawMenu ENDP

gameOver PROC
	CALL	Clrscr
	CALL	showWalls

	mgoTo 2, 4									
	mWrite	"                                                   Your score:"	
	mgoTo 2, 5
	mWrite	"                 GAME OVER!!           /~\"
	mgoTo 2, 6
	mWrite	"                                      |oo )"
	mgoTo 2, 7
	mWrite	"                                      _\=/_"
	mgoTo 2, 8
	mWrite	"                      ___        #   /  _  \       Top 3:"
	mgoTo 2, 9
	mWrite	"                     / ()\        \\//|/.\|\\      1          "
	mgoTo 2, 10
	mWrite	"                   _|_____|_       \/  \_/  ||     2          "
	mgoTo 2, 11
	mWrite	"                  | | === | |         |\ /| ||     3          "
	mgoTo 2, 12
	mWrite	"                  |_|  O  |_|         \_ _/ #"
	mgoTo 2, 13
	mWrite	"                   ||  O  ||          | | |"
	mgoTo 2, 14
	mWrite	"                   ||__*__||          | | |"
	mgoTo 2, 15
	mWrite	"                  |~ \___/ ~|         []|[]"
	mgoTo 2, 16
	mWrite	"                  /=\ /=\ /=\         | | |"
	mgoTo 2, 17
	mWrite	"  ________________[_]_[_]_[_]________/_]_[_\_______________________"
	mgoTo 2, 19
	mWrite	"                               [ try  again ]                            "
	mgoTo 2, 21
	mWrite	"                                  [ exit ]                              "

	mgoTo 67, 4
	MOV	EAX, score						
	CALL WriteInt

	cmp eax , thirdScore
	jb no_change
	je no_change
	cmp eax , secondScore
	jb change_third
	je no_change
	cmp eax , firstScore	
	je no_change
	jb change_second
	ja change_first

no_change:
	jmp done
 
change_third:
	mov ebx , score
	mov thirdScore, ebx 
	jmp done

change_second:
	mov ebx , secondScore
	mov thirdScore, ebx 
	mov ebx , score
	mov secondScore, ebx
	jmp done

change_first:
	mov ebx , secondScore
	mov thirdScore, ebx 
	mov ebx , firstScore
	mov secondScore, ebx
	mov ebx , score
	mov firstScore , ebx
	jmp done
	
done:
	mgoTo 61, 9
	MOV	EAX, firstScore						
	CALL WriteInt

	mgoTo 61, 10
	MOV	EAX, secondScore						
	CALL WriteInt

	mgoTo 61, 11
	MOV	EAX, thirdScore						
	CALL WriteInt
	
	mgoTo 55, 6
	CMP score, 50
	JBE S01
	CMP score, 100
	JBE S02
	CMP score, 150
	JBE S03
	CMP score, 200
	JBE S04
	CMP score, 250
	JBE S05
	JMP S06
	
	S01:
		mWrite	"★ ☆ ☆ ☆ ☆"
		JMP End07
	S02:
		mWrite	"★ ★ ☆ ☆ ☆"
		JMP End07
	S03:
		mWrite	"★ ★ ★ ☆ ☆"
		JMP End07
	S04:
		mWrite	"★ ★ ★ ★ ☆"
		JMP End07
	S05:
		mWrite	"★ ★ ★ ★ ★"
		JMP End07
	S06:
		mWrite	"★ ★ ★ ★ ★"
		mgoTo 55, 13
		mWrite	" Legendary!!! "
	End07:

	RET			

gameOver ENDP

END main
