local value = boop.util.safeLower(boop.util.trim(matches[2] or ""))
boop.ui.setPrequeueEnabled(value == "on")
