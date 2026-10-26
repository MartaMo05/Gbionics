@ECHO OFF
REM ============================================================================
REM  MAKE ALL - generates ALL the documentation of a board and uploads it to Infor:
REM    1. make_sch_docs      .BOM files, schematic PDF          (orcad_project)
REM    2. make_BOM           BOM + Production-BOM XLSX/PDF       (bom)
REM    3. make_prod_package  production package + 4 PDFs         (allegro_project)
REM    4. one upload of everything (items 3100.., 3101.., 2100.., + 3D model),
REM       after confirmation; existing documents become new versions after one
REM       more question, identical files are skipped.
REM  If a step reports errors you are asked whether to go on; its documents are
REM  not uploaded.
REM
REM  Normal use: copy this .bat into the PCB_xx folder and double-click it.
REM  Options: --only sch,bom,prod   --upload-only   --no-upload
REM ============================================================================
SETLOCAL ENABLEDELAYEDEXPANSION
SET "AUTODOC_DIR=C:\Cadence\BOM_manager\scripts\python"
IF EXIST "%~dp0make_all.py" SET "AUTODOC_DIR=%~dp0"
IF "%AUTODOC_DIR:~-1%"=="\" SET "AUTODOC_DIR=%AUTODOC_DIR:~0,-1%"
IF NOT EXIST "%AUTODOC_DIR%\make_all.py" (
    ECHO [ERROR] make_all.py not found in %AUTODOC_DIR%
    ECHO         Copy the AutoDOC scripts into C:\Cadence\BOM_manager\scripts\python.
    GOTO :END
)
REM --- Board folder: current folder (PCB_xx or a folder below it), else folder of the .bat ---
SET "TARGET=%CD%"
ECHO "%CD%" | FINDSTR /I /R "\\PCB_[0-9][0-9]" >nul || SET "TARGET=%~dp0"
IF "%TARGET:~-1%"=="\" SET "TARGET=%TARGET:~0,-1%"
SET "AUTODOC_CALLER=%~f0"
python "%AUTODOC_DIR%\make_all.py" "%TARGET%" %*
:END
ECHO.
PAUSE
