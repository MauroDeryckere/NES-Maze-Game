@del %1.o
@del %1.nes
@del %1.map.txt
@del %1.labels.txt
@del %1.nes.ram.nl
@del %1.nes.0.nl
@del %1.nes.1.nl
@del %1.nes.dbg
@echo.
@echo Compiling...
\cc65\bin\ca65 %1.s -g -o %1.o
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Linking...
\cc65\bin\ld65 -o %1.nes -C %1.cfg %1.o -m %1.map.txt -Ln %1.labels.txt --dbgfile %1.nes.dbg
@IF ERRORLEVEL 1 GOTO failure
@echo.
@echo Success!
@GOTO endbuild
:failure
@echo.
@echo Build error!
:endbuild