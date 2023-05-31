*-----------------------------------------------------------
* Program    : Shuffle Board
* Written by : Peyton Ryan
* Date       : 9/26/22
* Description: A 2-player shuffleboard game
* where players take turns shooting pucks to
* get the highest score. Features circular
* ellastic collision which was a nightmare.
* REQUIREMENTS
* 1 control puck position and poewr
* 2 background is a set image
* 3 friction applied as negative acceleration
* 4 position as 2 decimal precision (hex)
* 5 ELLASTIC CIRCULAR COLLISION BABY
* 6 Score is displayed in 7 segment displays
* 7 First player is determined randomly
* Turned out fantastic.
*-----------------------------------------------------------
NUM_PUCKS       EQU 6
PUCK_SIZE       EQU 16
PUCK_SIZE_S     EQU $10000
PUCK_DATA_SIZE  EQU 64
FRICTION        EQU 240
FRICTION_ZERO   EQU $7FFFFF
TOP_2_F         EQU $FF000000
PUCK_START_X    EQU $14000
PUCK_START_Y    EQU $1A000
PUCK_MAX_X      EQU $16800
PUCK_MIN_X      EQU $11800
PUCK_MAX_Y      EQU $1CC00
PUCK_MIN_Y      EQU $6400
THREE_POINT     EQU $8C00
TWO_POINT       EQU $B400
PUCK_POW_MAX    EQU $1800
PUCK_POW_MIN    EQU $800
PUCK_POS_MS     EQU $280
PUCK_POW_MS     EQU $80
PUCK_POW_DMS    EQU $100
PUCK_STORE_X    EQU $20000
PUCK_STORE_DY   EQU $2000

DISPLAY_WIDTH   EQU 640
DISPLAY_HEIGHT  EQU 480

SPACE_KEY_CODE  EQU 32

GET_INPUT_TC    EQU 19
DISPLAY_RES_TC  EQU 33
PEN_COLOR_TC    EQU 80
FILL_COLOR_TC   EQU 81
DRAW_PIXEL_TC   EQU 82
DRAW_RECT_TC    EQU 87
DRAW_MODE_TC    EQU 92
PEN_WIDTH_TC    EQU 93
REPAINT_TC      EQU 94

GET_TIME_CODE   EQU 8

SINGLE_BUFFER   EQU 16
DOUBLE_BUFFER   EQU 17

SCORE_A_X       EQU 225
SCORE_A_Y       EQU 150
SCORE_A_COLOR   EQU $000000FF
SCORE_A_LEN     EQU 20
SCORE_A_THICK   EQU 4

SCORE_B_X       EQU 415
SCORE_B_Y       EQU 150
SCORE_B_COLOR   EQU $00FF0000
SCORE_B_LEN     EQU 20
SCORE_B_THICK   EQU 4

BG_COLOR        EQU $FFD49900 ;$00FFD499

START 	ORG $1000
    ;set screen resolution
    move.b      #DISPLAY_RES_TC,d0
    move.l      #DISPLAY_WIDTH,d1
    swap.w      d1
    move.w      #DISPLAY_HEIGHT,d1
    trap        #15
    
    ;set double buffering
    move.b      #DRAW_MODE_TC,d0
    move.b      #DOUBLE_BUFFER,d1
    trap        #15
    
    ;set values of registers
    move.l      #0, d0 
    move.l      #1, d1
    move.l      #2, d2
    move.l      #3, d3
    move.l      #4, d4
    move.l      #5, d5
    move.l      #6, d6
    move.l      #7, d7
    
    ;allocate stack 
	move.l      #PUCK_DATA_SIZE,d0
    add.l       #1,d0
    mulu        #NUM_PUCKS,d0
    sub.l       d0,sp
	
	;paint screen
    move.b      #REPAINT_TC,d0
    trap        #15
        
    jsr         seedRandom

resetGame
    jsr         getRandomBool
    
    ;create pucks
    move.l      #-1,d0
    move.l      #PUCK_START_Y,d1
    move.l      sp,a0
createPucks
    add.l       #1,d0
    cmp         #NUM_PUCKS,d0
    beq         createPucksDone
    add.l       #PUCK_DATA_SIZE,a0
    
    ;set puck default values
    move.w      #0,(a0)
    move.w      d6,2(a0)
    add.l       #1,d6
    and.l       #1,d6
    move.l      #PUCK_STORE_X,4(a0)
    move.l      d1,8(a0)
    move.l      4(a0),12(a0)
    move.l      8(a0),16(a0)
    move.l      #0,20(a0)
    move.l      #0,24(a0)
    move.l      #0,28(a0)
    move.l      #0,32(a0)
    sub.l       #PUCK_STORE_DY,d1
    
    bra         createPucks
