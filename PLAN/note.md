Hey! Thanks for the feedback - just pushed fixes:

1. **Added missing `requests` dependency** - should resolve the `ModuleNotFoundError`

2. **Clarified the `-w` flag** - it's on the `dashboard` subcommand:
   ```bash
   mech dashboard -w "C:\Path\To\SavedVariables"
   ```
   (not `mech -w`)

3. **Updated docs** - Fixed incorrect CLI syntax and removed references to commands that don't exist

**To update:**
```bash
cd !Mechanic/desktop
git pull
pip install -e .
```

Let me know if you hit any other issues!
