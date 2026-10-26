@ECHO OFF

REM ================================================================================
REM  MAKE BOM - DUAL BOM GENERATION (ASSEMBLY + CORE)  (formerly PMC_DOC_automation.bat)
REM
REM  Normal use: copy into PCB_xx\bom and double-click it (it works on the current folder).
REM  Options: --no-upload  generate only, do not offer the Infor upload (used by make_all)
REM           --no-pause   do not wait for a key at the end (used by make_all)
REM  Exit code: 0 = OK, 1 = generation error, otherwise the upload exit code.
REM ================================================================================

SETLOCAL EnableDelayedExpansion

REM --- Installation check (autodoc_setup.py): scripts up to date, Python packages, programs.
REM     If the scripts were updated this .bat may have changed too: it is started again.
REM     (the whole IF block is read before it runs, so overwriting this file here is safe)
IF NOT "%AUTODOC_SETUP_DONE%"=="1" IF EXIST "C:\Cadence\BOM_manager\scripts\python\autodoc_setup.py" (
    python "C:\Cadence\BOM_manager\scripts\python\autodoc_setup.py" --need bom,upload --caller "%~f0"
    IF ERRORLEVEL 10 (
        SET "AUTODOC_SETUP_DONE=1"
        CALL "%~f0" %*
        EXIT /B
    )
)
SET "AUTODOC_SETUP_DONE=1"

SET "NO_UPLOAD=0"
SET "NO_PAUSE=0"
SET "RC=0"
REM One anteater per run: printed at the end of this script, not by the scripts it calls
SET "PARENT_NO_ANTEATER=%AUTODOC_NO_ANTEATER%"
SET "AUTODOC_NO_ANTEATER=1"
FOR %%A IN (%*) DO (
    IF /I "%%~A"=="--no-upload" SET "NO_UPLOAD=1"
    IF /I "%%~A"=="--no-pause" SET "NO_PAUSE=1"
)

ECHO.
ECHO ==============================================================================
ECHO  MAKE BOM - DUAL BOM GENERATION (ASSEMBLY + CORE)
ECHO ==============================================================================
ECHO.

REM ------------------------------------------------------------------------------
REM  1. Dynamic Folder Structure and Item Code Resolution
REM ------------------------------------------------------------------------------
FOR %%I IN ("%CD%\..") DO SET "PCB_FOLDER=%%~nxI"
FOR %%I IN ("%CD%\..\..") DO SET "BOARD_FOLDER=%%~nxI"

SET "PCB_REV=!PCB_FOLDER:~-2!"

FOR /F "tokens=1* delims=_" %%A IN ("!BOARD_FOLDER!") DO (
    SET "SCHEM_CODE=%%A"
    SET "RAW_DESC=%%B"
)

SET "ROOT_ID=!SCHEM_CODE:~-5!"
SET "ITEM_CODE=3100!PCB_REV!!ROOT_ID!"
SET "BOARD_TITLE=!RAW_DESC!"

SET "BOARD_DESC_ASSY=!BOARD_TITLE:_= !"
SET "BOARD_DESC_CORE=!BOARD_TITLE:_= !"

ECHO [INFO] Working Path      : %CD%
ECHO [INFO] PCB Folder        : !PCB_FOLDER! (Revision: !PCB_REV!)
ECHO [INFO] Board Folder      : !BOARD_FOLDER!
ECHO [INFO] Schematic Root ID : !SCHEM_CODE! (ID: !ROOT_ID!)
ECHO [INFO] Target Item Code  : !ITEM_CODE!
ECHO [INFO] Full Board Title  : !BOARD_TITLE!
ECHO.

REM Error flag for the generation phase (set to 1 if any XLSX/PDF step fails)
SET "HAS_GEN_ERROR=0"

REM ------------------------------------------------------------------------------
REM  2. Pre-execution Validation: Maximum 2 BOM Files per Format (BOM, XLSX, PDF)
REM ------------------------------------------------------------------------------
SET "COUNT_PRE_BOM=0"
FOR /F %%C IN ('dir /b /a-d "*.BOM" 2^>nul ^| find /c /v ""') DO SET "COUNT_PRE_BOM=%%C"

SET "COUNT_PRE_XLSX=0"
FOR /F %%C IN ('dir /b /a-d "*BOM*.xlsx" 2^>nul ^| findstr /V /B "~$" ^| find /c /v ""') DO SET "COUNT_PRE_XLSX=%%C"