createPucksDone
    move.l      sp,a0
    
    ;Draw BG
    lea         imgBG,a0
	move.l      a0,(sp)
	move.l      #0,4(sp)  ;Image top left X
	move.l      #0,8(sp)  ;Image top left Y
	move.l      #640,12(sp) ;Image width
	move.l      #480,16(sp) ;Image height
	move.l      #0,20(sp) ;Display top left X
	move.l      #0,24(sp) ;Display top left Y
    jsr displayBitmap
    
    ;draw 0-0 score
    jsr updateScores
    
    ;game variables
    move.l      #0,32(sp) ;puck num counter
    move.l      sp,36(sp) ;current puck address
    move.l      #0,40(sp) ;are all pucks done
gameLoop
    add.l       #PUCK_DATA_SIZE,36(sp)
    jsr         getPuckPos
    jsr         getPuckPower

movePucksLoop
    move.l      #0,40(sp)
    jsr         updatePucks
    jsr         renderPucks
    jsr         setOldPos
    jsr         resolveCollisions
    jsr         updateScores
    
    move.l      40(sp),d0
    cmp         #0,d0
    bne         movePucksLoop
    
    move.l      32(sp),d0
    add.l       #1,d0
    move.l      d0,32(sp)
    cmp         #NUM_PUCKS,d0
    bne         gameLoop
    
    bra         resetGame
    
	STOP #$2000

;---------------------------
resolveCollisions
    move.l      sp,a4
    add.l       #4,a4
    
    move.l      #0,d0
    
    ;iterate over each puck, 
    ;only checking higher id pucks than it
resolveOuterLoop
    add.l       #1,d0
    cmp.l       #NUM_PUCKS,d0
    beq         resolveOuterLoopDone
    
    add.l       #PUCK_DATA_SIZE,a4
    move.l      a4,a5
    move.l      d0,d1
resolveInnerLoop
    add.l       #1,d1
    cmp.l       #NUM_PUCKS,d1
    bgt         resolveOuterLoop
    
    add.l       #PUCK_DATA_SIZE,a5
    
    ;check for collision
    ;uses pythagorean cause circles
    move.l      4(a4),d2
    sub.l       4(a5),d2
    move.l      d2,d4
    cmp.l       #0,d2
    bgt         absFirstDone
    neg.l       d2
absFirstDone
    lsr.l       #4,d2  
    mulu        d2,d2
    move.l      8(a4),d3
    sub.l       8(a5),d3
    move.l      d3,d5
    cmp.l       #0,d3
    bgt         absSecondDone
    neg.l       d3
absSecondDone
    lsr.l       #4,d3
    mulu        d3,d3
    add.l       d3,d2
    ;check against radius squared
    ;we dont be doing sqrt
    cmp.l       #PUCK_SIZE_S,d2
    bge         resolveInnerLoop
    
    ;set colliding pucks as active
    move.w      #2,(a4)
    move.w      #2,(a5)
    
    ;clear some variables
    ;this formula is hefty for the
    ;ellastic collisions, but is
    ;convenient in that it doesn't
    ;use trig functions and only
    ;vector math
    move.l      #0,4(sp)  ;xdx
    move.l      #0,8(sp)  ;xdy
    move.l      #0,12(sp) ;vdx
    move.l      #0,16(sp) ;vdy
    move.l      #0,20(sp)
    move.l      #0,24(sp)
    
    move.l      sp,a6
    add.l       #4,a6
    
    ;set xdx
    move.l      4(a4),d2
    sub.l       4(a5),d2
    move.l      d2,4(a6)
    
    ;set xdy
    move.l      8(a4),d2
    sub.l       8(a5),d2
    move.l      d2,8(a6)
    
    ;set vdx
    move.l      20(a4),d2
    sub.l       20(a5),d2
    move.l      d2,12(a6)
    
    ;set vdy
    move.l      24(a4),d2
    sub.l       24(a5),d2
    move.l      d2,16(a6)
    
    ;set dv . dx
    move.w      6(a6),d3
    move.w      14(a6),d4
    muls        d4,d3
    cmp.l       #0,d3
    blt         dvdxNegative1
    lsr.l       #4,d3
    bra         dvdxPositive1
