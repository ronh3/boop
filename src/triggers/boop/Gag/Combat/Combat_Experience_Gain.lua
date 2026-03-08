-- Attach experience gain to pending slain summary.
boop.stats.onExperienceGain(matches[2], gmcp and gmcp.Room and gmcp.Room.Info and gmcp.Room.Info.area or nil)
boop.gag.onExperienceLine(matches[2], line or "")
