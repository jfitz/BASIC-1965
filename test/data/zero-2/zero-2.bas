10 DEF FNF(X) = X^5 + 2*X^3 -1
11 REM DEF FNF(X) = -3*X^5 + X^3 + 1
20 READ A,B
25 IF FNF(A) > 0 THEN 230
30 LET X = (A+B)/2
40 IF FNF(A) = 0 THEN 100
50 IF FNF(A) < 0 THEN 70
60 LET B = X
65 GOTO 80
70 LET A = X
80 IF ABS(A-B)/(ABS(A)+ABS(B)) < 0.0000005 THEN 100
90 GOTO 30
100 PRINT "ONE ZERO AT" X
110 STOP
120
230 LET X = (A+B)/2
240 IF FNF(X) = 0 THEN 100
250 IF FNF(X) < 0 THEN 270
260 LET A = X
265 GOTO 280
270 LET B = X
280 IF ABS(A-B)/(ABS(A)+ABS(B)) < 0.0000005 THEN 100
290 GOTO 230
300
900 DATA 0,1
999 END

