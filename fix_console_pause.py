import os

locales_dir = r"C:\Program Files (x86)\World of Warcraft\_dev_\!Mechanic\Locales"

replacements = {
    'L["Pause"] = "Pause"': 'L["Pause"] = "|A:common-icon-pause:14:14|a Pause"',
    'L["Resume"] = "Resume"': 'L["Resume"] = "|A:common-icon-forward:14:14|a Resume"'
}

for filename in os.listdir(locales_dir):
    if filename == "enUS.lua" or not filename.endswith(".lua"):
        continue
    
    path = os.path.join(locales_dir, filename)
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    
    changed = False
    for old, new in replacements.items():
        if old in content:
            content = content.replace(old, new)
            changed = True
    
    if changed:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated {filename}")

