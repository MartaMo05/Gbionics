@ECHO OFF

REM ================================================================================
REM  BOM MANAGER
REM --------------------------------------------------------------------------------
REM  
REM    Usage: bom_manager <command line options>
REM  
REM    Where <command line options> can be:
REM  
REM      COMMANDS:
REM          -export_bom: tells the BOM manager to export the current BOM in
REM              .xlsx format; source and target file names are specified
REM              by other command line options listed below.
REM          -compare_bom: tells the BOM manager to compare the source BOM
REM              against the reference BOM
REM          -where_used: tells the BOM manager to look for a given part number
REM              into the BOM archive
REM  
REM      PARAMETERS:
REM          -phase_motion_control: specifies that the BOM is generated for
REM               this company; mutually exclusive with '-physis_net' parameter
REM          -physis_net: specifies that the BOM is generated for this company;
REM               mutually exclusive with '-phase_motion_control' parameter
REM          -source_bom_file <path>: name of the BOM text file to be exported
REM              (use double quotation marks in case the full path contains
REM               spaces).
REM          -target_xlsx_file <path>: name of the BOM XLSX file to be created
REM              (use double quotation marks in case the full path contains
REM               spaces).
REM          -overwrite_xlsx: tells the BOM manager to overwrite the target
REM              XLSX BOM file if necessary (otherwise the process ends
REM                                          without overwriting)
REM          -add_timestamp: tells the BOM manager to add a timestamp to the
REM              output XLSX file; format: ' (yyyy-mm-dd)'
REM          -reference_bom_file <path>: name of the BOM text file to be used for
REM              the difference table with respect to the current BOM.
REM              (use double quotation marks in case the full path contains
REM               spaces).
REM          -part_number <part_number>: specifies the part number to be
REM              searched into the BOM archive.
REM          -board_name <name>: specifies the name or code of the board to
REM              be added to the cover of the XLSX target file (use double
REM              quotation marks in case the string contains spaces).
REM          -board_description <name>: string with the description of the board
REM              to be added to the cover of the XLSX target file (use double
REM              quotation marks in case the string contains spaces).
REM          -board_revision <name>: string with the revision of the board
REM              to be added to the cover of the XLSX target file (use double
REM              quotation marks in case the string contains spaces).
REM  
REM ================================================================================
    
REM ================================================================================
REM  This batch file should be placed by the user into the BOM folder and modified 
REM  as for the paths of the files.
REM  Once done this, it will be only necessary to provide the updated BOM file and
REM  to launch it to obtain a formatted XLSX file.
REM  
REM  NOTE: the character "^" allows to split a single line command into multiple
REM        line; care shall be taken to leave a space before it to avoid 
REM        concatenate the current line with the following.
REM ================================================================================

SETLOCAL EnableDelayedExpansion

ECHO.
ECHO ==============================================================================
ECHO  BOM MANAGER - DUAL BOM GENERATION (ASSEMBLY + CORE)
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

REM ------------------------------------------------------------------------------
REM  2. Source Schematic BOM File Discovery
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
REM  3. Exporting and Formatting ASSEMBLY BOM (..._Production-BOM)
REM ------------------------------------------------------------------------------
ECHO ==============================================================================
ECHO  [1/2] PROCESSING ASSEMBLY BOM (Production-BOM)
ECHO ==============================================================================

IF not defined SOURCE_BOM_ASSY (
    ECHO [WARNING] No schematic BOM file found for ASSEMBLY. Skipping...
) ELSE (
    ECHO [INFO] Source BOM File: "!SOURCE_BOM_ASSY!"
    SET "BASE_NAME_ASSY=!ITEM_CODE!_!BOARD_TITLE!_REV-00_Production-BOM"
    SET "TARGET_XLSX_ASSY=%CD%\!BASE_NAME_ASSY!.XLSX"

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

    FOR %%X IN ("!BASE_NAME_ASSY!*.XLSX") DO (
        SET "ACTUAL_XLSX_ASSY=%%~fX"
        SET "ACTUAL_PDF_ASSY=%%~dpnX.pdf"
    )

    IF DEFINED ACTUAL_XLSX_ASSY (
        ECHO [STEP] Formatting Excel worksheets and generating PDF...
        python "C:\Cadence\BOM_manager\scripts\python\excel_to_pdf.py" "!ACTUAL_XLSX_ASSY!" "!ACTUAL_PDF_ASSY!"
        ECHO [SUCCESS] Generated Assembly Deliverables:
        ECHO           - !ACTUAL_XLSX_ASSY!
        ECHO           - !ACTUAL_PDF_ASSY!
    ) ELSE (
        ECHO [ERROR] Generated Assembly XLSX file not found.
    )
)

