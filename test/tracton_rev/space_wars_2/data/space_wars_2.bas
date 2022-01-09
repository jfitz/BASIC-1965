10 REM THIS COMPUTER SIMULATION IS AN ADVANCED VERSION OF
20 REM THE SPACE WARS GAME. YOU MISSION IS TO DESTROY THE
30 REM DEATH STAR. YOU MAY BE ATTACKED BY THE DEATH STAR'S
40 REM DEFENSES AND BY THE SKY FIGHTERS
50 RANDOMIZE
60 PRINT "ARE INSTRUCTIONS FOR SPACE WARS REQUIRED? TYPE"
70 PRINT "EITHER 1 OR 0"
80 INPUT A
90 IF A = 1 THEN 130
100 IF A = 0 THEN 540
110 PRINT "YOU HAVE ISSUED AN INVALID RESPONSE"
120 GOTO 60
130 PRINT
140 PRINT "***************SPACE WARS***************"
150 PRINT "THE DEATH STAR SPACE STATION, YOUR GOAL, IS HEAVILY"
160 PRINT "SHIELDED AND MOUNTS MORE FIREPOWER THAN HALF"
170 PRINT "THE IMPERIAL FLEET. BUT, ITS DEFENSES WERE"
180 PRINT "PRIMARILY DESIGNED TO FEND OFF LARGE-SCALE CAPITAL"
190 PRINT "SPACE-SHIP ASSAULTS. A SMALL, ONE- OR TWO-MAN"
200 PRINT "X-WING FIGHTER SHOULD BE ABLE TO SLIP THROUGH"
210 PRINT "ITS DEFENSIVE SCREENS. YOUR MISSION, IS TO DESTROY"
220 PRINT "THE DEATH STAR!!! ON ITS SURFACE THERE IS A SMALL"
230 PRINT "THERMAL EXHAUST PORT. ITS SIZE BELIES ITS IMPORTANCE"
240 PRINT "AS IT APPEARS TO BE AN UNSHIELDED SHAFT THAT RUNS"
250 PRINT "DIRECTLY INTO THE MAIN REACTOR SYSTEM, POWERING"
260 PRINT "THE DEATH STAR SPACE STATION. SINCE THIS SERVES"
270 PRINT "AS AN EMERGENCY OUTLET FOR WASTE HEAT IN THE"
280 PRINT "EVENT OF REACTOR OVERPRODUCTION, ITS USEFULNESS"
290 PRINT "WOULD BE ELIMINATED BY ENERGY-PARTICLE SHIELDING"
300 PRINT "A DIRECT HIT WOULD INITIATE A CHAIN REACTION THAT"
310 PRINT "WOULD DESTROY THE STATION, THUS PROTECTING THE"
320 PRINT "REPUBLIC"
330 PRINT "**********EXECUTIVE COMMANDS ARE**********"
340 PRINT "(1) FIRE HIGH-ENERGY TORPEDO"
350 PRINT "(2) FIRE LASER CANNON"
360 PRINT "(3) FIRE LASER"
370 PRINT "(4) PROPULSION OF X-WING"
380 PRINT "THE BATTLE COMPUTER OPTION MAY BE USED WITH COMMANDS"
390 PRINT "2 AND 3. THE ENERGY TORPEDO IS USED TO DESTROY"
400 PRINT "THE DEATH STAR WITH, EACH TORPEDO EXPENDS 20,000"
410 PRINT "UNITS OF ENERGY. THE LASER CANNON MAY BE USED"
420 PRINT "AGAINST THE SKY FIGHTERS, IT REQUIRES 5,000 UNITS"
430 PRINT "THE LASER USES 1,000 ENERGY UNITS PER SHOT AND IT"
440 PRINT "IS ALSO USED AGAINST THE SKY FIGHTERS."
450 PRINT "THE BATTLE COMPUTER REQUIRES 500 ENERGY UNITS, BUT,"
460 PRINT "GUARANTEES A DIRECT HIT ON A SKY FIGHTER. TO DESTROY"
465 PRINT "A SKY FIGHTER YOU MUST DEPLETE IT OF ENERGY."
470 PRINT "MOVING THE X-WING SPACE CRAFT IS IMPERATIVE AS"
480 PRINT "THE ENERGY TOPEDO MUST BE FIRED WITHIN 1000KM"
490 PRINT "OF THE DEATH STAR. X-WING PROPULSION REQUIRES"
500 PRINT "1 ENERGY UNIT PER KM"
510 PRINT "****************************************"
520 PRINT "GOOD-LUCK"
530 PRINT "MAY THE FORCE BE WITH YOU"
535 PRINT "****************************************"
536 REM X-WING ENERGY AND SKY ENERGY
540 LET X1 = 5E05
550 LET T1 = 1E04
560 LET T2 = 5E04
570 LET D = 1E05
578 LET X0 = 0
580 GOSUB 630
590 GOSUB 730
600 GOSUB 840
610 GOSUB 1040
612 IF X0 <> 0 THEN 2690
620 GOSUB 1500
622 IF X0 <> 0 THEN 2690
625 GOTO 580

