10 DIM A(6,5)
20 FOR I = 0 TO 6
30 FOR J = 0 TO 5
40 LET A(I,J) = I*10 + J
50 NEXT J
60 NEXT I
70 PRINT "MATRIX A"
72 MAT PRINT A;
80 MAT B = TRN(A)
90 PRINT "MATRIX B"
92 MAT PRINT B;
100 OPTION BASE 1
170 PRINT "MATRIX A"
172 MAT PRINT A;
180 MAT B = TRN(A)
190 PRINT "MATRIX B"
192 MAT PRINT B;
199 END