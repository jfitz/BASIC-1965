110 READ M,N
120 FOR I = 1 TO M
130    LET S = 0
140    FOR J = 1 TO N
150       READ O(I,J)
160       LET S = S + O(I,J)
170    NEXT J
180    LET R(I) = S
190 NEXT I
200
210 LET S1 = 0
220 FOR J = 1 TO N
230    LET S = 0
240    FOR I = 1 TO M
250       LET S = S + O(I,J)
260    NEXT I
270    LET C(J) = S
280    LET S1 = S1 + S
290 NEXT J
300
310 PRINT
320 LET C = 0
330 FOR I = 1 TO M
340    FOR J = 1 TO N
350       LET E = R(I)*C(J)/S1
360       LET C = C + (O(I,J) - E)^2/E
370       PRINT O(I,J),
380    NEXT J
390    PRINT
400 NEXT I
410 PRINT
420 PRINT "CHI-SQUARE EQUALS";C;"ON";(M-1)*(N-1);"DEGREES OF FREEDOM"
430
900 DATA 3,2
910 DATA 17,42,50,50,114,61
999 END
