10 REM THIS PROGRAM SIMULATES THEN MECHANICAL
20 REM THREE WHEEL ONE-ARM BANDIT
30 PRINT "ARE INSTRUCTIONS REQUIRED"
40 PRINT "TYPE EITHER YES OR NO"
50 INPUT L$
60 IF L$ = "YES" THEN 100
70 IF L$ = "NO" THEN 170
80 PRINT "INVALID COMMAND"
90 GOTO 30
100 PRINT "SCORING IS SIMPLE; 3 ORANGES, LEMONS OR"
110 PRINT "BANANAS EARN $10. 3 CHERRIES EARN $90."
120 PRINT "IF THE FIRST FRUIT IS AN APPLE YOU EARN #$2"
130 PRINT "IF THE 1ST AND 2ND ARE APPLES YOU EARN $3"
140 PRINT "IF THE LAST FRUIT IS A CHERRY AND THE"
150 PRINT "OTHER TWO ARE THE SAME BUT NOT APPLES YOU"
160 PRINT "EARN $10. EACH TURN COSTS $1. GOOD-LUCK"
170 LET J = 0
180 PRINT
190 GOSUB 590
200 LET S1 = S
210 GOSUB 590
220 LET S2 = S
230 GOSUB 590
240 LET S3 = S
250 LET S = S1
260 GOSUB 610
270 LET S1$ = S$
280 LET S = S2
290 GOSUB 610
300 LET S2$ = S$
310 LET S = S3
320 GOSUB 610
330 LET S3$ = S$
340 IF S1$ = "CHERRY" THEN 380
350 IF S1$ = "APPLE" THEN 420
360 IF S1$ = S2$ THEN 440
370 GOTO 460
380 IF S1$ = S2$ THEN 400
390 GOTO 460
400 IF S2$ = S3$ THEN 480
410 GOTO 460
420 IF S1$ = S2$ THEN 500
430 GOTO 520
440 IF S2$ = S3$ THEN 540
450 IF S3$ = "CHERRY" THEN 540
460 LET J = J - 1
470 GOTO 550
480 LET J = J + 89
490 GOTO 550
500 LET J = J + 2
510 GOTO 550
520 LET J = J + 1
530 GOTO 550
540 LET J = J + 9
550 PRINT
560 PRINT S1$;" ";S2$;" ";S3$
570 PRINT "YOUR EARNINGS ARE NOW $";J
580 GOTO 720
590 LET S = 1 + INT(5*RND)
600 RETURN
610 ON S GOTO 620, 640, 660, 680, 700
620 LET S$ = "CHERRY"
630 GOTO 710
640 LET S$ = "APPLE"
650 GOTO 710
660 LET S$ = "LEMON"
670 GOTO 710
680 LET S$ = "ORANGE"
690 GOTO 710
700 LET S$ = "BANANA"
710 RETURN
720 PRINT
730 PRINT "TO CONTINUE TYPE Y, IF NOT TYPE N"
740 INPUT Z$
750 IF Z$ = "Y" THEN 780
760 PRINT "ONE-ARM BANDIT SAYS GOOD-BYE"
770 STOP
780 PRINT
790 GOTO 190
800 END
