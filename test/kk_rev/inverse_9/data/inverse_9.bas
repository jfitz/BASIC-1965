10 READ N
20 FOR I = 1 TO N-1
30 FOR J = 1 TO N-1
40 LET P(I,J) = I*J - INT(I*J/N)*N
50 NEXT J
60 NEXT I
70 FOR I = 1 TO N-1
80 FOR J = 1 TO N-1
90 IF P(I,J) = 1 THEN 140
100 NEXT J
110 PRINT I; "DOES NOT HAVE AN INVERSE"
120 NEXT I
130 STOP
140 PRINT I; "HAS AN INVERSE" J
150 GOTO 120
160 DATA 9
999 END

