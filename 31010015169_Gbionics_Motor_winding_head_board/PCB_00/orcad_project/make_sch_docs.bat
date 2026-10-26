@ECHO OFF
REM ============================================================================
REM  SCHEMATIC DOCS - generates the schematic PDF and the .BOM files (Core + variant)
REM                   with Capture
REM
REM  Normal use: copy this .bat into the Capture project folder
REM              (PCB_xx\orcad_project) and double-click it.
REM  It also works from a prompt inside PCB_xx, or dragging the .opj/folder onto it.
REM  Capture opens and closes by itself: do not touch it until it has finished.
REM  Options (after the first argument): --variant NAME, --no-pdf, --no-bom,
REM  --keep-work, --no-upload
REM  At the end, if there are no errors, it asks whether to upload the schematic PDF
REM  and the project sources zip to Infor.
REM ============================================================================
SETLOCAL ENABLEDELAYEDEXPANSION
SET "AUTODOC_DIR=C:\Cadence\BOM_manager\scripts\python"
IF EXIST "%~dp0make_sch_docs.py" SET "AUTODOC_DIR=%~dp0"
IF "%AUTODOC_DIR:~-1%"=="\" SET "AUTODOC_DIR=%AUTODOC_DIR:~0,-1%"
IF NOT EXIST "%AUTODOC_DIR%\make_sch_docs.py" (
    ECHO [ERROR] make_sch_docs.py not found in %AUTODOC_DIR%
    ECHO         Copy the AutoDOC scripts into C:\Cadence\BOM_manager\scripts\python.
    GOTO :END
)
SET "TARGET=%~1"
IF NOT "%TARGET%"=="" GOTO :RUN
SET "TARGET=%CD%"
CALL :HAS_OPJ "%TARGET%"
IF "!FOUND!"=="1" GOTO :RUN
SET "TARGET=%~dp0"
IF "%TARGET:~-1%"=="\" SET "TARGET=%TARGET:~0,-1%"
CALL :HAS_OPJ "%TARGET%"
IF "!FOUND!"=="1" GOTO :RUN
ECHO [ERROR] No .opj project found in %CD% (nor in orcad_project).
ECHO         Copy the .bat into the orcad_project folder and run it again.
GOTO :END
:RUN
ECHO Project: %TARGET%
ECHO.
SET "AUTODOC_CALLER=%~f0"
python "%AUTODOC_DIR%\make_sch_docs.py" "%TARGET%" %2 %3 %4 %5 %6 %7 %8 %9
:END
ECHO.
PAUSE
EXIT /B
:HAS_OPJ
SET "FOUND=0"
IF EXIST "%~1\*.opj" SET "FOUND=1"
IF EXIST "%~1\orcad_project\*.opj" SET "FOUND=1"
EXIT /B