dvdxNegative1
    neg.l       d3
    lsr.l       #4,d3
    neg.l       d3
dvdxPositive1
    move.w      10(a6),d4
    move.w      18(a6),d5
    muls        d5,d4
    cmp.l       #0,d4
    blt         dvdxNegative2
    lsr.l       #4,d4
    bra         dvdxPositive2
dvdxNegative2
    neg.l       d4
    lsr.l       #4,d4
    neg.l       d4
dvdxPositive2
    add.l       d4,d3
    
    ;set |dx| 2
    move.l      #0,d4
    move.w      6(a6),d4
    muls        d4,d4
    move.l      #0,d5
    move.w      10(a6),d5
    muls        d5,d5
    add.l       d5,d4
    lsr.l       #8,d4
    lsr.l       #4,d4
    
    
    ; set (dv . dx) / |dx|2
    divs        d4,d3
    move.l      #0,d4
    move.w      d3,d4
    
    ; multiply previous by dx
    move.w      6(a6),d5
    move.w      10(a6),d6
    muls        d4,d5
    cmp.l       #0,d5
    blt         dvdxNegative4
    lsr.l       #8,d5
    bra         dvdxPositive4
dvdxNegative4
    neg.l       d5
    lsr.l       #8,d5
    neg.l       d5
dvdxPositive4
    muls        d4,d6
    cmp.l       #0,d6
    blt         dvdxNegative5
    lsr.l       #8,d6
    bra         dvdxPositive5
dvdxNegative5
    neg.l       d6
    lsr.l       #8,d6
    neg.l       d6
dvdxPositive5
    
    ;subtract previous from v
    neg.l       d5
    neg.l       d6
    add.l       20(a4),d5
    add.l       24(a4),d6
    
    ;set new velocity
    move.l      d5,28(a4)
    move.l      d6,32(a4)
    
    ;repeat for the other puck
    
    ;set xdx
    move.l      4(a5),d2
    sub.l       4(a4),d2
    move.l      d2,4(a6)
    
    ;set xdy
    move.l      8(a5),d2
    sub.l       8(a4),d2
    move.l      d2,8(a6)
    
    ;set vdx
    move.l      20(a5),d2
    sub.l       20(a4),d2
    move.l      d2,12(a6)
    
    ;set vdy
    move.l      24(a5),d2
    sub.l       24(a4),d2
    move.l      d2,16(a6)
    
    ;set dv . dx
    move.w      6(a6),d3
    move.w      14(a6),d4
    muls        d4,d3
    cmp.l       #0,d3
    blt         dvdxNegative1B
    lsr.l       #4,d3
    bra         dvdxPositive1B
dvdxNegative1B
    neg.l       d3
    lsr.l       #4,d3
    neg.l       d3
dvdxPositive1B
    move.w      10(a6),d4
    move.w      18(a6),d5
    muls        d5,d4
    cmp.l       #0,d4
    blt         dvdxNegative2B
    lsr.l       #4,d4
    bra         dvdxPositive2B
dvdxNegative2B
    neg.l       d4
    lsr.l       #4,d4
    neg.l       d4
dvdxPositive2B
    add.l       d4,d3
    
    ;set |dx| 2
    move.l      #0,d4
    move.w      6(a6),d4
    muls        d4,d4
    move.l      #0,d5
    move.w      10(a6),d5
    muls        d5,d5
    add.l       d5,d4
    lsr.l       #8,d4
    lsr.l       #4,d4
    
    
    ; set (dv . dx) / |dx|2
    divs        d4,d3
    move.l      #0,d4
    move.w      d3,d4
    
    ;multiply previous times dx
    move.w      6(a6),d5
    move.w      10(a6),d6
    muls        d4,d5
    cmp.l       #0,d5
    blt         dvdxNegative4B
    lsr.l       #8,d5
    bra         dvdxPositive4B
dvdxNegative4B
    neg.l       d5
    lsr.l       #8,d5
    neg.l       d5
dvdxPositive4B
    muls        d4,d6
    cmp.l       #0,d6
    blt         dvdxNegative5B
    lsr.l       #8,d6
    bra         dvdxPositive5B
dvdxNegative5B
    neg.l       d6
    lsr.l       #8,d6
    neg.l       d6
dvdxPositive5B
    
    ; subtract previous from v
    neg.l       d5
    neg.l       d6
    add.l       20(a5),d5
    add.l       24(a5),d6
    ; set new v
    move.l      d5,28(a5)
    move.l      d6,32(a5)

    
    
    bra         resolveInnerLoop
