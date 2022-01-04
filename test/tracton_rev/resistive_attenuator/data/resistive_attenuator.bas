10 REM THIS PROGRAM COMPUTES THE COMPONENTS
20 REM REQUIRED FOR A PI OR T TYPE
30 REM RESISTIVE ATTENUATOR
40 PRINT "INPUT RESISTANCE R(IN) = ";
50 INPUT R1
60 PRINT "OUTPUT RESISTANCE R(OUT) = ";
70 INPUT R9
80 LET Z = R1/R9
90 LET Q = (SQR(Z) + SQR(Z - 1))^2
100 LET M = 10*(LOG(Q)/LOG(10))
110 PRINT "MINIMUM SYSTEM LOSS IN DECIBELS = ";M
120 PRINT "ENTERED DESIRED LOSS IN DECIBELS";
130 INPUT N
135 LET N = INT(N)
140 REM COMPUTE T NETWORK
150 LET T3 = 2*(SQR(N*R1*R9))/(N-1)
160 LET T1 = R1*((N+1)/(N-1)) - T3
170 LET T2 = R9*((N+1)/(N-1)) - T3
180 REM COMPUTE PI NETWORK
190 LET P3 = 0.5*(N-1)*SQR((R1*R9)/N)
200 LET P1 = 1/(1/R1*((N+1)/(N-1)) - (1/P3))
210 LET P2 = 1/(1/R9*((N+1)/(N-1)) - (1/P3))
220 REM REPORT
230 PRINT "R(IN) = ";R1,"R(OUT) = ";R9
240 PRINT "DESIRED LOSS = ";N
250 PRINT
260 PRINT "T ATTENUATOR"
270 PRINT "RESISTOR 1 = ";T1
280 PRINT "RESISTOR 2 = ";T2
290 PRINT "RESISTOR 3 = ";T3
300 PRINT
310 PRINT "PI ATTENUATOR"
320 PRINT "RESISTOR 1 = ";P1
330 PRINT "RESISTOR 2 = ";P2
340 PRINT "RESISTOR 3 = ";P3
350 PRINT
360 PRINT "TYPE 1 TO CONTINUE, 0 TO STOP"
370 INPUT Q
380 IF Q = 1 THEN 400
390 STOP
400 PRINT
410 GOTO 40
420 END
