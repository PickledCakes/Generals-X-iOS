# Adding a Zero Hour mod profile

The collection uses build-time `ios/profiles/catalog.json` entries and a generated bundle `GameProfiles.plist`. The launcher, save browser, diagnostics and engine selection read that list. Each included profile owns `Games/<id>/GameData` and `Library/Application Support/GeneralsX/<id>`; never reuse another profile's ID for an incompatible mod.

Use a full installed Zero Hour + mod folder as the source. Install/activate the mod on Windows first if it uses a custom installer; this builder does not execute Windows installers or recreate arbitrary Windows-only launchers/injectors. Mods requiring DLL injection or executable patches need separate native-engine work and are not supported just by adding a profile.

Add an entry, for example:

```json
{
  "id": "ExampleMod",
  "title": "EXAMPLE MOD",
  "subtitle": "Custom Zero Hour content",
  "engine": "ZeroHourEngine",
  "recipe": "retail",
  "icon": "ZeroHourIcon",
  "checksum": "example-mod.json",
  "activateArchives": {"!Example.gib": "!Example.big"},
  "disableScripts": ["Data/Scripts/SkirmishScripts.scb"]
}
```

Keep only the fields actually needed. An already active BIG-based mod can omit `activateArchives` and use the retail copy recipe. Root `!` archives receive priority over retail patches; among mod archives the normal filename ordering is preserved. Loose content overrides can still take precedence, so deactivate only the stock scripts specifically required by that mod's launcher. The ShockWave profile demonstrates a specialized activation-map recipe and SPE replacement files.

Profile IDs allow letters, digits, underscores and hyphens, beginning with a letter; IDs must be unique and at most 48 characters. Custom profiles currently use `ZeroHourEngine`; custom original-Generals identities need additional legacy engine storage work. Use an existing icon key or extend the build-time icon extractor with artwork supplied by the user. The launcher scrolls horizontally for more than three profiles; keep titles concise.

To add reference checksums, create `ios/profiles/checksums/example-mod.json`:

```json
{"schemaVersion":1,"reference":"Your documented mod version","sha256":{"!Example.gib":"64-character SHA-256 digest"}}
```

Only reference stable, non-account-dependent content. Never add EXEs/DLLs, Steam manifests, DRM data, saves or launcher account configuration. Differences remain warning-only. Omitting `checksum` produces a warning that no reference manifest is available and continues; it does not imply the mod was verified.

Select the new ID in your ignored local build configuration. Test startup, a real mission, loading/saving, restart, and isolation from normal Zero Hour. For an incompatible engine/schema change, give the profile a new ID and explain save compatibility rather than sharing old saves silently. Keep mod credits and version details with the profile; do not commit the mod archives themselves.