resolveOuterLoopDone
    rts

getPuckPower
    move.l      40(sp),a4
    move.l      #0,28(a4)
    move.l      #PUCK_POW_DMS,32(a4)
    move.l      #PUCK_POW_MIN,48(sp)
    neg.l       48(sp)
    move.l      #PUCK_POW_MAX,52(sp)
    neg.l       52(sp)
getPuckPowerLoop
    move.l      (sp),60(sp)
    add.l       #4,sp
    jsr         updatePucks
    jsr         renderPucks
    jsr         setOldPos
    sub.l       #4,sp
    move.l      60(sp),(sp)
    
    sub.l       #PUCK_POW_MS,48(sp)
    move.l      40(sp),a4      
    
    move.l      48(sp),d0
    move.l      52(sp),d1
    cmp.l       d0,d1
    bge         getPuckPowerLoopDone
    
    move.l      #SPACE_KEY_CODE,d1
    move.l      #GET_INPUT_TC,d0
    TRAP        #15
    andi.l      #$FF,d1
    beq         getPuckPowerLoopDone
    
    bra         getPuckPowerLoop
    
getPuckPowerLoopDone

    
    move.l      48(sp),32(a4)
    
    move.w      #2,(a4)
    rts

getPuckPos
    move.l      40(sp),a4
    
    move.w      #1,(a4)
    move.l      #PUCK_START_Y,16(a4)
    
    move.l      #PUCK_START_X,12(a4)
    move.l      #PUCK_POS_MS,28(a4)
    move.l      #PUCK_POS_MS,20(a4)
    move.l      #PUCK_MAX_X,d2
    move.l      #PUCK_MIN_X,d3
    
puckPosLoop
    move.l      40(sp),a4
    move.l      4(a4),d0
    move.l      28(a4),d1
    cmp         d0,d2
    ble         puckPosFlip
    cmp         d0,d3
    bge         puckPosFlip
    bra         puckPosDontFlip
puckPosFlip
    neg.l       d1
puckPosDontFlip
    move.l      d1,28(a4)

    move.l      (sp),60(sp)
    add.l       #4,sp
    jsr         updatePucks
    jsr         renderPucks
    jsr         setOldPos
    sub.l       #4,sp
    move.l      60(sp),(sp)
    
    ;check for player input
    move.l      #SPACE_KEY_CODE,d1
    move.l      #GET_INPUT_TC,d0
    TRAP        #15
    andi.l      #$FF,d1
    beq         puckPosLoop
    
    move.l      #0,28(a4)
    
    rts

updateScores
    ;checks the scores and print to screen
    ;uses 7 segment display
    move.l      #-1,d2
    
    move.l      sp,a4
    add.l       #4,a4
    
    move.l      #0,20(sp)
    move.l      #0,24(sp)
    
updateScoresLoop
    ;check all the pucks, add to score
    add.l       #PUCK_DATA_SIZE,a4
    add.l       #1,d2
    cmp         #NUM_PUCKS,d2
    beq         updateScoresLoopDone
    
    cmp.w       #0,2(a4)
    bne         updateScoresRed
    
    ;check if out of bounds
    move.l      #PUCK_MAX_X,d3
    cmp.l       4(a4),d3
    blt         updateScoresLoop
    move.l      #PUCK_MIN_X,d3
    cmp.l       4(a4),d3
    bgt         updateScoresLoop
    move.l      #PUCK_MAX_Y,d3
    cmp.l       8(a4),d3
    blt         updateScoresLoop
    move.l      #PUCK_MIN_Y,d3
    cmp.l       8(a4),d3
    bgt         updateScoresLoop
    
    ;check if worth more points
    add.l       #1,20(sp)
    move.l      #TWO_POINT,d3
    cmp.l       8(a4),d3
    blt         updateScoresLoop
    add.l       #1,20(sp)
    move.l      #THREE_POINT,d3
    cmp.l       8(a4),d3
    blt         updateScoresLoop
    add.l       #1,20(sp)
    bra         updateScoresLoop
