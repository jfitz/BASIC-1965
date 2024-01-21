100 REM THIS PROGRAM PLAYS THREE-PILE NIM, WITH RANDOM NUMBERS
110 REM IN EACH PILE. PLAYER WHO CLEARS BOARD WINS.
120
130 REM INITIALIZE
140 FOR P = 1 TO 3
150    LET N(P) = INT(10*RND(0))+6
160 NEXT P
170 PRINT "INITIAL CONFIGURATION:"
180 PRINT
190 GOSUB 900
200
210 REM OPPONENT'S MOVE
220 PRINT "PILE, NUMBER TAKEN";
230 INPUT P, N
240 LET N(P) = N(P) - N
250 IF N(P) >= 0 THEN 300
260 PRINT "ILLEGAL MOVE"
270 LET N(P) = N(P) + N
280 PRINT
290 GOTO 200
300 IF N(1)+N(2)+N(3) > 0 THEN 370
310 PRINT
320 PRINT "YOU WIN *****"
330 PRINT
340 PRINT
350 GOTO 140
360
370 REM SET UP BIT-PATTERNS
380 FOR P = 1 TO 3
390    LET X = N(P)
400    FOR J = 4 TO 1 STEP -1
410       LET Y = INT(X/2)
420       LET B(P,J) = X - 2*Y
430       LET X = Y
440    NEXT J
450 NEXT P
460
470 REM FIND COLUMN PARITIES
480 FOR J = 1 TO 4
490    LET S(J) = B(1,J) + B(2,J) + B(3,J)
500    LET S(J) = S(J) - 2*INT(S(J)/2)
510 NEXT J
520
530 REM IF ALL EVEN, MAKE RANDOM MOVE
540 IF S(1)+S(2)+S(3)+S(4) > 0 THEN 610
550 FOR P = 1 TO 3
560    IF N(P) = 0 THEN 590
570    LET N = INT(N(P)*RND(0)) + 1
580    BREAK
590 NEXT P
591 IF BROKEN() THEN 770
600
610 REM MAKE OPTIMAL MOVE
618 OPTION FORGET_FORNEXT FALSE
620 FOR J = 1 TO 4
630    IF S(J) <= 0 THEN 640
639    BREAK
640 NEXT J
642 OPTION FORGET_FORNEXT
650 FOR P = 1 TO 3
660    IF B(P,J) <> 1 THEN 670
669    BREAK
670 NEXT P
680 LET N = 0
690 FOR J = J TO 4
700    IF S(J) = 0 THEN 750
710    IF B(P,J) = 0 THEN 740
720    LET N = N + 2^(4-J)
730    GOTO 750
740    LET N = N - 2^(4-J)
750 NEXT J
760
770 REM CARRY OUT MOVE
780 PRINT
790 PRINT "MY MOVE:" P; "," N
800 PRINT
810 LET N(P) = N(P) - N
820 IF N(1)+N(2)+N(3) > 0 THEN 850
830 PRINT "I WIN *****"
840 GOTO 330
850 PRINT "NEW CONFIGURATION:"
860 PRINT
870 GOSUB 900
880 GOTO 210
890
900 REM PRINT CONFIGURATION
910 FOR P = 1 TO 3
920    PRINT "PILE " P; N(P)
930 NEXT P
940 PRINT
950 PRINT
960 RETURN
970 END

