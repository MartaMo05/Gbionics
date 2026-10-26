AutoDOC TEMPLATE PROJECT - one board
=====================================
How to start a new board:
 1. Copy the folder 31010000000_DESCRIPTION into the product folder (e.g. the git repository).
 2. Rename it <schematic code>_<description>, e.g. 31010015159_Peripheral_CB
    (schematic code = 3101..., description without spaces, use _).
 3. PCB_00 = revision 00. For a new revision copy PCB_00 to PCB_01, PCB_02, ...
 4. Put the design files in the folders below (see the README.txt in each folder).
 5. Fill in pcb_spec.json (replace every TBD; a filled-in example is in
    deploy\examples\pcb_spec_example). Images used in the notes go next to it.
 6. Run the .bat files (they use the AutoDOC scripts installed in
    C:\Cadence\BOM_manager\scripts\python, see deploy\install_autodoc.bat):
       orcad_project\make_sch_docs.bat      .BOM files, schematic PDF, checks
       bom\make_BOM.bat                     BOM + Production-BOM (XLSX, PDF)
       allegro_project\make_prod_package.bat production package, PDFs, 3D model
       make_all.bat                         all of the above + one upload to Infor
Codes: 3101... schematic, 3100<rev><last 5 digits of the schematic code> assembled board (LN item),
2100... bare PCB (.brd name). The README.txt files can be deleted.