updateScoresRed  
    move.l      #PUCK_MAX_X,d3
    cmp.l       4(a4),d3
    blt         updateScoresLoop
    move.l      #PUCK_MIN_X,d3
    cmp.l       4(a4),d3
    bgt         updateScoresLoop
    move.l      #PUCK_MAX_Y,d3
    cmp.l       8(a4),d3
    blt         updateScoresLoop
    move.l      #PUCK_MIN_Y,d3
    cmp.l       8(a4),d3
    bgt         updateScoresLoop
    
    add.l       #1,24(sp)
    move.l      #TWO_POINT,d3
    cmp.l       8(a4),d3
    blt         updateScoresLoop
    add.l       #1,24(sp)
    move.l      #THREE_POINT,d3
    cmp.l       8(a4),d3
    blt         updateScoresLoop
    add.l       #1,24(sp)
    bra         updateScoresLoop
updateScoresLoopDone
    ;clear A score
    move.l      #BG_COLOR,d3
    move.l      #8,d4
    move.l      #SCORE_A_X,d5
    move.l      #SCORE_A_Y,d6
    jsr         drawScore
    ;clear B score
    move.l      #BG_COLOR,d3
    move.l      #8,d4
    move.l      #SCORE_B_X,d5
    move.l      #SCORE_B_Y,d6
    jsr         drawScore

    ;get A score
    move.l      #SCORE_A_COLOR,d3
    move.l      20(sp),d4
    move.l      #SCORE_A_X,d5
    move.l      #SCORE_A_Y,d6
    jsr         drawScore
    ;get B score
    move.l      #SCORE_B_COLOR,d3
    move.l      24(sp),d4
    move.l      #SCORE_B_X,d5
    move.l      #SCORE_B_Y,d6
    jsr         drawScore
    
    move.b      #REPAINT_TC,d0
    TRAP        #15
    rts


seedRandom
    clr.l       d6
    move.l      #GET_TIME_CODE,d0
    TRAP        #15
    move.l      d1,RANDOMVAL
    rts
    
getRandomBool
    ;returns 0 or 1
    movem.l d0,-(sp)
    movem.l d1,-(sp)
    movem.l d2,-(sp)
    move.l  RANDOMVAL,d0
    moveq	#$AF-$100,d1
    moveq	#18,d2
Ninc0	
	add.l	d0,d0
	bcc	Ninc1
	eor.b	d1,d0
Ninc1
	dbf	d2,Ninc0
	
	move.l	d0,RANDOMVAL
	clr.l	d6
	move.b	d0,d6
	
    movem.l (sp)+,d2
    movem.l (sp)+,d1
    movem.l (sp)+,d0
    
    andi    #1,d6
    
    rts

setOldPos  
    move.l      sp,a4
    add.l       #4,a4
    move.l      #-1,d1
setOldPosLoop
    add.l       #1,d1
    cmp         #NUM_PUCKS,d1
    beq         setOldPosLoopEnd
    add.l       #PUCK_DATA_SIZE,a4
    
    ;copy new position to old
    move.l      12(a4),4(a4)
    move.l      16(a4),8(a4)
    
    bra         setOldPosLoop
setOldPosLoopEnd
    rts


updatePucks
    move.l      sp,a4
    add.l       #4,a4
    move.l      #-1,d1
updatePucksLoop
    add.l       #1,d1
    cmp         #NUM_PUCKS,d1
    beq         updatePucksLoopEnd
    add.l       #PUCK_DATA_SIZE,a4
    
    ;If puck isn't active, skip it
    cmp.w       #0,(a4)
    beq         updatePucksLoop
    cmp.w       #1,(a4)
    beq         skipFriction
    cmp.w       #3,(a4)
    beq         updatePucksLoop
    
    ;apply friction
    move.l      28(a4),d0
    cmp         #0,d0
    blt         negativeX
    muls        #FRICTION,d0
    lsr.l       #8,d0
    bra         doneX
negativeX
    neg.l       d0
    muls        #FRICTION,d0
    lsr.l       #8,d0
    neg.l       d0
doneX
    move.l      d0,28(a4)
    move.l      28(a4),20(a4)
    
    move.l      32(a4),d0
    cmp         #0,d0
    blt         negativeY
    muls        #FRICTION,d0
    lsr.l       #8,d0
    bra         doneY
negativeY
    neg.l       d0
    muls        #FRICTION,d0
    lsr.l       #8,d0
    neg.l       d0
doneY
    move.l      d0,32(a4)
    move.l      32(a4),24(a4)
    bra dontSkipFriction
skipFriction
    move.l      28(a4),20(a4)
    move.l      32(a4),24(a4)
dontSkipFriction
    
    ;check if not moving
    cmp.l       #0,20(a4)
    bne         hasVelocity
    cmp.l       #0,24(a4)
    bne         hasVelocity
    move.w      #3,(a4)
    bra         noVelocity
