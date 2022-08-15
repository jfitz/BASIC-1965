10 DIM S(4,100), P(6,6), M(100)
20 DEF FNC(X) = X-7*INT(X/7)
30 PRINT "NOTE NUMBER", "CHORD",
40 PRINT " S     A     T     B"
50 PRINT
60
100 REM  INITIALIZE.
105 OPTION BASE 1
110 MAT READ P
111 DATA 5,4,1,6,2,3, 6,4,2,1,5,3, 6,4,3,1,2,5
112 DATA 1,5,4,6,3,2, 2,6,5,4,1,3, 1,5,3,6,2,4
120 READ N9
130 MAT READ M(N9)
140 DATA 28
150 DATA 2,1,0,2,1,0,7,5,7,4,2,0,1
160 DATA 2,1,0,2,1,0,7,5,7,4,2,0,1,1,0
170 OPTION BASE 0
190 FOR V = 0 TO 4
200    READ S(V,N9)
210 NEXT V
220 DATA 1,0,-3,-5,-7
240 LET C2 = 1
250
450 FOR N = N9 TO 1 STEP -1
460 IF N = N9 THEN 6000
500 REM  TEST CHORDS.
505 LET I1 = 1
510 FOR I = I1 TO 6
520 LET C2 = P(C1,I)
525 LET S(0,N) = C2
530 LET S = M(N)
540 LET S(1,N) = S
542
545 REM  FIX ROOT
550 LET D(1) = C2-8
560 LET D(2) = C2-15
565 LET D = S(4,N+1)
570 FOR J = 1 TO 2
580 IF ABS(D(J)-D) <= 5 THEN 610
590 LET R = D(3-J)
600 BREAK
610 NEXT J
611 IF BROKEN THEN 660
620 IF S > S(1,N+1) THEN 650
630 LET R = D(1)
640 GOTO 660
650 LET R = D(2)
660 LET S(4,N) = R
670
700 REM  FIND OTHER NOTES
705 LET J = 1
710 FOR K = 0 TO 4 STEP 2
720 IF FNC(S-(R+K))=0 THEN 750
730 LET B(J) = R+K
740 LET J = J+1
750 NEXT K
760 IF J > 3 THEN 4000
770
800 FOR L = 0 TO 6
810 LET A = B(1)
820 LET B = B(2)
830 LET W(0,L) = 0
840 LET W(2,L) = B
850 LET W(3,L) = A
860 LET B(1) = B
870 LET B(2) = A+7
880 NEXT L
899
1000 REM  TEST CASES IN W-TABLE
1010 FOR L = 0 TO 6
1020 FOR V = 2 TO 3
1030 LET B = W(V,L)
1040 IF ABS(B-S(V,N+1)) <= 5 THEN 1050
1049 BREAK
1050 IF B <= 17-4*V THEN 1060
1059 BREAK
1060 IF B >= 5-4*V THEN 1070
1069 BREAK
1070 LET S(V,N) = B
1080 IF S(2*V-3,N) > S(2*V-2,N) THEN 1090
1089 BREAK
1090 NEXT V
1091 IF BROKEN() THEN 1260
1095
1100 REM  CHECK FOR BAD TRANSITIONS
1102 IF C1 = C2 THEN 1200
1105 FOR V1 = 1 TO 4
1110 FOR V2 = V1+1 TO 4
1115 LET D = S(V1,N+1)-S(V2,N+1)
1120 IF FNC(D) = 0 THEN 1145
1130 IF FNC(D) = 4 THEN 1145
1140 CONTINUE
1145 LET S1 = S(V1,N)-S(V1,N+1)
1150 LET S2 = S(V2,N)-S(V2,N+1)
1155 IF S1 <> S2 THEN 1160
1159 BREAK
1160 NEXT V2
1161 IF BROKEN() = FALSE THEN 1165
1164 BREAK
1165 NEXT V1
1166 IF BROKEN() THEN 1260
1170
1200 REM COMPUTE DISTANCE
1210 FOR V = 2 TO 3
1220 LET D(V) = ABS(S(V,N)-S(V,N+1))
1230 NEXT V
1240 LET W(0,L) = D(2)+D(3)
1250 GOTO 1261
1260 LET W(0,L) = 999
1261 NEXT L
1262
1500 REM  SELECT CHORD
1510 LET M = 999
1520 FOR L = 0 TO 6
1530 LET M1 = W(0,L)
1540 IF M1 > M THEN 1590
1550 LET M = M1
1560 LET L9 = L
1590 NEXT L
1600 IF M = 999 THEN 4000
1610 LET S(2,N) = W(2,L9)
1620 LET S(3,N) = W(3,L9)
1630 BREAK
1640
4000 REM  REJECT CHORD
4001 NEXT I
4002 IF BROKEN() THEN 6000
5000 REM  BACK UP
5005 LET N = N+1
5010 IF N <> N9 THEN 5100
5020 PRINT "STUCK"
5030 STOP
5100 LET C2 = S(0,N)
5110 LET C1 = S(0,N+1)
5120 FOR I = 1 TO 6
5130 IF C2 <> P(C1,I) THEN 5140
5139 BREAK
5140 NEXT I
5141 IF BROKEN() THEN 5200
5200 LET I1 = I+1
5210 GOTO 510
5220
6000 REM  PRINT RESULTS
6001 PRINT N, S(0,N), S(1,N);S(2,N);S(3,N);S(4,N)
6002 LET C1 = C2
6003 NEXT N
6004
9999 END

