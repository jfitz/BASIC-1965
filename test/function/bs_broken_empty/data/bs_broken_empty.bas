10 REM This is a test
20 FOR I = 1 TO 10
30 PRINT I
40 IF I < 5 THEN 60
50 BREAK
60 NEXT I
70 IF BROKEN() THEN 78
72 PRINT "NOT BROKEN"
74 GOTO 90
78 PRINT "BROKEN"
90 STOP
99 END
