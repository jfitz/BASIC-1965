10 DIM N(1000)
11 DIM P(350)
20 FOR I = 1 TO 1000
21    LET N(I) = 0
22 NEXT I
25 LET P(0) = 2
26 LET K = 0
30 FOR P = 3 TO 2000 STEP 2
35    LET X = (P-1)/2
40    IF N(X) < 0 THEN 90
50    LET K = K+1
55    LET P(K) = P
56    IF P > SQR(2000) THEN 90
60    FOR I = P TO 2000 STEP 2*P
65       LET X = (I-1)/2
70       LET N(X) = -1
80    NEXT I
90 NEXT P
100 REM READ LEADING DIGITS
110 PRINT "SEARCH FOR PRIMES OF THE FORM A*1000 + B, 0 < B < 2000."
115 PRINT
116 PRINT "A = ";
120 INPUT A
125 LET S = SQR((A+2)*1E3)
130 PRINT
140 PRINT "B = "
150 PRINT
160
200 REM TEST PRIMES TO 2000
205 FOR I = 1 TO 1000
206    LET N(I) = 0
207 NEXT I
210 FOR I = 1 TO K
220    LET F = P(I)
230    GOSUB 800
239    IF Z > 999 THEN 270
240    FOR J = Z TO 999 STEP F
250       LET N(J) = -1
260    NEXT J
270 NEXT I
280
400 REM TEST REMAINING NUMBERS
405 LET D = 2
410 LET F = 2003
420    GOSUB 800
430    IF Z > 999 THEN 450
440    LET N(Z) = -1
450 LET F = F+D
460 LET D = 6-D
470 IF F <= S THEN 420
480
700 REM PRINT RESULT
702 LET S = 0
705 FOR I = 0 TO 999
710    IF N(I) < 0 THEN 730
720    PRINT 2*I + 1;
725    LET S = S+1
730 NEXT I
732 PRINT
733 PRINT
735 PRINT "THERE ARE " S; "PRIMES IN THE RANGE."
740 PRINT
745 PRINT
750 PRINT "TWIN PRIMES:"
752 PRINT
755 FOR I = 0 TO 998
760    IF N(I) < 0 THEN 780
765    IF N(I+1) < 0 THEN 780
770    PRINT 2*I+1, 2*I+3
780 NEXT I
790 STOP
795
800 REM TEST FACTOR F
810 LET X = A - F*INT(A/F)
820 LET Y = A*1E3
830 LET X = F - (Y - F*INT(Y/F))
840 IF X <> 2*INT(X/2) THEN 860
850 LET X = X + F
860 LET Z = (X-1)/2
870 RETURN
999 END

