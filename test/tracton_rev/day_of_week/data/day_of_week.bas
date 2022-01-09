10 REM THIS PROGRAM COMPUTES THE DAY OF THE WEEK
20 REM RESTRICTION: THE DATE MUST BE AFTER 1752
100 PRINT "ENTER DAY(D), MONTH(M) AND YEAR(Y)"
110 INPUT D,M,Y
120 IF Y > 1752 THEN 150
130 PRINT "YEAR MUST NOT BE PRIOR TO 1753"
140 GOTO 100
150 LET K = INT(0.6 + (1/M))
160 LET L = Y - K
170 LET O = M + 12*K
180 LET P = L/100
190 LET Z1 = INT(P/4)
200 LET Z2 = INT(P)
210 LET Z3 = INT((5*L)/4)
220 LET Z4 = INT (13*(O + 1)/5)
230 LET Z = Z4 + Z3 - Z2 + Z1 + D - 1
240 LET Z=Z - (7*INT(Z/7)) + 1
250 PRINT "THE DAY OF THE WEEK IS ";
251 GOSUB 400
260 PRINT
270 PRINT "FOR NEXT DATE TYPE IN 1,"
280 PRINT "IF NOT TYPE 0"
290 INPUT L
300 IF L = 1 THEN 340
310 IF L = 0 THEN 360
320 PRINT "INVALID COMMAND"
330 GOTO 270
340 PRINT
350 GOTO 100
360 PRINT "DAY OF THE WEEK SAYS GOOD-BYE"
370 STOP
400 IF Z = 1 THEN 470
410 IF Z = 2 THEN 490
420 IF Z = 3 THEN 510
430 IF Z = 4 THEN 530
440 IF Z = 5 THEN 550
450 IF Z = 6 THEN 570
460 IF Z = 7 THEN 590
470 PRINT "SUNDAY"
480 GOTO 600
490 PRINT "MONDAY"
500 GOTO 600
510 PRINT "TUESDAY"
520 GOTO 600
530 PRINT "WEDNESDAY"
540 GOTO 600
550 PRINT "THURSDAY"
560 GOTO 600
570 PRINT "FRIDAY"
580 GOTO 600
590 PRINT "SATURDAY"
600 RETURN
999 END
