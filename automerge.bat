@echo off
REM Script de merge automatico de todos los rpd en la carpeta 'rpd'
REM Los ficheros RPD dentro de la carpeta 'rpd' no pueden tener espacios en el nombre

echo automerge version 19.01.0


for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do echo %%I

setlocal ENABLEDELAYEDEXPANSION
set "scriptdir=%~dp0"
set "startdir=%cd%"
set "rpd_pass=Admin123"

IF %1.==. GOTO ArgNo
set "mergedir=%1"
GOTO ArgEnd

:ArgNo
set "mergedir=.\"
:ArgEnd
cd %mergedir%

mkdir equ
mkdir automerges
ECHO(

:BuscarB
FOR %%I in (*borrado*.rpd) DO (
echo Se toma de base {modified} el fichero %%I
SET BORRADO=%%I
GOTO BuscarPRO
)
GOTO ErrorNB


:BuscarPRO
copy %BORRADO% automerges\merge_borrado_base.rpd /y
set /a count = 1
set /a plus = 2

set last=borrado_base

ECHO -------------------------------------
ECHO Empieza el proceso iterativo de merge
ECHO -------------------------------------

FOR /F %%I in ('dir /B /O:S rpd\*.rpd') DO (
REM for %%I in (rpd\*.rpd) do (

set "current=%%~nI"
echo | CALL %scriptdir%\equalizerpds -B %rpd_pass% -C "automerges\merge_!last!.rpd" -E Admin123 -F "rpd\%%I" -O "equ\equalized_%%~nI.rpd"
IF %ERRORLEVEL% NEQ 0 GOTO ErrorEQ

echo | CALL %scriptdir%\biserverxmlgen -B -R "equ\equalized_%%~nI.rpd" -P Admin123 -O "patch_%%~nI.xml" -8
IF %ERRORLEVEL% NEQ 0 GOTO ErrorGen
echo Se ha creado el patch de %%~nI

call %scriptdir%\roleprune "patch_%%~nI.xml" "patch_%%~nI.xml"

echo | CALL %scriptdir%\biserverxmlexec -I "patch_%%~nI.xml" -S Admin123 -B "automerges\merge_!last!.rpd" -P %rpd_pass% -O "automerges\merge_!current!.rpd"
IF %ERRORLEVEL% NEQ 0 GOTO ErrorExe

set /a count += 1
set /a plus += 1

set "last=%%~nI"
ECHO(
)

GOTO NoComp

ECHO --------------------
ECHO Se crearan los compares para cada proyecto
ECHO --------------------

FOR /F %%I in ('dir /B /O:S rpd\*.rpd') DO (
echo | CALL %scriptdir%\comparerpd -C automerges\merge_!current!.rpd -P C41x4B4nkRpd -G rpd\%%I -W Admin123 -O rpd\%%~nI.csv -8

IF %ERRORLEVEL% NEQ 0 GOTO ErrorComp
)

:NoComp

:Renombrar
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do set datetime=%%I
set datetime=%datetime:~0,8%_%datetime:~8,4%

copy automerges\merge_!current!.rpd %datetime%_automerge.rpd /y
rem del merge*.automerge
goto GoodEnd

:ErrorEQ
echo Se ha producido un error durante el comando de igualado de RPDs { !current! }
GOTO BadEnd
:ErrorGen
echo Se ha producido un error durante el comando de generación de XML { !current! }
GOTO BadEnd
:ErrorExe
echo Se ha producido un error durante el comando de fusionado de paquetes { !current! }
GOTO BadEnd
:ErrorComp
echo Se ha producido un error durante el comando de compare de paquetes { !current! }
GOTO BadEnd

:ErrorNB
echo No se ha encontrado un fichero base (borrado/modified) donde aplicar los parches en la carpeta %mergedir%
GOTO BadEnd

:BadEnd
echo Finalizando el programa sin realizar el merge
set ERRORLEVEL=1
GOTO EndEnd

:GoodEnd
echo Realizado el merge con nombre {%datetime%_automerge.rpd}
set ERRORLEVEL=0
GOTO EndEnd

:EndEnd
rem del *.automerge
del patch_*.xml
rd /s /q equ
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do echo %%I

IF %1.==. GOTO :eof
cd %startdir%
@pause
