10 REM MATRIX ASSIGNMENT
20 DIM A(2,3), B(3)
30 DATA 1,2,3,4,5,6
40 DATA 7,8,9
100 FOR I = 1 TO 2
110 FOR J = 1 TO 3
120 READ A(I,J)
130 NEXT J
140 NEXT I
150 PRINT "MATRIX A"
160 MAT PRINT A;
200 FOR I = 1 TO 3
220 READ B(I)
240 NEXT I
250 PRINT "MATRIX B"
260 MAT PRINT B;
300 MAT LET C = A*B
310 PRINT "MATRIX C"
320 MAT PRINT C;
999 END
