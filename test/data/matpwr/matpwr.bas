10 READ N
20 MAT READ M(N,N)
30 FOR I = 1 TO 4
40 PRINT "POWER : " 2^I
50 MAT LET A = M*M
60 MAT PRINT A
70 MAT LET M = A
80 NEXT I
90 DATA 3
91 DATA 0.5, 0.25, 0.25, 0.5, 0, 0.5, 0.25, 0.25, 0.5
99 END
