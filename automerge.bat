@echo off
REM Script de merge automatico de todos los rpd en la carpeta 'rpd'
REM Los ficheros RPD dentro de la carpeta 'rpd' no pueden tener espacios en el nombre

echo automerge version 19.03.0
REM formato version: YEAR.MONTH.RELEASE(empieza por 0)

REM for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do echo %%I

setlocal ENABLEDELAYEDEXPANSION
set "scriptdir=%~dp0"
set "startdir=%cd%"
REM variable con el nombre de la carpeta con los RPDs de las aplicaciones
set "carpeta_rpd=rpd"
set "rpd_pass=Admin123"

REM la variable mergedir indica donde se realizara el automerge
IF %1.==. GOTO ArgNo
set "mergedir=%1"
GOTO ArgEnd

:ArgNo
set "mergedir=.\"
:ArgEnd

echo El automerge se realizara en la carpeta "%mergedir%"
cd %mergedir%

REM comprobamos si la carpeta con las aplicaciones existe y tiene ficheros
if not exist %carpeta_rpd% (
  GOTO ErrorNoCarpetaRPD
)

set _TMP=
for /f "delims=" %%a in ('dir /b %carpeta_rpd%') do set _TMP=%%a

IF {%_TMP%}=={} (
  GOTO ErrorNoRPDs 
)

echo Se crean las carpetas donde se almacenan los RPD intermedios
md equ 2>NUL
md automerges 2>NUL
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

ECHO -----------------------------------------
ECHO --Empieza el proceso iterativo de merge--
ECHO -----------------------------------------

FOR /F %%I in ('dir /B /O:S %carpeta_rpd%\*.rpd') DO (
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
REM Actualmente este trozo no se ejecuta

ECHO --------------------
ECHO Se crearan los compares para cada proyecto
ECHO --------------------

FOR /F %%I in ('dir /B /O:S %carpeta_rpd%\*.rpd') DO (
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

:ErrorNoCarpetaRPD
echo Error: No se ha encontrado la carpeta con los RPD de las aplicaciones {%carpeta_rpd%}
GOTO BadEnd
:ErrorNoRPDs
echo Error: La carpeta con los RPD de las aplicaciones esta vacia {%carpeta_rpd%}
GOTO BadEnd

:ErrorEQ
echo Error: Se ha producido un error durante el comando de igualado de RPDs { !current! }
GOTO BadEnd
:ErrorGen
echo Error: Se ha producido un error durante el comando de generación de XML { !current! }
GOTO BadEnd
:ErrorExe
echo Error: Se ha producido un error durante el comando de fusionado de paquetes { !current! }
GOTO BadEnd
:ErrorComp
echo Error: Se ha producido un error durante el comando de compare de paquetes { !current! }
GOTO BadEnd

:ErrorNB
echo Error: No se ha encontrado un fichero base (borrado/modified) donde aplicar los parches en la carpeta "%mergedir%"
echo Asegurate que en esta carpeta hay algun fichero RPD que contenga la palabra 'borrado' en su nombre
GOTO BadEnd

:BadEnd
echo Finalizando el programa sin realizar el merge (ver errores indicados arriba)
set ERRORLEVEL=1
GOTO EndEnd

:GoodEnd
echo Realizado el merge con nombre {%datetime%_automerge.rpd}
set ERRORLEVEL=0
GOTO EndEnd

:EndEnd
rem del *.automerge
del /q patch_*.xml 2>NUL
rd /s /q equ
REM for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /format:list') do echo %%I

IF %1.==. GOTO :eof
cd %startdir%
@pause
