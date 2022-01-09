10 REM THIS PROGRAM GENERATES VIA POLYNOMIAL
20 REM APPROXIMATION THE GAMMA FUNCTION
30 REM AND THE GENERALIZED FACTORIALS
40 LET A = 0.57717
50 LET B = 0.98821
60 LET C = 0.89706
70 LET D = 0.91821
80 LET E = 0.7567
90 LET F = 0.4822
100 LET G = 0.19353
110 LET H = 0.03587
120 PRINT "TYPE 1 FOR GAMMA FUNCTION OR"
130 PRINT "TYPE 2 FOR THE GENERALIZED FACTORIAL"
140 INPUT A
150 IF A = 1 THEN 190
160 IF A = 2 THEN 300
170 PRINT "INVALID RESPONSE"
180 GOTO 120
190 PRINT "ENTER VALUE OF X"
200 INPUT X
210 LET K = X
220 LET K = K - 1
230 IF K > = 0 THEN 260
240 PRINT "X MUST BE EQUAL TO OR GREATER THAN 1"
250 GOTO 190
260 GOSUB 490
270 IF (X - 1) = INT(X - 1) THEN 410
280 GOSUB 570
290 GOTO 410
300 PRINT "ENTER VALUE OF X"
310 INPUT X
320 LET K = X
330 IF K > = 0 THEN 360
340 PRINT "X MUST BE GREATER THAN OR EQUAL TO 0"
350 GOTO 300
360 GOSUB 490
370 IF X = INT(X) THEN 390
380 GOSUB 570
390 PRINT X;"! = ";K
400 GOTO 420
410 PRINT "GAMMA (";X;") = ";K
420 PRINT
430 PRINT "TO CONTINUE TYPE 1, IF NOT TYPE 0"
440 INPUT L
450 IF L = 1 THEN 470
460 STOP
470 PRINT
480 GOTO 120
490 LET J = 1
500 LET J = J*K
510 LET K = K - 1
520 IF K < 1 THEN 540
530 GOTO 500
540 LET L = K
550 LET K = J
560 RETURN
570 LET A1 = 1 + (A*L) + (B*(L^2)) + (C*(L^3))
580 LET A1 = A1 + (D*(L^4)) + (E*(L^5)) + (F*(L^6))
590 LET A1 = A1 + (G*(L^7)) + (H*(L^8))
600 LET K = A1*K
610 RETURN
620 END
