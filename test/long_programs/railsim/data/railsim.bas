100 REM DEFINITIONS
110 REM POSITION OF HOBOKEN (meters)
111 LET K0 = 0
120 REM POSITION OF HARMON COVE (meters)
121 LET K1 = 8.0E3
130 REM ACCELERATION (meters/second^2)
131 LET A0 = 1.0
140 REM MAX VELOCITY (meters/second)
141 LET V9 = 80
200 REM ONE TRIP
201 LET X = K0
202 LET V = 0
290 PRINT "T  ";"X  ";"V  ";"A  ";"T5 ";"X5 ";"K1"
299 LET T = 0
1000 REM LOOP
1010 REM COMPUTE STOPPING TIME
1011 LET T5 = 2.0*V/A0
1020 REM COMPUTE STOPPING DISTANCE
1021 LET X5 = V*T5 + 0.5*(A0)*T5^2
1230 REM IF CLOSE TO DESTINATION, SLOW DOWN
1231 IF X + X5 >= K1 THEN 1234
1232 LET A = A0
1233 GOTO 1240
1234 LET A = -A0
1240 REM IF NOT AT TOP SPEED, INCREASE SPEED
1241 IF A < 0 THEN 1245
1242 IF V >= V9 THEN 1248
1243 LET V = V + A
1244 GOTO 1900
1245 IF V <= 0 THEN 1900
1246 LET V = V + A
1247 GOTO 1900
1248 LET A = 0
1900 REM CHECK VELOCITY
1901 IF V >= 0 THEN 1960
1902 LET V = 0
1960 REM MOVE THE TRAIN
1961 LET X = X + V
1970 REM REPORT POSITION AND SPEED
1971 PRINT T;X;V;A;T5;X5;K1
1980 REM IF AT STOPPING POINT, STOP SIMULATION
1981 IF X >= K1 THEN 9998
1990 REM STEP INTO FUTURE
1991 LET T = T + 1
1999 GOTO 1000
9998 STOP
9999 END