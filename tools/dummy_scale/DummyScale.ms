-- Dummy scale
-- zgush v1.3 20240521

selected = selection as array
format "Selected objects count: %\n" selected.count

size = .25
for i = 1 to selected.count do (
	aObject = selected[i]
	if classof aObject == Dummy then (
		aObject.boxsize = [size, size, size]
	) 
)
