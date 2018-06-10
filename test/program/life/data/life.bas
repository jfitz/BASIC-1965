100 REM *** INTRO

200 REM *** SET UP BOARD
210 REM *** EMPTY GRID
220 DIM B(10,10)
230 REM *** INITIAL PATTERN
240 LET B(4,4)=1
241 LET B(4,5)=1
242 LET B(4,6)=1

300 REM *** DISPLAY BOARD
310 PRINT "********************"
320 MAT PRINT B;
330 PRINT "********************"
340 PRINT
350 INPUT "CONTINUE (1=YES)", A
360 IF A <> 1 THEN 999

400 REM *** CALCULATE NEIGHBORS
410 DIM B(11,11)
420 MAT N=ZER(10,10)
430 FOR I=1 TO 10
440 FOR J=1 TO 10
442 LET C = 0
450 FOR I0=-1 TO 1
460 FOR J0=-1 TO 1
470 IF ABS(I0)+ABS(J0) = 0 THEN 500
480 IF B(I+I0,J+J0) = 0 THEN 500
490 LET C = C + 1
500 NEXT J0
510 NEXT I0
512 LET N(I,J)=C
520 NEXT J
530 NEXT I
540 DIM B(10,10)

600 REM *** CALCULATE NEW BOARD
610 FOR I=1 TO 10
620 FOR J=1 TO 10
630 IF N(I,J)<2 THEN 660
640 IF N(I,J)=2 THEN 720
650 IF N(I,J)=3 THEN 690
660 REM * CELL DIES
670 LET B(I,J)=0
680 GOTO 730
690 REM * CELL IS BORN
700 LET B(I,J)=1
710 GOTO 730
720 REM * CELL REMAINS UNCHANGED
730 NEXT J
740 NEXT I

800 REM *** NEXT ITERATION
810 GOTO 300

999 END