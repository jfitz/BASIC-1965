10 LET N0 = 100
12 DIM T(N0,10), V(N0)
20 FOR I = 0 TO N0
30    READ K
40    IF K <> 999 THEN 48
45    BREAK
48    LET I0 = I
50    LET T(I,0) = K
60    LET K1 = ABS(K)
70    FOR J = 1 TO 2*K1 + 1 - SGN(K1)
80       READ T(I,J)
90    NEXT J
95 NEXT I
99
100 PRINT "SELECTED ACTS: ";
105 FOR I = I0 TO 0 STEP -1
110    LET K = T(I,0)
120    IF K > 0 THEN 200
130    IF K < 0 THEN 300
140    LET V(I) = T(I,1)
150    GOTO 399
200    LET S = 0
210    FOR J = 2 TO 2*K STEP 2
220       LET B = T(I,J)
230       LET S = S + T(I,J-1)*V(B)
240    NEXT J
250    LET V(I) = S
260    GOTO 399
300    LET M = -999999999
310    FOR J = 2 TO 2*ABS(K) STEP 2
320       LET V = V(T(I,J))
330       IF V <= M THEN 360
340       LET M = V
350       LET A = T(I,J-1)
360    NEXT J
370    PRINT A;
380    LET V(I) = M
399 NEXT I
400 PRINT
410 PRINT
420 PRINT "EXPECTED GAIN = $" V(0)
430
900 DATA -3,1,1,2,2,3,3
901 DATA 2,0.5,4,0.5,5
902 DATA 0,0
903 DATA 3,0.333,6,0.167,7,0.5,8
904 DATA 0,100
905 DATA -2,4,9,5,10
906 DATA 2,0.5,11,0.5,12
907 DATA 0,-10
908 DATA 2,0.75,13,0.25,14
909 DATA 3,0.167,15,0.333,16,0.5,17
910 DATA 0,-100
911 DATA 0,90
912 DATA -2,6,18,7,19
913 DATA 0,90
914 DATA -2,8,20,9,21
915 DATA 0,100
916 DATA 0,0
917 DATA 0,-100
918 DATA 3,0.167,22,0.333,23,0.5,24
919 DATA 0,-110
920 DATA 3,0.167,25,0.333,26,0.5,27
921 DATA 0,-110
922 DATA 0,90
923 DATA 0,-10
924 DATA 0,-110
925 DATA 0,90
926 DATA 0,-10
927 DATA 0,-110
998 DATA 999
999 END

