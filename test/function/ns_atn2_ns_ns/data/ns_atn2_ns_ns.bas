10 REM TEST ARCTAN 2 ARGS
20 PRINT "Y","X","ARCTAN"
30 READ Y,X
40 IF X+Y = X*Y THEN 99
54 LET A = ATN(Y,X)
56 PRINT Y, X, A
60 GOTO 30
90 DATA -0,-1, -1,-1, -1,0, -1,1, 0,1, 1,1, 1,0, 1,-1, 0,0
99 END
