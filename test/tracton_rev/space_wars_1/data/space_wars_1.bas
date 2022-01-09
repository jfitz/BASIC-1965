10 REM THIS PROGRAM IS THE GAME OF SPACE WARS
20 REM TWO SHIPS BATTLE, YOU MUST DESTROY THE
30 REM ENEMY TO SAVE THE REPUBLIC
40 RANDOMIZE
50 PRINT "ARE INSTRUCTIONS REQUIRED? TYPE EITHER"
60 PRINT "1 OR 0"
70 INPUT A
80 IF A = 1 THEN 120
90 IF A = 0 THEN 250
100 PRINT "INVALID RESPONSE"
110 GOTO 50
120 PRINT
130 PRINT "THERE ARE 5 EXECUTIVE COMMANDS; TURN THE"
140 PRINT "SHIP(1), MOVE(2), FIRE LASER CANNON(3),"
150 PRINT "FIRE LASER(4), AND SELF-DESTRUCT(5)"
160 PRINT "THE CANNON MUST BE FIRED WITH 10 DEGREES"
170 PRINT "OF 90 TO BE EFFECTIVE. NEGATIVE DEG TURNS TOWARDS"
180 PRINT "0 AND POSITIVE DEG TOWARDS 180. ENTERING NEGATIVE KM"
190 PRINT "MOVES YOU TOWARDS THE ENEMY, WHILE POSITIVE MOVES"
200 PRINT "YOU AWAY. LASER EFFECTIVENESS IS RANDOM, DUE TO"
210 PRINT "SHIELDING, DISTANCE, AND INTERSTELLAR DEBRIS"
220 PRINT
230 PRINT "***************GOOD-LUCK***************"
240 PRINT "MAY THE FORCE BE WITH YOU"
250 LET E1 = 1E04
260 LET E2 = E1
270 LET D = 1E03 + INT(5E05*RND)
280 LET B = 1 + INT(180*RND)
290 GOSUB 340
300 GOSUB 390
310 LET E1 = E1 - D1
312 LET X0 = 0
320 GOSUB 500
322 IF X0 <> 0 THEN 1180
330 GOTO 690
340 IF D >= 1E05 THEN 370
350 LET L = 1
360 GOTO 380
370 LET L = 0
380 RETURN
390 IF L = 0 THEN 440
400 LET H2 = (1 + INT(100*RND))/100
410 LET D1 = 500*H2
420 LET E2 = E2 - 500
430 GOTO 490
440 LET M1 = 1 + INT(2*RND)
450 IF M1 = 1 THEN 470
460 GOTO 480
470 LET D1 = 0
480 LET E2 = E2 - 1000
490 RETURN
500 PRINT
510 PRINT "DISTANCE TO ENEMY";D;"KM"
520 PRINT "BEARING IS";B;"DEGREES"
530 IF L = 1 THEN 560
540 PRINT "THE SKY FIGHTER HAS FIRED THE LASER CANNON"
550 GOTO 570
560 PRINT "THE SKY FIGHTER HAS FIRED HIS LASER"
570 PRINT "YOUR TOTAL ENERGY IS NOW";E1;"UNITS"
580 PRINT "THE ENEMY HAS";E2;"UNITS OF ENERGY LEFT"
590 IF E1 <= 0 THEN 620
600 IF E2 <= 0 THEN 650
610 GOTO 680
620 PRINT "YOUR ENERGY LEVEL IS ZERO, THE ENEMY"
630 PRINT "HAS WON, YOU HAVE BECOME ONE WITH THE FORCE!"
640 LET X0 = 1
642 GOTO 680
650 PRINT "THE ENEMY HAS RUN OUT OF ENERGY, YOU"
660 PRINT "HAVE WON"
670 LET X0 = 2
680 RETURN
690 PRINT
700 PRINT "WHICH COMMAND DO YOU WISH TO EXECUTE"
710 INPUT C
720 IF C = 1 THEN 730
721 IF C = 2 THEN 840
722 IF C = 3 THEN 1010
723 IF C = 4 THEN 1100
724 IF C = 5 THEN 1140
725 GOTO 700
730 PRINT "HOW MANY DEGREES OF ROTATION"
740 INPUT B1
750 IF B + B1 < 0 THEN 800
760 IF B + B1 > 180 THEN 820
770 LET B = B + B1
780 LET E1 = E1 - (10*ABS(B1))
790 GOTO 290
800 PRINT "YOUR RESULT ANGLE MUST BE AT LEAST ZERO DEGREES"
810 GOTO 730
820 PRINT "YOUR RESULT ANGLE MUST BE AT MOST 180 DEGREES"
830 GOTO 730
840 PRINT "HOW MANY KM TO TRAVERSE"
850 INPUT K
860 IF D + K < 0 THEN 910
870 IF D + K > 1E6 THEN 960
880 LET D = D + K
890 LET E1 = E1 - (ABS(K)/1000)
900 GOTO 290
910 PRINT "YOU HAVE TRIED TO CLOSE THE DISTANCE TO LESS THAN ZERO"
920 PRINT "BETWEEN YOU AND THE ENEMY, THE ON-BOARD"
930 PRINT "COMMAND COMPUTER WILL NOT EXECUTE THIS MANEUVER"
940 PRINT
950 GOTO 840
960 PRINT "YOU HAVE TRIED TO EXCEED THE DISTANCE WHERE"
970 PRINT "ANY OF YOUR WEAPONS ARE EFFECTIVE"
980 PRINT "THE ON-BOARD COMPUTER WILL NOT"
990 PRINT "EXECUTE THIS MANEUVER"
1000 GOTO 840
1010 LET E1 = E1 - 1000
1020 IF B >= 80 THEN 1050
1030 PRINT "YOUR ANGLE IS TOO SMALL, YOU HAVE MISSED"
1040 GOTO 290
1050 IF B <= 100 THEN 1080
1060 PRINT "YOUR ANGLE IS TOO GREAT, YOU HAVE MISSED"
1070 GOTO 290
1080 LET E2 = E2 - 1000
1090 GOTO 290
1100 LET E1 = E1 - 500
1110 LET D2 = (1 + INT(100*RND)/100)
1120 LET E2 = E2 - (D2*500)
1130 GOTO 290
1140 PRINT "YOU HAVE INSTRUCTED THE ON-BOARD COMPUTER"
1150 PRINT "TO SELF-DESTRUCT, THE REACTOR HAS GONE"
1160 PRINT "CRITICAL, YOU HAVE GONE TO MEET THE FORCE"
1170 IF D <= 500 THEN 1200
1180 PRINT "SPACE WARS IS OVER"
1190 GOTO 1240
1200 PRINT "YOUR DESTRUCTION HAS ALSO DESTROYED"
1210 PRINT "THE SKY FIGHTER, YOU WILL BE REMEMBERED"
1220 PRINT "AS A HERO"
1230 GOTO 1180
1240 PRINT
1250 PRINT "TO PLAY SPACE WARS AGAIN TYPE 1"
1260 PRINT "OTHERWISE TYPE 0"
1270 INPUT Z
1280 IF Z = 1 THEN 1310
1290 PRINT "SPACE WARS SAYS GOOD-BYE"
1300 STOP
1310 PRINT
1320 GOTO 50
1330 END
