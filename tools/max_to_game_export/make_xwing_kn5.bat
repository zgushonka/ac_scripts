@echo off

@REM !!! Put YOUR paths here.

copy "g:\!_3d\export.FBX" "g:\!_3d\My_SW_Fighter\export_xwing\xwing_t65.FBX"

set "ksEditorAtPath=g:\!_3d\tools\ksEditor\ksEditorAt.exe"
set "carPath=g:\!_3d\\My_SW_Fighter\export_xwing\"
set "carFile=%carPath%\zg_xwing_t65.kn5"

%ksEditorAtPath% kn5 %carFile% %carPath%\xwing_t65.FBX

copy "%carFile%" "g:\SteamLibrary\steamapps\common\assettocorsa\content\cars\aazg_zdev_sw_x-wing_t65\zg_xwing_t65.kn5"