SET "COUNT_PRE_PDF=0"
FOR /F %%C IN ('dir /b /a-d "*BOM*.pdf" 2^>nul ^| find /c /v ""') DO SET "COUNT_PRE_PDF=%%C"

ECHO [INFO] Existing BOM deliverables in folder:
ECHO        - Schematic BOM files : !COUNT_PRE_BOM!
ECHO        - Excel files         : !COUNT_PRE_XLSX!
ECHO        - PDF files           : !COUNT_PRE_PDF!
ECHO.

SET "HAS_PRE_ERROR=0"

IF !COUNT_PRE_BOM! GTR 2 (
    ECHO [ERROR] Found !COUNT_PRE_BOM! schematic BOM files. Maximum allowed is 2.
    SET "HAS_PRE_ERROR=1"
)

IF !COUNT_PRE_XLSX! GTR 2 (
    ECHO [ERROR] Found !COUNT_PRE_XLSX! Excel BOM files. Maximum allowed is 2.
    SET "HAS_PRE_ERROR=1"
)

IF !COUNT_PRE_PDF! GTR 2 (
    ECHO [ERROR] Found !COUNT_PRE_PDF! PDF BOM files. Maximum allowed is 2.
    SET "HAS_PRE_ERROR=1"
)

IF "!HAS_PRE_ERROR!"=="1" (
    ECHO.
    ECHO [ERROR] Pre-execution check failed: More than 2 BOM files detected for one or more formats.
    ECHO         Please remove obsolete or duplicate files before running the automation.
    ECHO.
    SET "RC=1"
    GOTO :EndScript
)

REM ------------------------------------------------------------------------------
REM  3. Source Schematic BOM File Discovery
REM ------------------------------------------------------------------------------
SET "SOURCE_BOM_GENERIC="
SET "SOURCE_BOM_CORE="
SET "SOURCE_BOM_ASSY="

FOR %%F IN (*CORE*.BOM 3101*CORE*.BOM) DO (
    SET "SOURCE_BOM_CORE=%%~fF"
)

FOR %%F IN (3101*ASS*.BOM *ASSEMBLY*.BOM) DO (
    SET "SOURCE_BOM_ASSY=%%~fF"
)

FOR %%F IN (3101*.BOM *.BOM) DO (
    SET "FNAME=%%~nF"
    ECHO !FNAME! | findstr /I "CORE" >nul
    IF ERRORLEVEL 1 (
        IF not defined SOURCE_BOM_GENERIC SET "SOURCE_BOM_GENERIC=%%~fF"
    )
)

IF not defined SOURCE_BOM_ASSY SET "SOURCE_BOM_ASSY=!SOURCE_BOM_GENERIC!"
IF not defined SOURCE_BOM_CORE (
    IF defined SOURCE_BOM_GENERIC (
        SET "SOURCE_BOM_CORE=!SOURCE_BOM_GENERIC!"
    )
)

REM ------------------------------------------------------------------------------
REM  4. Exporting and Formatting ASSEMBLY BOM (..._Production-BOM)
REM ------------------------------------------------------------------------------
ECHO ==============================================================================
ECHO  [1/2] PROCESSING ASSEMBLY BOM (Production-BOM)
ECHO ==============================================================================

