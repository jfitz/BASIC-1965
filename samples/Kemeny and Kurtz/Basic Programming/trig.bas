10 LET P = 3.14159625
20 DEF FND(X) = X*P/180
30 DEF FNS(X) = SIN(FND(X))
40 DEF FNC(X) = COS(FND(X))
50 PRINT "DEGREES","SINE","COSINE"
60 FOR X = 0 TO 90 STEP 10
70     PRINT X, FNS(X), FNC(X)
80 NEXT X
99 END

