10 REM TEST FOR PRECISION OPTION
100 PRINT "VALUES WITH PRECISION 7"
110 OPTION PRECISION 7
120 LET A = 1/7
130 FOR I = 1 TO 10
140 PRINT A
150 LET A = A / 10
160 NEXT I
200 PRINT "VALUES WITH PRECISION 16"
210 OPTION PRECISION 16
220 LET A = 1/7
230 FOR I = 1 TO 12
240 PRINT A
250 LET A = A / 10
260 NEXT I
999 END