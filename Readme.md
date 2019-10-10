# LocMapper
Mapping translations from a source of truth to your code.

## Localization Process:
- Refresh the local DB with the reference translations in the drive.
  Currently you have to download a CSV from the drive and import it in your
  local DB with File -> Import Reference Translations…
  In the future, there will be a Refresh Reference Translations… menu entry,
  which will ask you to login to the drive provider the first time it's used,
  then will automatically fetch and merge an up-to-date translations from the
  drive.
- Refresh the known keys and keys structure in the local DB.
  Use File -> Import Key Structure from [Xcode|Android] Project… for this.
  This command parses the keys in the Xcode or Android project and import it
  in the local DB. Any previous key in the local DB not in the project is
  removed from the local DB. New keys will have a value of TODOLOC (until
  either they're mapped or an actual value is set).
- Filter shown keys to only show unmapped & TODOLOC keys. Map or fill the
  keys.
- Export the local DB to your project. You're done!