630 IF D > 1E04 THEN 660
640 LET L = 1
650 GOTO 700
660 LET L = 0
670 LET H = (1 + INT(100*RND)/100)
680 LET E1 = 5000*H
690 GOTO 720
700 LET H = (1 + INT(100*RND)/100)
710 LET E1 = 1000*H
720 RETURN

730 IF D > 5E03 THEN 760
740 LET K = 1
750 GOTO 800
760 LET K = 0
770 LET H = (1 + INT(100*RND)/100)
780 LET E2 = 8000*H
790 GOTO 820
800 LET H = (1 + INT(100*RND)/100)
810 LET E2 = 3000*H
820 RETURN

840 IF D < 3E03 THEN 860
850 LET E3 = 0
860 LET H = (1 + INT(100*RND)/100)
870 LET E3 = 2E04*H
880 LET T1 = T1 - E1
890 LET T2 = T2 - E2
900 IF T1 <= 0 THEN 920
910 GOTO 950
920 LET E1 = 0
930 LET Y = 1
940 GOTO 960
950 LET Y = 0
960 IF T2 <= 0 THEN 980
970 GOTO 1010
980 LET E2 = 0
990 LET Z = 1
1000 GOTO 1020
1010 LET Z = 0
1020 LET X1 = X1 - E1 - E2 - E3
1030 RETURN

1040 PRINT "DISTANCE TO DEATH STAR IS NOW";D;"KM"
1045 IF Y = 1 THEN 1100
1050 IF L = 0 THEN 1080
1060 PRINT "THE SKY FIGHTER HAS FIRED HIS LASER"
1070 GOTO 1110
1080 PRINT "THE SKY FIGHTER HAS FIRED HIS LASER CANNON"
1090 GOTO 1110
1100 PRINT "THE SKY FIGHTER IS OUT OF ACTION!!!"
1110 IF Z = 1 THEN 1180
1120 GOTO 1220
1130 IF K = 0 THEN 1160
1140 PRINT "THE DARK LORD HAS FIRED HIS HIGH ENERGY LASER"
1150 GOTO 1360
1160 PRINT "THE SMITH LORD HAS USED A LASER CANNON ENERGY BEAM"
1170 GOTO 1360
1180 PRINT "GARTH RADER HAS EXPENDED ALL HIS WEAPON'S ENERGY"
1190 PRINT "SUPPLY. HE IS CURRENTLY ESCAPING TO THE ENDS OF"
1200 PRINT "THE GALAXY. ***THE FORCE IS WITH YOU***"
1210 GOTO 1360
1220 LET C = 1 + (5*RND)
1230 ON C GOTO 1240, 1270, 1290, 1330
1240 PRINT "*CAUTION*GARTH RADER IS THE BEST SHOT IN THE"
1250 PRINT "IMPERIAL FLEET, PLUS HE USES THE BAD SIDE OF THE FORCE"
1260 GOTO 1130
1270 PRINT "THE DARK LORD IS EXTREMELY DANGEROUS!!!"
1280 GOTO 1130
1290 PRINT "**CAUTION RADER IS INHUMANLY ACCURATE CAUTION**"
1300 GOTO 1130
1310 PRINT "THE SMITH LORD'S PRECISION IS AWESOME"
1320 GOTO 1130
1330 PRINT "RADER'S ON-BOARD ATTACK COMPUTER HAS MATCHED"
1340 PRINT "YOUR COURSE, HIS WEAPONS ARE READY"
1350 GOTO 1130
1360 IF D <= 3E03 THEN 1380
1370 GOTO 1410
1380 PRINT "YOU ARE CLOSER THAN 3000KM TO THE SPACE STATION"
1390 PRINT "THE DEATH STAR'S AUTOMATIC DEFENSE NETWORK HAS BEEN"
1400 PRINT "ACTIVATED. ***USE EXTREME CAUTION***"
1410 PRINT
1415 PRINT "YOUR TOTAL ENERGY IS NOW";X1;"UNITS"
1420 IF X1 < 2E04 THEN 1440
1430 GOTO 1490
1440 PRINT "YOU HAVE DEPLETED YOUR ENERGY SUPPLY, THE DEATH"
1450 PRINT "STAR WILL NOW DESTROY YOUR HOME PLANET"
1460 PRINT "YOU WILL BE A HERO NOWHERE AND REMEMBERED BY NONE"
1470 PRINT "*****YOU HAVE MISUSED THE FORCE*****"
1480 LET X0 = 2
1490 RETURN

