100 REM ANGLE-SIDE-ANGLE
110 LET P = 3.14159625
120 DEF FND(X) = X*P/180
130 DEF FNS(X) = SIN(FND(X))
140 PRINT "ANGLE", "SIDE", "ANGLE", "SECOND SIDE", "THIRD SIDE"
150 READ A,X,B
160 LET C = 180 - A - B
170 LET Y = X*FNS(B)/FNS(C)
180 LET Z = X*FNS(A)/FNS(C)
190 PRINT A,X,B,Y,Z
200 GOTO 150
210 DATA 60,5,60, 60,5,90, 15,10,63
220 END
