10 PRINT " P", " Q", " R", "FORMULA"
15 PRINT
20 FOR P = 1 TO 0 STEP -1
30     FOR Q = 1 TO 0 STEP -1
40         FOR R = 1 TO 0 STEP -1
50             LET X = P
60             GOSUB 200
70             LET X = Q
80             GOSUB 200
90             LET X = R
95             GOSUB 200
100            LET X = P*SGN(Q+R)
110            GOSUB 200
120            PRINT
130        NEXT R
140    NEXT Q
150 NEXT P
160 STOP
170
200 IF X > 0 THEN 250
210 PRINT "FALSE",
220 RETURN
250 PRINT "TRUE",
260 RETURN
999 END

