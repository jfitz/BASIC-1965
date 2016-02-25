100 REM ANGLE-SIDE-SIDE
110 LET P = 3.14159265
120 DEF FND(X) = X*P/180
130 DEF FNS(X) = SIN(FND(X))
135 DEF FNR(X) = INT(100*X+.5)/100
140 PRINT "ANGLE", "SIDE", "SIDE", "THIRD SIDE", "CASE 2"
150 READ B,X,Y
160 PRINT B,X,Y,
170 LET S = X*FNS(B)/Y
180 IF S > 1 THEN 290
190 IF S = 1 THEN 320
195
200 REM TWO POINTS OF INTERSECTION
210 LET T = S/SQR(1-S^2)
220 LET C = ATN(T)*180/P
230 LET A = 180 - B - C
240 GOSUB 370
250 LET C = 180 - C
260 LET A = 180 - B - C
270 GOSUB 370
275 PRINT
280 GOTO 150
285
290 REM NO POINT OF INTERSECTION
300 PRINT "NONE", "NONE"
310 GOTO 150
315
320 REM ONE POINT OF INTERSECTION
330 LET A = 90 - B
340 GOSUB 370
350 PRINT "NONE"
360 GOTO 150
365
370 REM ANGLE-SIDE-ANGLE ROUTINE
380 LET Z = X*FNS(A)/S
390 IF Z >= 0 THEN 420
400 PRINT "NONE",
410 RETURN
420 PRINT Z,
430 RETURN
440
450 DATA 60,10,8, 60,10,9, 60,10,11, 120,10,8, 120,10,9
460 DATA 120,10,11, 90,3,5, 60,5,5, 30,10,5
470 END