IF not defined SOURCE_BOM_ASSY (
    ECHO [WARNING] No schematic BOM file found for ASSEMBLY. Skipping...
) ELSE (
    ECHO [INFO] Source BOM File: "!SOURCE_BOM_ASSY!"
    SET "BASE_NAME_ASSY=!ITEM_CODE!_!BOARD_TITLE!_REV-!PCB_REV!_Production-BOM"
    SET "TARGET_XLSX_ASSY=%CD%\!BASE_NAME_ASSY!.XLSX"

    REM Create temporary backup for 'Kit Supplied by Customer' sync
    FOR %%I IN ("!BASE_NAME_ASSY!*.XLSX") DO COPY /Y "%%~fI" "%%~fI.prev.bak" >nul 2>&1

    ECHO [STEP] Exporting XLSX BOM...
    python "C:\Cadence\BOM_manager\scripts\python\bom_manager.py" ^
        -export_bom ^
        -phase_motion_control ^
        -source_bom_file "!SOURCE_BOM_ASSY!" ^
        -target_xlsx_file "!TARGET_XLSX_ASSY!" ^
        -overwrite_xlsx ^
        -add_timestamp ^
        -board_name "!ITEM_CODE!" ^
        -board_description "!BOARD_DESC_ASSY!" ^
        -board_revision "!PCB_REV!.00"

    REM Pick the most recently modified XLSX (= the one just generated)
    SET "ACTUAL_XLSX_ASSY="
    SET "ACTUAL_PDF_ASSY="
    FOR /F "delims=" %%I IN ('dir /b /a-d /o-d "!BASE_NAME_ASSY!*.XLSX" 2^>nul') DO (
        IF NOT DEFINED ACTUAL_XLSX_ASSY (
            SET "ACTUAL_XLSX_ASSY=%%~fI"
            SET "ACTUAL_PDF_ASSY=%%~dpnI.pdf"
        )
    )

    IF DEFINED ACTUAL_XLSX_ASSY (
        ECHO [STEP] Formatting Excel worksheets and generating PDF...
        python "C:\Cadence\BOM_manager\scripts\python\excel_to_pdf.py" "!ACTUAL_XLSX_ASSY!" "!ACTUAL_PDF_ASSY!"
        IF ERRORLEVEL 1 (
            ECHO [ERROR] PDF generation failed for Assembly BOM. Old versions kept.
            SET "HAS_GEN_ERROR=1"
        ) ELSE (
            ECHO [SUCCESS] Generated Assembly Deliverables:
            ECHO           - !ACTUAL_XLSX_ASSY!
            ECHO           - !ACTUAL_PDF_ASSY!

            REM Remove previous versions: keep only the files just generated
            FOR %%I IN ("!BASE_NAME_ASSY!*.XLSX") DO (
                IF /I NOT "%%~fI"=="!ACTUAL_XLSX_ASSY!" (
                    DEL /F /Q "%%~fI" >nul 2>&1
                    ECHO [CLEANUP] Removed old version: %%~nxI
                )
            )
            FOR %%I IN ("!BASE_NAME_ASSY!*.PDF") DO (
                IF /I NOT "%%~fI"=="!ACTUAL_PDF_ASSY!" (
                    DEL /F /Q "%%~fI" >nul 2>&1
                    ECHO [CLEANUP] Removed old version: %%~nxI
                )
            )
        )
    ) ELSE (
        ECHO [ERROR] Generated Assembly XLSX file not found.
        SET "HAS_GEN_ERROR=1"
    )
)

REM Safety pause to let Excel COM release file handles before the second run
timeout /t 3 /nobreak >nul
ECHO.

REM ------------------------------------------------------------------------------
REM  5. Exporting and Formatting CORE BOM (..._BOM)
REM ------------------------------------------------------------------------------
ECHO ==============================================================================
ECHO  [2/2] PROCESSING CORE BOM (BOM)
ECHO ==============================================================================

