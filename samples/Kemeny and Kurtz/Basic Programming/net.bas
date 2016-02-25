100 DEF FNR(X)=INT(X*1E3+0.5)/1E3
110 DIM C(20,20), U(20,20), B(20), P(20)
120 READ N,V
130 MAT C = ZER(N,N)
150 MAT B = ZER(N)
170 LET C(1,1) = 1
180 LET C(N,N) = 1
190 LET B(1) = V
200
210 READ I,J,R
220 IF I = -1 THEN 270
230 LET C(I,J) = 1/R
240 LET C(J,I) = 1/R
250 GOTO 210
260
270 FOR I = 2 TO N-1
280 LET S = 0
290 FOR J = 1 TO N
300 LET S = S+C(I,J)
310 NEXT J
320 LET C(I,I) = -S
330 LET C(1,I) = 0
340 LET C(N,I) = 0
350 NEXT I
360
370 MAT U = INV(C)
380 MAT P = U*B
390
400 PRINT "NODE", "VOLTAGE"
410 PRINT
420 FOR I = 1 TO N
430 PRINT I, FNR(P(I))
440 NEXT I
450 PRINT
460 PRINT
470
480 PRINT "CURRENT FLOW"
490 PRINT
500 LET S1 = 0
510 FOR I = 2 TO N-1
520 PRINT "NODE" I
530 FOR J = 1 TO N
540 PRINT FNR(C(I,J)*(P(I)-P(J))),
550 NEXT J
560 LET S1 = S1 + C(I,N)*(P(I)-P(N))
570 PRINT
580 PRINT
590 NEXT I
600 PRINT
610
620 PRINT "TOTAL CURRENT = " FNR(S1)
630 PRINT "RESISTANCE OF CIRCUIT = " FNR(V/S1)
640
650 DATA 7,24
660 DATA 1,2,100, 2,7,50, 2,3,25, 1,4,16, 3,4,20, 3,6,40
670 DATA 4,5,60, 5,6,60, 6,7,40
680 DATA -1,0,0
690 END
