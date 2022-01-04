10 REM THIS PROGRAM COMPUTES THE PERCENTAGES OF THE
20 REM PRODUCTS PRODUCED BY HYDROCARBON COMBUSTION
30 PRINT "FOR INSTRUCTIONS TYPE YES, IF NOT TYPE NO"
40 INPUT I$
50 IF I$ = "YES" THEN 90
60 IF I$ = "NO" THEN 130
70 PRINT "INVALID COMMAND"
80 GOTO 30
90 PRINT "THE AMOUNTS OF EACH ELEMENT MUST BE"
100 PRINT "ENTERED, EVEN IF THE AMOUNT IS ZERO"
110 PRINT "EXAMPLE: - METHANE (CH4) MUST BE ENTERED AS"
120 PRINT "C;1, H:4, O:0, S:0, N:0"
130 PRINT
140 PRINT "ENTER CARBON(C), HYDROGEN(H), OXYGEN(O)"
150 PRINT "SULPHUR(S), NITROGEN(N) IN THAT ORDER"
160 INPUT C,H,O,S,N
170 PRINT "ENTER PERCENTAGE EXCESS AIR, IF ZERO"
180 PRINT "ENTER 0. EXAMPLE: - 34% ENTER AS 34"
190 INPUT E
200 LET E = 1 + (E/100)
210 LET O2 = C + S + (H/4) - (O/2)
220 LET A = O2*E*4.762
230 LET A1 = 1.8094*A
240 LET F = (0.7507*C) + (0.063*H) + (2.004*S)
250 LET F = (0.875*N) + O + F
260 LET A1 = A1/F
270 LET M = A + (H/4) + (O/2) + (N/2)
280 LET C2 = (C*100)/M
290 LET S2 = (S*100)/M
300 LET H2 = (H*100)/M
310 LET O3 = (100*(E-1)*O2)/M
320 LET N2 = (100*((3.762*E*O2) + (N/2)))/M
330 PRINT
340 PRINT "AIR-FUEL RATIO WITH RESPECT TO MOLES = ";A
350 PRINT "AIR-FUEL RATIO WITH RESPECT TO MASS = ";A1
360 PRINT "TOTAL MOLES OF PRODUCT = ";M
370 PRINT "*****PERCENTAGE VOLUME OF PRODUCTS*****"
380 PRINT "CARBON DIOXIDE = ";C2;"%"
390 PRINT "SULPHUR DIOXIDE = ";S2;"%"
400 PRINT "WATER = ";H2;"%"
410 PRINT "OXYGEN = ";O3;"%"
420 PRINT "NITROGEN = ";N2;"%"
430 PRINT "*****COMPLETE COMBUSTION ASSUMED*****"
440 PRINT
450 PRINT "TO TRY NEXT COMPOUND TYPE YES"
460 PRINT "TO STOP TYPE NO"
470 INPUT L$
480 IF L$ = "YES" THEN 510
490 PRINT "COMBUSTION SAYS GOOD-BYE"
500 STOP
510 PRINT
520 GOTO 30
530 END
