10 REM THIS PROGRAM COMPUTES THE DAY OF THE WEEK
20 REM RESTRICTION: THE DATE MUST BE AFTER 1752
30 LET J$(1) = "SUNDAY"
40 LET J$(2) = "MONDAY"
50 LET J$(3) = "TUESDAY"
60 LET J$(4) = "WEDNESDAY"
70 LET J$(5) = "THURSDAY"
80 LET J$(6) = "FRIDAY"
90 LET J$(7) = "SATURDAY"
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
250 PRINT "THE DAY OF THE WEEK IS ";J$(Z)
260 PRINT
270 PRINT "FOR NEXT DATE TYPE IN YES, IF NOT"
280 PRINT "TYPE NO"
290 INPUT L$
300 IF L$ = "YES" THEN 340
310 IF L$ = "NO" THEN 360
320 PRINT "INVALID COMMAND"
330 GOTO 270
340 PRINT
350 GOTO 30
360 PRINT "DAY OF THE WEEK SAYS GOOD-BYE"
370 END