100 DIM X(100), Y(100), Z(200), T(200)
110
140 READ M, N
150 FOR I = 1 TO M
160    READ X(I)
170 NEXT I
180 FOR J = 1 TO N
190    READ Y(J)
200 NEXT J
210
250 FOR K = 1 TO M
260    LET Z(K) = X(K)
270    LET T(K) = +1
280 NEXT K
290 FOR K = 1 TO N
300    LET Z(M+K) = Y(K)
310    LET T(M+K) = 0
320 NEXT K
330
360 FOR K = 1 TO M+N-1
370    FOR L = K+1 TO M+N
380       IF Z(K) <= Z(L) THEN 450
390       LET T = Z(K)
400       LET Z(K) = Z(L)
410       LET Z(L) = T
420       LET T = T(K)
430       LET T(K) = T(L)
440       LET T(L) = T
450    NEXT L
460 NEXT K
470
500 LET J = 1
510 LET K = 1
520 LET B = J
530 LET T = J
540 LET J = J+1
550 IF J > M+N THEN 600
560 IF Z(J) > Z(B) THEN 600
570 LET T = T+J
580 LET K = K+1
590 GO TO 540
600 FOR L = B TO J-1
610    LET Z(L) = T/K
620 NEXT L
630 IF J <= M+N THEN 510
640
740 LET S(0) = 0
750 LET S(1) = 0
760 FOR K = 1 TO M+N
770    LET S(T(K)) = S(T(K)) + Z(K)
790 NEXT K
800 PRINT "RANK SUM FOR X IS"; S(1), "FOR Y IS"; S(0)
810
900 DATA 6, 4
910 DATA 117, 145, 147, 120, 150, 120
920 DATA 160, 160, 140, 190
999 END
