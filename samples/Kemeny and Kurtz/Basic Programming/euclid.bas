10 PRINT " A", " B", "G.C.D."
20 READ A,B
30 PRINT A,B,
40 LET Q = INT(A/B)
45 LET R = A - Q*B
50 LET A = B
55 LET B = R
60 IF R > 0 THEN 40
70 PRINT A
80 GOTO 20
90 DATA 130,169, 243,256, 123456789,987654321
99 END