hasVelocity
    move.l      #1,44(sp)
noVelocity
    move.l      20(a4),d0
    add.l       d0,12(a4)
    move.l      24(a4),d0
    add.l       d0,16(a4)
    
    bra         updatePucksLoop
updatePucksLoopEnd
    rts

updatePucksSetNotActive
    

renderPucks
    move.l      (sp),32(sp)
    move.l      sp,a4
    add.l       #4,a4
    move.l      #-1,d1
deletePucksLoop
    ;draws bg over place where puck was
    add.l       #1,d1
    cmp         #NUM_PUCKS,d1
    beq         deletePucksLoopEnd
    add.l       #PUCK_DATA_SIZE,a4
    
    lea         imgBg,a0
    ;Set other parameters
    move.l      #PUCK_SIZE,12(sp)
    move.l      #PUCK_SIZE,16(sp)
    move.l      4(a4),d0
    lsr.l       #8,d0
    sub.l       #PUCK_SIZE>>1,d0      
    move.l      d0,20(sp)
    move.l      8(a4),d0
    lsr.l       #8,d0
    sub.l       #PUCK_SIZE>>1,d0  
    move.l      d0,24(sp)
    move.l      20(sp),4(sp)
    move.l      24(sp),8(sp)
    jsr         displayBitmap
    bra         deletePucksLoop
deletePucksLoopEnd

    ;draw the pucks where they are now
    move.l      sp,a4
    add.l       #4,a4
    move.l      #-1,d1
renderPucksLoop
    add.l       #1,d1
    cmp         #NUM_PUCKS,d1
    beq         renderPucksLoopEnd
    add.l       #PUCK_DATA_SIZE,a4
    
    ;If puck isn't active, skip it
    ;cmp.w       #0,(a4)
    ;beq         renderPucksLoop
    
    ;Set puck color
    cmp.w       #0,2(a4)
    beq         chooseRed
    cmp.w       #2,2(a4)
    beq         chooseYellow
    lea         imgBlue,a0
    bra         choseColor
chooseRed
    lea         imgRed,a0
    bra         choseColor
chooseYellow
    lea         imgYellow,a0
choseColor
    move.l      a0,(sp)
    ;Set other parameters
    move.l      #0,4(sp)
    move.l      #0,8(sp)
    move.l      #PUCK_SIZE,12(sp)
    move.l      #PUCK_SIZE,16(sp)
    move.l      12(a4),d0
    lsr.l       #8,d0
    sub.l       #PUCK_SIZE>>1,d0      
    move.l      d0,20(sp)
    move.l      16(a4),d0
    lsr.l       #8,d0
    sub.l       #PUCK_SIZE>>1,d0  
    move.l      d0,24(sp)
    jsr         displayBitmap
    bra         renderPucksLoop
renderPucksLoopEnd
    move.l      32(sp),(sp)
    move.b      #REPAINT_TC,d0
    trap        #15
    rts
    


drawScore
    ;d3 Color
    ;d4 Value
    ;d5 Center X
    ;d6 Center Y
    
    ;Set pen colors
    move.l      d3,d1
    move.l      #PEN_COLOR_TC,d0
    TRAP        #15
    move.l      #FILL_COLOR_TC,d0
    TRAP        #15
    ;Set pen size
    move.l      #1,d1
    move.l      #PEN_WIDTH_TC,d0
    TRAP        #15
    
    ;Find segment code
    lea         SEGMENT_0, a0
    mulu        #4,d4
    add.l       d4, a0
    move.l      (a0),d7
    
    ;set rectangle code
    move.l      #DRAW_RECT_TC,d0
    
    move.l      #64, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipA
    ;drawA
    ;horizontal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_LEN>>1,d1
    add.l       #SCORE_A_LEN>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_THICK>>1,d2
    add.l       #SCORE_A_THICK>>1,d4
    ;adjustments
    sub.l       #SCORE_A_LEN,d2
    sub.l       #SCORE_A_LEN,d4
    TRAP        #15
aSkipA
    move.l      #32, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipB
    ;drawB
    ;vertcal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_THICK>>1,d1
    add.l       #SCORE_A_THICK>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_LEN>>1,d2
    add.l       #SCORE_A_LEN>>1,d4
    ;adjustments
    sub.l       #SCORE_A_LEN>>1,d2
    sub.l       #SCORE_A_LEN>>1,d4
    add.l       #SCORE_A_LEN>>1,d1
    add.l       #SCORE_A_LEN>>1,d3
    TRAP        #15