1500 PRINT
1510 PRINT "WHICH COMMAND DO YOU WISH TO EXECUTE"
1520 INPUT B
1530 ON B GOTO 1540, 1690, 2030, 2320

1540 IF D <= 1000 THEN 1590
1550 PRINT "YOU HAVE WASTED A TORPEDO, YOU ARE FARTHER"
1560 PRINT "AWAY THAN 1000KM"
1570 LET X1 = X1 - 2E04
1580 GOTO 2680
1590 LET H = 1 + (INT(100*RND))
1600 IF H > 50 THEN 1640
1610 PRINT "YOU SHOULD HAVE USED THE FORCE, YOU HAVE MISSED"
1620 LET X1 = X1 - 2E04
1630 GOTO 2680
1640 PRINT "THE FORCE WAS WITH YOU, YOU HAVE SINGLE-HANDED"
1650 PRINT "DESTROYED THE DEATH STAR. YOU HAVE SAVED THE"
1660 PRINT "REPUBLIC AND PRINCESS LEAH ARGONA WILL LOVE YOU"
1670 PRINT "FOREVER."
1680 LET X0 = 3
1682 RETURN

1690 PRINT "THE CANNON IS READY, DO YOU WISH COMPUTER ASSISTANCE"
1700 PRINT "ENTER EITHER 1 OR 0
1710 INPUT C
1720 IF C = 1 THEN 1820
1730 IF C = 0 THEN 1880
1740 PRINT "INVALID RESPONSE"
1750 GOTO 1700
1760 PRINT "WHICH FIGHTER THE SKY (1) OR RADER (0)"
1770 INPUT C
1780 IF C = 1 THEN 1840
1790 IF C = 0 THEN 1860
1800 PRINT "WHICH???"
1810 GOTO 1760
1820 LET Q = 5500
1830 GOTO 1760
1840 LET T1 = T1 - Q
1850 GOTO 1960
1860 LET T2 = T2 - Q
1870 GOTO 1960
1880 PRINT "DO YOU WISH TO FIRE ON GARTH RADER (1) OR"
1890 PRINT "ON THE SKY FIGHTER (0)"
1900 INPUT C
1910 LET Q$ = 5000*(1 + INT(100*RND)/100)
1920 IF C = 0 THEN 1980
1930 IF C = 1 THEN 2000
1940 PRINT "WHICH ENEMY???"
1950 GOTO 1880
1960 LET X1 = X1 - 5000
1970 GOTO 2660
1980 LET T1 = T1 - Q
1982 LET X1 = X1 - 5000
1990 GOTO 2010
2000 LET T2 = T2 - Q
2010 LET X1 = X1 - 5000
2020 GOTO 2660