IF not defined SOURCE_BOM_CORE (
    ECHO [WARNING] No schematic BOM file found for CORE. Skipping...
) ELSE (
    ECHO [INFO] Source BOM File: "!SOURCE_BOM_CORE!"
    SET "BASE_NAME_CORE=!ITEM_CODE!_!BOARD_TITLE!_REV-!PCB_REV!_BOM"
    SET "TARGET_XLSX_CORE=%CD%\!BASE_NAME_CORE!.XLSX"

    REM Create temporary backup for 'Kit Supplied by Customer' sync
    FOR %%I IN ("!BASE_NAME_CORE!*.XLSX") DO COPY /Y "%%~fI" "%%~fI.prev.bak" >nul 2>&1

    ECHO [STEP] Exporting XLSX CORE BOM...
    python "C:\Cadence\BOM_manager\scripts\python\bom_manager.py" ^
        -export_bom ^
        -phase_motion_control ^
        -source_bom_file "!SOURCE_BOM_CORE!" ^
        -target_xlsx_file "!TARGET_XLSX_CORE!" ^
        -overwrite_xlsx ^
        -add_timestamp ^
        -board_name "!ITEM_CODE!" ^
        -board_description "!BOARD_DESC_CORE!" ^
        -board_revision "!PCB_REV!.00"

    REM Pick the most recently modified XLSX (= the one just generated)
    SET "ACTUAL_XLSX_CORE="
    SET "ACTUAL_PDF_CORE="
    FOR /F "delims=" %%I IN ('dir /b /a-d /o-d "!BASE_NAME_CORE!*.XLSX" 2^>nul') DO (
        IF NOT DEFINED ACTUAL_XLSX_CORE (
            SET "ACTUAL_XLSX_CORE=%%~fI"
            SET "ACTUAL_PDF_CORE=%%~dpnI.pdf"
        )
    )

    IF DEFINED ACTUAL_XLSX_CORE (
        ECHO [STEP] Formatting Excel worksheets and generating PDF...
        python "C:\Cadence\BOM_manager\scripts\python\excel_to_pdf.py" "!ACTUAL_XLSX_CORE!" "!ACTUAL_PDF_CORE!"
        IF ERRORLEVEL 1 (
            ECHO [ERROR] PDF generation failed for Core BOM. Old versions kept.
            SET "HAS_GEN_ERROR=1"
        ) ELSE (
            ECHO [SUCCESS] Generated Core Deliverables:
            ECHO           - !ACTUAL_XLSX_CORE!
            ECHO           - !ACTUAL_PDF_CORE!

            REM Remove previous versions: keep only the files just generated
            FOR %%I IN ("!BASE_NAME_CORE!*.XLSX") DO (
                IF /I NOT "%%~fI"=="!ACTUAL_XLSX_CORE!" (
                    DEL /F /Q "%%~fI" >nul 2>&1
                    ECHO [CLEANUP] Removed old version: %%~nxI
                )
            )
            FOR %%I IN ("!BASE_NAME_CORE!*.PDF") DO (
                IF /I NOT "%%~fI"=="!ACTUAL_PDF_CORE!" (
                    DEL /F /Q "%%~fI" >nul 2>&1
                    ECHO [CLEANUP] Removed old version: %%~nxI
                )
            )
        )
    ) ELSE (
        ECHO [ERROR] Generated Core XLSX file not found.
        SET "HAS_GEN_ERROR=1"
    )
)

ECHO.
ECHO ==============================================================================
ECHO  BOM GENERATION COMPLETE
ECHO ==============================================================================
ECHO.

IF "!HAS_GEN_ERROR!"=="1" (
    ECHO [ERROR] One or more generation steps failed. Upload to Infor LN IDM disabled.
    ECHO         Check the messages above and run the automation again.
    SET "RC=1"
    GOTO :EndScript
)

REM ------------------------------------------------------------------------------
REM  6. Verification of Generated Deliverables
REM ------------------------------------------------------------------------------
SET "COUNT_PDF=0"
FOR /F %%C IN ('dir /b /a-d "*BOM*.pdf" 2^>nul ^| find /c /v ""') DO SET "COUNT_PDF=%%C"

SET "COUNT_XLSX=0"
FOR /F %%C IN ('dir /b /a-d "*BOM*.xlsx" 2^>nul ^| findstr /V /B "~$" ^| find /c /v ""') DO SET "COUNT_XLSX=%%C"

ECHO [STATUS] Deliverables ready in folder: !COUNT_PDF! PDF file(s), !COUNT_XLSX! Excel file(s).
ECHO.

SET "HAS_POST_ERROR=0"
IF !COUNT_PDF! GTR 2 (
    ECHO [ERROR] Found !COUNT_PDF! PDF BOM files in folder. Maximum allowed is 2.
    SET "HAS_POST_ERROR=1"
)
IF !COUNT_XLSX! GTR 2 (
    ECHO [ERROR] Found !COUNT_XLSX! Excel BOM files in folder. Maximum allowed is 2.
    SET "HAS_POST_ERROR=1"
)

IF "!HAS_POST_ERROR!"=="1" (
    ECHO.
    ECHO [ERROR] Upload aborted to prevent uploading duplicate deliverables to Infor LN IDM.
    ECHO         Please ensure only the 2 latest BOM deliverables remain in the folder.
    ECHO.
    SET "RC=1"
    GOTO :EndScript
)

IF "!NO_UPLOAD!"=="1" (
    ECHO [INFO] Upload not offered ^(--no-upload^).
    GOTO :EndScript
)

REM ------------------------------------------------------------------------------
REM  7. User Consent for Automated Infor LN IDM Ingestion
REM ------------------------------------------------------------------------------
:PromptLoop
SET "CONFIRM_UPLOAD="
SET /P "CONFIRM_UPLOAD=Do you want to upload generated deliverables to Infor LN IDM? [Y/N]: "

