100 READ A, B, C, D
110 READ T8, T9, P
140 DATA 4, 2, 1, 3
150 DATA .01, 4, 35
160 LET T1 = 0
170
180 PRINT "TIME", " X", " Y"
190 PRINT
200 READ X, Y
210 PRINT 0, X, Y
220 FOR I = 1 TO P
230 FOR T = 0 TO T9/P STEP T8
240 LET X = X + (A*X - B*X*Y)*T8
250 LET Y = Y + (C*X*Y - D*Y)*T8
255 LET T1 = T1 + T8
260 NEXT T
270 PRINT T1, X, Y
280 NEXT I
290
900 DATA 3,.5
999 END

