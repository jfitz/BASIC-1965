1000 REM READ A NUMBER C
1010 FOR I = 0 TO 100
1020     READ X(I)
1030     IF X(I) < 0 THEN 1100
1040 NEXT I
1050 GOTO 1200
1100 LET L = I-1
1110 FOR I = 0 TO L
1120     LET C(I) = X(L-I)
1130 NEXT I
1140 RETURN
1200 PRINT "NUMBER TOO LONG"
1210 STOP
1220
2000 REM PRINT A NUMBER C
2010 IF C(L) >= 100 THEN 2200
2020 PRINT "      ";
2030 IF C(L) >= 10 THEN 2100
2040 PRINT "      ";
2050 PRINT C(L); ",   ";
2060 LET L9 = L-1
2070 GOTO 2210
2100 LET M = INT(C(K)/10)
2110 LET C(L) = C(L) - 10*M
2120 PRINT M;
2130 GOTO 2050
2200 LET L9 = L
2210 FOR I = L9 TO 0 STEP -1
2220     LET N = C(I)
2230     LET Q = 100
2240     FOR J = 1 TO 3
2250         LET M = INT(N/Q)
2260         LET N = N - M*Q
2270         LET Q = Q/10
2280         PRINT M;
2290     NEXT J
2300     IF I = 0 THEN 2400
2310     PRINT ",   ";
2320 NEXT I
2400 PRINT
2405 PRINT
2410 RETURN
2420
3000 REM CARRY IS IN NUMBER C
3010 LET C(L+1) = 0
3020 FOR I = 0 TO L
3030     LET N = C(I)
3040     LET M = INT(N/1000)
3050     LET C(I) = N - 1000*M
3060     LET C(I+1) = C(I+1) + M
3070 NEXT I
3080 IF M = 0 THEN 3100
3090 LET L = L+1
3100 RETURN
3110
9000 DATA 123,456,789,333,-1
9010 DATA 987,654,321,000,-1
9999 END

10   DIM A(100),B(100),C(200),X(100)
100  REM READ, PRINT A,B
110  GOSUB 1000
120  GOSUB 2000
130  FOR I = 0 TO L
140      LET A(I) = C(I)
150  NEXT I
160  LET L1 = L
170  PRINT "TIMES"
180  PRINT
210  GOSUB 1000
220  GOSUB 2000
230  FOR I = 0 TO L
240      LET B(I) = C(I)
250  NEXT I
260  LET L2 = L
270  PRINT "EQUALS"
280  PRINT
290 
300  REM C = A * B
310  LET L = L1+L2
320  FOR I = 0 TO L
330      LET C(I) = 0
340  NEXT I
350  FOR J = 0 TO L1
360      FOR K = 0 TO L2
370          LET I = J+K
380          LET C(I) = C(I) + A(J)*B(K)
390      NEXT K
400  NEXT J
410  GOTO 600
420  LET L = L2
430      FOR I = L1+1 TO L
440  LET A(I) = 0
450  NEXT I
500  FOR I = 0 TO L
510      LET C(I) = A(I) + B(I)
520  NEXT I
530
600  REM CARRY, PRINT ANSWER
610  GOSUB 3000
620  GOSUB 2000
630  STOP
640