2030 PRINT "YOU HAVE DECIDED ON USING THE LASER"
2040 PRINT "DO YOU WISH COMPUTER ASSISTANCE, 1 OR 0"
2050 INPUT C
2060 IF C = 1 THEN 2100
2070 IF C = 0 THEN 2120
2080 PRINT "THE COMPUTER RESPONDS ONLY TO A YES OR NO"
2090 GOTO 2040
2100 LET J = 1
2110 GOTO 2130
2120 LET J = 0
2130 PRINT "WHICH FIGHTER THE SKY (0) OR RADER (1)"
2140 PRINT "DO YOU WISH TO FIRE ON"
2150 INPUT C
2160 IF J = 1 THEN 2190
2170 LET Q = 1000*(1 + INT(RND)/100)
2180 GOTO 2200
2190 LET Q = 1000
2200 IF C = 0 THEN 2240
2210 IF C = 1 THEN 2260
2220 PRINT "WHICH TARGET?????"
2230 GOTO 2130
2240 LET T1 = T1 - Q
2250 GOTO 2270
2260 LET T2 = T2 - Q
2270 IF J = 1 THEN 2300
2280 LET X1 = X1 - 1000
2290 GOTO 2660
2300 LET X1 = X1 - 1500
2310 GOTO 2660

2320 PRINT "HOW MANY UNITS OF ENERGY DO YOU WISH TO FEED TO"
2330 PRINT "THE HYPER-ATOMIC DRIVE UNIT, (1 UNIT/KM)"
2340 PRINT "**CAUTION** TOO MUCH ENERGY WILL OVER-HEAT"
2350 PRINT "THE REACTOR, INPUT NO MORE THAN 22,500 UNITS"
2360 PRINT "AT ANY ONE TIME"
2370 INPUT F
2380 PRINT "IN WHICH DIRECTION, AWAY (0) OR TOWARDS (1)"
2390 PRINT "THE DEATH STAR"
2400 INPUT C
2410 IF F > 2.25E04 THEN 2470
2420 IF C = 0 THEN 2500
2430 IF C = 1 THEN 2620
2440 PRINT "DON'T YOU KNOW WHICH DIRECTION YOU WANT TO GO TO"
2450 GOTO 2380

2460 REM OVERHEATING THE REACTOR
2470 PRINT "YOU HAVE WASTED ";F;"UNITS OF ENERGY"
2480 PRINT "THE REACTOR IS CRITICALLY OVERHEATED"
2490 GOTO 2640

2500 LET D = D + F
2510 IF D > 1.5E05 THEN 2540
2520 GOTO 2640
2530 REM WENT TOO FAR
2540 PRINT "WHERE ARE YOU GOING? THE BATTLE IS IN THE"
2550 PRINT "OPPOSITE DIRECTION"
2560 GOTO 2640
2570 PRINT "YOU HAVE SMASHED INTO THE DARK STAR ********"
2580 PRINT "WHERE DID YOU LEARN TO FLY, GARTH RADER"
2590 PRINT "IS LAUGHING AT YOU;; OH!! BY THE WAY---"
2600 PRINT "* * * * * * YOU HAVE LOST * * * * * *"
2610 LET X0 = 1
2612 RETURN

2620 LET D = D - F
2630 IF D <= 0 THEN 2570
2640 LET X1 = X1 - F
2650 GOTO 2680

2660 PRINT "THE SKY FIGHTER'S ENERGY IS NOW";T1;"UNITS"
2670 PRINT "THE DARK LORD'S ENERGY IS";T2;"UNITS"
2680 RETURN

2690 PRINT "YOU ARE AN INCOMPETENT GOOD KNIGHT"
2700 PRINT "YOU HAVE DISGRACED THE MEMORY OF"
2710 PRINT "OBI-SAN COYOTE! WHOSE SIDE ARE YOU ON?!?"
2720 PRINT "WHY DON'T YOU PROVE YOUR WORTH AND TRY AGAIN"
2730 GOTO 2760

2740 PRINT "OBI-SAN COYOTE WOULD BE PROUD OF YOU"
2750 PRINT "YOU ARE INDEED A **GOOD KNIGHT**"

2760 PRINT
2780 PRINT "TO PLAY SPACE WARS AGAIN TYPE 1,"
2790 PRINT "IF NOT TYPE 0"
2800 INPUT L
2810 IF L = 1 THEN 2840
2820 IF L = 0 THEN 2860
2830 PRINT "DO YOU WANT TO STOP OR PLAY AGAIN?????"
2840 GOTO 2780
2850 GOTO 50
2860 PRINT "SPACE WARS SAYS GOOD-BYE AND MAY THE FORCE BE WITH YOU"
2870 END