IF NOT DEFINED CONFIRM_UPLOAD GOTO :PromptLoop
IF /I "!CONFIRM_UPLOAD!"=="Y" GOTO :ProceedUpload
IF /I "!CONFIRM_UPLOAD!"=="YES" GOTO :ProceedUpload
IF /I "!CONFIRM_UPLOAD!"=="N" GOTO :SkipUpload
IF /I "!CONFIRM_UPLOAD!"=="NO" GOTO :SkipUpload

ECHO Invalid input. Please type 'Y' to upload or 'N' to skip.
GOTO :PromptLoop

:SkipUpload
ECHO.
ECHO [INFO] Upload skipped by user. Generated files have been preserved locally.
GOTO :EndScript

:ProceedUpload
ECHO.
ECHO ==============================================================================
ECHO  INFOR LN IDM - AUTOMATED DOCUMENT INGESTION
ECHO ==============================================================================
ECHO.
ECHO [INFO] Target ERP Environment : Infor LN PROD (IDM)
ECHO [INFO] Target Item Code       : !ITEM_CODE!
ECHO.

REM ------------------------------------------------------------------------------
REM  8. Build the list of deliverables (PDF first, then Excel; '~$' lock files skipped)
REM ------------------------------------------------------------------------------
SET "UPLOAD_ARGS="
SET "UPLOAD_COUNT=0"

FOR %%F IN (*BOM*.pdf) DO (
    ECHO [QUEUE] PDF   : "%%~nxF"
    SET "UPLOAD_ARGS=!UPLOAD_ARGS! --file ELT_BOM_pdf "%%~fF""
    SET /A UPLOAD_COUNT+=1
)

FOR %%F IN (*BOM*.xlsx) DO (
    SET "UP_NAME=%%~nxF"
    IF "!UP_NAME:~0,2!"=="~$" (
        ECHO [INFO] Skipping Excel lock file: "%%~nxF"
    ) ELSE (
        ECHO [QUEUE] Excel : "%%~nxF"
        SET "UPLOAD_ARGS=!UPLOAD_ARGS! --file ELT_BOM_excel "%%~fF""
        SET /A UPLOAD_COUNT+=1
    )
)

IF !UPLOAD_COUNT! EQU 0 (
    ECHO [WARNING] No deliverables found to upload.
    SET "RC=1"
    GOTO :EndScript
)

REM ------------------------------------------------------------------------------
REM  9. Upload all deliverables in a single browser session
REM ------------------------------------------------------------------------------
ECHO.
ECHO [INFO] Uploading !UPLOAD_COUNT! deliverable^(s^) in a single Infor session...
python "C:\Cadence\BOM_manager\scripts\python\upload_to_infor_idm.py" --item "!ITEM_CODE!" !UPLOAD_ARGS!
SET "UPLOAD_RC=!ERRORLEVEL!"
SET "RC=!UPLOAD_RC!"

ECHO.
ECHO ==============================================================================
IF "!UPLOAD_RC!"=="0" (
    ECHO  ALL DELIVERABLES SUCCESSFULLY UPLOADED TO INFOR IDM - !UPLOAD_COUNT! file^(s^)
) ELSE IF "!UPLOAD_RC!"=="2" (
    ECHO  UPLOAD ABORTED: item !ITEM_CODE! not found in Infor LN
) ELSE (
    ECHO  UPLOAD COMPLETED WITH ERRORS - see [SUMMARY] above
    ECHO  Check the screenshots 'infor_error_N.png' in this folder.
)
ECHO ==============================================================================

:EndScript
REM ------------------------------------------------------------------------------
REM  10. Cleanup of temporary 'Kit Supplied by Customer' backups
REM ------------------------------------------------------------------------------
IF EXIST "*.XLSX.prev.bak" (
    DEL /F /Q "*.XLSX.prev.bak" >nul 2>&1
    ECHO [CLEANUP] Temporary .prev.bak backups removed.
)

ECHO.
IF NOT "!PARENT_NO_ANTEATER!"=="1" python "C:\Cadence\BOM_manager\scripts\python\anteater.py" --force
IF "!NO_PAUSE!"=="0" PAUSE
EXIT /B !RC!
