100 MAT A = ZER(3,3)
110 MAT B = CON(3,3)
120 MAT C = IDN(3,3)
130
200 PRINT "ALL ZEROES"
210 MAT PRINT A;
220 PRINT "ALL ONES"
230 MAT PRINT B;
240 PRINT "IDENTITY MATRIX"
250 MAT PRINT C;
260
300 MAT READ A
310 PRINT "SQUARE MATRIX"
320 MAT PRINT A
330 MAT B = INV(A)
340 PRINT "ITS INVERSE"
350 MAT PRINT B
360
400 MAT R = A*B
410 MAT R = R-C
420 PRINT "ROUNDOFF ERRORS"
430 MAT PRINT R
440
900 DATA 1, 0.5, 0.333333, 0.5, 0.333333, 0.25, 0.333333, 0.25, 0.5
999 END