aSkipB
    move.l      #16, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipC
    ;drawC
    ;vertcal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_THICK>>1,d1
    add.l       #SCORE_A_THICK>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_LEN>>1,d2
    add.l       #SCORE_A_LEN>>1,d4
    ;adjustments
    add.l       #SCORE_A_LEN>>1,d2
    add.l       #SCORE_A_LEN>>1,d4
    add.l       #SCORE_A_LEN>>1,d1
    add.l       #SCORE_A_LEN>>1,d3
    TRAP        #15
aSkipC
    move.l      #8, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipD
    ;drawD
    ;horizontal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_LEN>>1,d1
    add.l       #SCORE_A_LEN>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_THICK>>1,d2
    add.l       #SCORE_A_THICK>>1,d4
    ;adjustments
    add.l       #SCORE_A_LEN,d2
    add.l       #SCORE_A_LEN,d4
    TRAP        #15
aSkipD
    move.l      #4, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipE
    ;drawE
    ;vertcal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_THICK>>1,d1
    add.l       #SCORE_A_THICK>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_LEN>>1,d2
    add.l       #SCORE_A_LEN>>1,d4
    ;adjustments
    add.l       #SCORE_A_LEN>>1,d2
    add.l       #SCORE_A_LEN>>1,d4
    sub.l       #SCORE_A_LEN>>1,d1
    sub.l       #SCORE_A_LEN>>1,d3
    TRAP        #15
aSkipE
    move.l      #2, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipF
    ;drawF
    ;vertcal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_THICK>>1,d1
    add.l       #SCORE_A_THICK>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_LEN>>1,d2
    add.l       #SCORE_A_LEN>>1,d4
    ;adjustments
    sub.l       #SCORE_A_LEN>>1,d2
    sub.l       #SCORE_A_LEN>>1,d4
    sub.l       #SCORE_A_LEN>>1,d1
    sub.l       #SCORE_A_LEN>>1,d3
    TRAP        #15
aSkipF
    move.l      #1, d1
    and         d7,d1
    cmp         #0, d1
    beq         aSkipG
    ;drawG
    ;horizontal
    move.l      d5,d1
    move.l      d5,d3
    sub.l       #SCORE_A_LEN>>1,d1
    add.l       #SCORE_A_LEN>>1,d3
    move.l      d6,d2
    move.l      d6,d4
    sub.l       #SCORE_A_THICK>>1,d2
    add.l       #SCORE_A_THICK>>1,d4
    ;adjustments
    TRAP        #15
aSkipG
    rts

saveRegisters ;saves registers d0-d6 to stack
    sub.l       #28,sp
    move.l      28(sp),(sp)
    move.l      d0,4(sp)
    move.l      d1,8(sp)
    move.l      d2,12(sp)
    move.l      d3,16(sp)
    move.l      d4,20(sp)
    move.l      d5,24(sp)
    move.l      d6,28(sp)
    rts
    
restoreRegisters ;takes values back from stack to registers
    move.l      4(sp),d0
    move.l      8(sp),d1
    move.l      12(sp),d2
    move.l      16(sp),d3
    move.l      20(sp),d4
    move.l      24(sp),d5
    move.l      28(sp),d6
    move.l      (sp),28(sp)
    add.l       #28,sp
    rts
    

displayBitmap
;accepts two numbers on the stack
;returns value in d7
;d0 and d1 unchanged
    jsr saveRegisters
     
    move.l  46(a0),d0
    jsr flipEndian
    move.l  d7,d1
    move.l  10(a0),d0
    jsr flipEndian
    move.l  d7,a1
    add.l   a0,a1
    move.l  sp,a6
    
    
    sub.l   #4,sp
    move.l  18(a0),d0 ;width
    jsr flipEndian
    move.l  d7,(sp)
    
    sub.l   #4,sp
    move.l  22(a0),d0 ;height
    jsr flipEndian
    move.l  d7,(sp)
    
    sub.l   #4,sp
    
    move.l  a0,a1
    move.l  10(a0),d0 ;pixel data address
    jsr flipEndian
    add.l   d7,a1
        
    move.l  #0,a2  ;current row bit
    move.l  #0,a3  ;start row bit
    move.l  #0,d0  ;function input
    move.l  #0,d1  ;display X and Color
    move.l  60(sp),d2  ;display Y
    move.l  #-1,d3  ;display X
    move.l  #0,d4  ;counter X
    move.l  #0,d5  ;counter Y
    move.l  #0,d6  ;row bits
    move.l  #0,d7  ;misc holding
       
    move.l  4(sp),d7
    sub.l   60(sp),d7
    sub.l   52(sp),d7
    move.l  8(sp),d6
    mulu    #4,d6
    mulu    d6,d7
    move.l  48(sp),d0
    mulu    #4,d0
    move.l  52(sp),d1
    mulu    d6,d1
    move.l  d7,d1
    add.l   d1,d0
    move.l  a1,a2
    move.l  a1,a3
    add.l   d0,a2
    add.l   d0,a3
    move.l  60(sp),d5