REM Safety pause between COM Excel sessions
timeout /t 2 /nobreak >nul
ECHO.

REM ------------------------------------------------------------------------------
REM  4. Exporting and Formatting CORE BOM (..._BOM)
REM ------------------------------------------------------------------------------
ECHO ==============================================================================
ECHO  [2/2] PROCESSING CORE BOM (BOM)
ECHO ==============================================================================

IF not defined SOURCE_BOM_CORE (
    ECHO [WARNING] No schematic BOM file found for CORE. Skipping...
) ELSE (
    ECHO [INFO] Source BOM File: "!SOURCE_BOM_CORE!"
    SET "BASE_NAME_CORE=!ITEM_CODE!_!BOARD_TITLE!_REV-00_BOM"
    SET "TARGET_XLSX_CORE=%CD%\!BASE_NAME_CORE!.XLSX"

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

    FOR %%X IN ("!BASE_NAME_CORE!*.XLSX") DO (
        SET "ACTUAL_XLSX_CORE=%%~fX"
        SET "ACTUAL_PDF_CORE=%%~dpnX.pdf"
    )

    IF DEFINED ACTUAL_XLSX_CORE (
        ECHO [STEP] Formatting Excel worksheets and generating PDF...
        python "C:\Cadence\BOM_manager\scripts\python\excel_to_pdf.py" "!ACTUAL_XLSX_CORE!" "!ACTUAL_PDF_CORE!"
        ECHO [SUCCESS] Generated Core Deliverables:
        ECHO           - !ACTUAL_XLSX_CORE!
        ECHO           - !ACTUAL_PDF_CORE!
    ) ELSE (
        ECHO [ERROR] Generated Core XLSX file not found.
    )
)

ECHO.
ECHO ==============================================================================
ECHO  BOM GENERATION COMPLETE
ECHO ==============================================================================
ECHO.

REM ------------------------------------------------------------------------------
REM  5. Verification of Generated Deliverables
REM ------------------------------------------------------------------------------
SET "COUNT_PDF=0"
SET "COUNT_XLSX=0"
FOR %%F IN (*BOM*.pdf) DO SET /A COUNT_PDF+=1
FOR %%F IN (*BOM*.xlsx) DO SET /A COUNT_XLSX+=1

ECHO [STATUS] Deliverables ready in folder: !COUNT_PDF! PDF file(s), !COUNT_XLSX! Excel file(s).
ECHO.

REM ------------------------------------------------------------------------------
REM  6. User Consent for Automated Infor LN IDM Ingestion
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
ECHO [INFO] Upload skipped. All generated files have been kept locally.
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
REM  7. Ingesting PDF Deliverables (ELT_BOM_pdf)
REM ------------------------------------------------------------------------------
ECHO ==============================================================================
ECHO  [1/2] UPLOADING PDF DELIVERABLES (ELT_BOM_pdf)
ECHO ==============================================================================
FOR %%F IN (*BOM*.pdf) DO (
    ECHO.
    ECHO [UPLOAD] Ingesting PDF: "%%~nxF"...
    python "C:\Cadence\BOM_manager\scripts\python\upload_to_infor_idm.py" "%%~fF" "!ITEM_CODE!" "ELT_BOM_pdf"
    timeout /t 3 /nobreak >nul
)

ECHO.

REM ------------------------------------------------------------------------------
REM  8. Ingesting Excel Deliverables (ELT_BOM_excel)
REM ------------------------------------------------------------------------------
ECHO ==============================================================================
ECHO  [2/2] UPLOADING EXCEL DELIVERABLES (ELT_BOM_excel)
ECHO ==============================================================================
FOR %%F IN (*BOM*.xlsx) DO (
    ECHO.
    ECHO [UPLOAD] Ingesting Excel: "%%~nxF"...
    python "C:\Cadence\BOM_manager\scripts\python\upload_to_infor_idm.py" "%%~fF" "!ITEM_CODE!" "ELT_BOM_excel"
    timeout /t 3 /nobreak >nul
)

ECHO.
ECHO ==============================================================================
ECHO  ALL DELIVERABLES SUCCESSFULLY UPLOADED TO INFOR IDM
ECHO ==============================================================================

:EndScript
ECHO.
PAUSE