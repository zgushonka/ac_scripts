-- macroScript Macro1
-- category:"DragAndDrop"
-- toolTip:"Exports visible objects to FBX file"
(
    deselect $*  -- Deselect any currently selected objects
	
    for obj in objects do
    (
        if not obj.isHidden do
            selectMore obj  -- Add the visible object to the selection
    )
		
    -- Set the file path and name
	fbxFileName = "g:\!_3d\export.FBX"
	
    -- Check if there are selected objects
    if selection.count > 0 then
        exportFile fbxFileName #noPrompt selectedOnly:true using:FBXEXP
)