outerLoopThirtyTwo
    move.l  #-1,d3
    add.l   #-1,d2
    move.l  a3,a2
    add.l   d6,a3
    move.l  56(sp),d4
    sub.l   #1,d5
    cmp     #0,d5
    blt     drawDone
innerLoopThirtyTwo
    add.l   #1,d3
    sub.l   #1,d4
    cmp     #0,d4
    blt     outerLoopThirtyTwo
    ;set color
    move.l  (a2),d1
    cmp.b   #0,d1
    beq     skipThisPixel
    LSR.l   #8,d1
    move.b  #PEN_COLOR_TC,d0
    trap    #15
    ;draw
    move.l  d3,d1
    add.l   64(sp),d1
    add.l   68(sp),d2
    move.b  #DRAW_PIXEL_TC,d0
    trap    #15
    sub.l   68(sp),d2
skipThisPixel 
    add.l   #4,a2
    jmp     innerLoopThirtyTwo

    jmp drawDone
drawDone
    
    add.l   #12,sp
	jsr restoreRegisters
    rts


flipEndian
    move.b  d0,d7
    LSR.l   #8,d0
    LSL.l   #8,d7
    move.b  d0,d7
    LSR.l  #8,d0
    LSL.l   #8,d7
    move.b  d0,d7
    LSR.l   #8,d0
    LSL.l   #8,d7
    move.b  d0,d7   
    rts
    
flipEndianWord
    move.l  #0,d7
    move.b  d0,d7
    LSR.l   #8,d0
    LSL.l   #8,d7
    move.b  d0,d7
    rts
    
errorOffsetNonNegative
    move.l  #13,d0
    lea     offsetNonNegative,a1
    trap    #15
    STOP    #$2000
    
errorOffsetTooHigh
    move.l  #13,d0
    lea     offsetTooHigh,a1
    trap    #15
    STOP    #$2000
    
errorDimensionsNonNegative
    move.l  #13,d0
    lea     dimensionsNonNegative,a1
    trap    #15
    STOP    #$2000
    
errorThirtyTwoBitOnly
    move.l  #13,d0
    lea     thirtyTwoBitOnly,a1
    trap    #15
    STOP    #$2000
    
errorNoColorPallets
    move.l  #13,d0
    lea     noColorPallets,a1
    trap    #15
    STOP    #$2000
    
errorDisplayOutOfBounds
    move.l  #13,d0
    lea     displayOutOfBounds,a1
    trap    #15
    STOP    #$2000

imgBG 
    incbin "board.bmp"
imgRed
    incbin "puckRed.bmp"
imgBlue
    incbin "puckBlue.bmp"
imgYellow
    incbin "puckYellow.bmp"

offsetNonNegative       dc.b 'The image offset must be non-negative',0
offsetTooHigh           dc.b 'The image offset and dimensions go past the bounds of the image',0
dimensionsNonNegative   dc.b 'The image dimensions must both be non-negative',0
thirtyTwoBitOnly        dc.b 'Only 32-bit images are currently supported',0
noColorPallets          dc.b 'Color pallets are not currently supported',0
displayOutOfBounds      dc.b 'Image attempted to render out of display',0

SEGMENT_0       dc.l $7E
SEGMENT_1       dc.l $30
SEGMENT_2       dc.l $6D
SEGMENT_3       dc.l $79
SEGMENT_4       dc.l $33
SEGMENT_5       dc.l $5B
SEGMENT_6       dc.l $5F
SEGMENT_7       dc.l $70
SEGMENT_8       dc.l $7F
SEGMENT_9       dc.l $7B
    
RANDOMVAL       ds.l    1
    
	END START
	
























*~Font name~Courier New~
*~Font size~16~
*~Tab type~1~
*~Tab size~4~
