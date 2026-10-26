@ECHO OFF
REM ============================================================================
REM  PRODUCTION PACKAGE - generates the production package of a board
REM
REM  Normal use: copy this .bat into the .brd folder (PCB_xx\allegro_project)
REM              and double-click it.
REM  It also works:
REM    - launched from a prompt inside PCB_xx or PCB_xx\allegro_project
REM    - dragging the PCB_xx folder, allegro_project or the .brd onto it
REM  Options (--descr, --spec, --no-odb, --no-upload, ...) after the first argument.
REM  At the end, if there are no errors, it asks whether to upload the package,
REM  the 4 PDFs and the 3D model to Infor.
REM ============================================================================
SETLOCAL ENABLEDELAYEDEXPANSION

REM --- Master script folder (still valid if the .bat is copied elsewhere) ---
SET "AUTODOC_DIR=C:\Cadence\BOM_manager\scripts\python"
IF EXIST "%~dp0make_prod_package.py" SET "AUTODOC_DIR=%~dp0"
IF "%AUTODOC_DIR:~-1%"=="\" SET "AUTODOC_DIR=%AUTODOC_DIR:~0,-1%"
IF NOT EXIST "%AUTODOC_DIR%\make_prod_package.py" (
    ECHO [ERROR] make_prod_package.py not found in %AUTODOC_DIR%
    ECHO         Copy the AutoDOC scripts into C:\Cadence\BOM_manager\scripts\python.
    GOTO :END
)

REM --- Work folder: argument, else current folder, else folder of the .bat ---
SET "TARGET=%~1"
IF NOT "%TARGET%"=="" GOTO :RUN

SET "TARGET=%CD%"
CALL :HAS_BRD "%TARGET%"
IF "!FOUND!"=="1" GOTO :RUN
SET "TARGET=%~dp0"
IF "%TARGET:~-1%"=="\" SET "TARGET=%TARGET:~0,-1%"
CALL :HAS_BRD "%TARGET%"
IF "!FOUND!"=="1" GOTO :RUN
ECHO [ERROR] No .brd found in %CD%
ECHO         (nor in allegro_project below it, nor in the folder of the .bat).
ECHO         Copy the .bat into the .brd folder and run it again.
GOTO :END

:RUN
ECHO Project folder: %TARGET%
ECHO.
SET "AUTODOC_CALLER=%~f0"
python "%AUTODOC_DIR%\make_prod_package.py" "%TARGET%" %2 %3 %4 %5 %6 %7 %8 %9

:END
ECHO.
PAUSE
EXIT /B

:HAS_BRD
SET "FOUND=0"
IF EXIST "%~1\*.brd" SET "FOUND=1"
IF EXIST "%~1\allegro_project\*.brd" SET "FOUND=1"
EXIT /B
