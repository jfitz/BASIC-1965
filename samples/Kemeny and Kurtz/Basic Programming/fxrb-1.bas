100 READ A,B,C,D
110 READ T8,T9,P
120 DIM G(60,20)
130 MAT G = ZER
140 DATA 4,2,1,3
150 DATA .01,2,30
160 DEF FNR(X) = INT(4*X+.5)
170
200 READ X,Y
210 LET G(FNR(X*1.5),FNR(Y)) = 1
220 FOR I = 1 TO P
230 FOR T = 0 TO T9/P STEP T8
240 LET X = X + (A*X - B*X*Y)*T8
250 LET Y = Y + (C*X*Y - D*Y)*T8
260 NEXT T
270 LET G(FNR(X*1.5),FNR(Y)) = 1
280 NEXT I
290
300 FOR J = 20 TO 0 STEP -1
310 FOR I = 0 TO 60
320 IF G(I,J) > 0 THEN 360
330 NEXT I
340 PRINT
350 GOTO 470
360 FOR I = 0 TO 60
370 IF G(I,J) > 0 THEN 400
380 PRINT " ";
390 GOTO 450
400 PRINT "*";
410 FOR K = I+1 TO 60
420 IF G(K,J) > 0 THEN 450
430 NEXT K
440 GOTO 460
450 NEXT I
460 PRINT
470 NEXT J
480
900 DATA 3,.5
999 END

