10 DEF FNF(X,Y) = SQR(X*X + Y*Y)
20
100 READ X0, X1, Y0, H
110 PRINT " X", " Y"
120 PRINT
130 PRINT X0, Y0
140 LET Y = Y0
150
160 FOR X = X0 TO X1-H STEP H
170 LET D1 = FNF(X)
180 LET Y1 = Y
190 LET Y = Y + D1*H/2
200 LET D2 = FNF(X+H/2)
210 LET Y = Y1 + D2*H
220 PRINT X+H, Y
230 NEXT X
240
900 DATA 0, 1, 1
910 DATA 0.1
999 END

