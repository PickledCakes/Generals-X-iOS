# Building the iOS collection

## Prerequisites

Use macOS with full Xcode and its iOS SDK installed. Launch Xcode once to install components/accept its license, and choose Xcode's command-line tools in Settings → Locations. Install Homebrew tools listed in the README. Install the LunarG macOS Vulkan SDK with iOS MoltenVK support; the development build used SDK 1.4.363.0. `export VULKAN_SDK="$HOME/VulkanSDK/<installed-version>/macOS"` overrides automatic discovery.

Xcode signing is optional when producing an IPA for another signing tool. Direct device installation requires your own Apple Account in Xcode, your own Team ID, an available unique bundle identifier, a trusted/unlocked device and Developer Mode. Apple account sign-in and system trust prompts are handled by Apple/Xcode, not by this script. Free Personal Team provisioning requires periodic renewal; consult Apple's current account documentation.

## Supply entire installations

Copy installed files from your own Windows installation (or your own extracted Steam installation), not shortcuts or installer executables. You can keep folders anywhere, including an ignored local `GameFiles/` folder:

```
GameFiles/
  Generals/              # original game's root BIG archives and Data folder
  ZeroHour/              # Zero Hour root BIG archives, Data, and bundled ZH_Generals fallback if present
  ShockWaveSPE/          # complete ZH installation with ShockWave and SPE already applied
```

Do not merge the folders. The builder copies content to separate read-only app subdirectories and never renames or edits the supplied installation. For ShockWave, both inactive `.gib` files and already activated `.big` files are accepted according to its launcher file map. The currently supplied profile uses the standard cameo selection rather than activating additional classic-cameo archives.

The known reference manifests cover Steam English Generals 1.08, Zero Hour 1.04 and ShockWave 1.201 + SPE 2.1.3. These are compatibility references, not an official authenticity certificate. Different retail/language/mod versions can warn and still work. English is the tested language; missing localized assets can produce missing labels or movies.

## Interactive or configured build

Run `./build.command`, choose profile numbers and paste/drag each full installation path. Leave Team ID blank for an unsigned IPA. Supply your own Team ID and unique bundle identifier for signing. Your paths/signing selections live only in ignored `build.local.json`.

For repeatable noninteractive use, copy `build.example.json` to `build.local.json` and edit it:

```json
{
  "bundleId": "com.yourname.generalsx",
  "teamId": "YOURTEAMID",
  "profiles": [
    {"id": "Generals", "source": "/path/to/Generals"},
    {"id": "GeneralsZH", "source": "/path/to/Zero Hour"}
  ]
}
```

Only selected profiles appear in the launcher/save browser and only their required engine frameworks are packaged. Selecting only ShockWave + SPE does not add a normal Zero Hour launcher choice; its own full mod installation supplies the required retail foundation. Rebuilding with a smaller selection clears previous staged profiles so unselected content is not left in the bundle.

Commands:

```sh
./build.command                          # build and package selected profiles
./build.command --unsigned               # ad-hoc IPA, to be signed separately
./build.command --install                # sign and install; asks if several devices are connected
./build.command --prepare-only           # advisory checks + content staging, no compiler/signing
./build.command --config /path/local.json
python3 -m unittest discover -s scripts/build/ios/tests -v
```

Save active progress before installing an update. Keeping the same bundle identifier/signing identity is important when updating an existing installation; changing identifiers installs a different app with different user data.

## What happens

The helper validates selected profile IDs and paths, prints advisory SHA-256 warnings, stages only selected content, downloads pinned fonts/MoltenVK, configures CMake's `ios-vulkan` preset and builds the required engine target(s). It initializes only the needed pinned DXVK submodule, not every historical reference repository. `Patches/dxvk-ios.patch` captures the local iOS dependency changes and applies idempotently.

If `VCPKG_ROOT` is unset, the helper clones a pinned vcpkg checkout into ignored `.cache/vcpkg`; an explicitly supplied `VCPKG_ROOT` is treated as user-managed. Dependency references are recorded in `ios/profiles/dependency-lock.json` and the existing upstream CMake/vcpkg manifests. First builds download and compile dependencies and can take substantially longer than rebuilds.

The native launcher is generated with XcodeGen. The final app is assembled directly from built frameworks, runtime libraries and staged content: it does not require pre-existing standalone Generals/ZH apps. Icons are generated locally from installed ICO files and mapped texture atlas regions. Missing artwork yields neutral generated letter tiles, not a failed build or a downloaded retail image.

For developers reusing an already compatible iOS engine cache:

```sh
./build.command --skip-engine-build --engine-build-dir /path/to/build/ios-vulkan --unsigned
```

That flag does not validate that a foreign engine cache contains this fork's required fixes. Normal users should use the default source build.

## Checksum policy

Only explicit stable asset paths in `ios/profiles/checksums/*.json` are checksummed. Account-sensitive/DRM/Steam data, all executables/DLLs, `game.dat`, `gensec*.big`, launcher settings and user saves/caches are excluded. Every mismatch or missing reference file is reported by name, with a warning count and continued build. Unknown files are not authenticated. Reports stay in ignored `build/ios-content/checksum-report.json` and contain relative asset names, not account details.

Checksum differences never fail the checksum phase. Missing source folders, missing required mod activation files, unsafe paths, compiler failures or signing failures still produce real build errors. This distinction prevents checksum strictness from blocking legitimate variants without pretending unusable inputs can compile/run successfully.

## Troubleshooting

- **No BIG archives:** choose the installed game's actual root folder, not Downloads or a parent containing several games.
- **Missing Vulkan headers/library:** select the full LunarG SDK path, including its iOS MoltenVK library, rather than Homebrew's Vulkan loader.
- **Signing identity/session errors:** resolve Apple Account sign-in in Xcode and verify Team ID/bundle identifier. No account password belongs in a config file or repository.
- **Missing mod files:** supply a fully installed mod/add-on folder, including its retail game foundation and launcher activation map.
- **Different checksums:** review the listed files and reference version; warnings allow the build to continue.
- **Runtime crashes:** export launcher Diagnostics and note profile, mission, source game release and reproduction steps. Keep saves backed up through the launcher.

## Validation

The inherited/modified native engines and three-profile development app have been built and exercised on an iPad mini A17 Pro. The public helper's content tests cover advisory mismatches, missing references, excluded account files, case-insensitive lookup, non-mutating mod activation, path/symlink isolation and optional profile selection. Real supplied installations are used for staging checks. The public native launcher is also compiled/packaged using the already tested engine cache.

A fully cold dependency/engine build on an unrelated Mac, all language/store variants, every mod mission and every supported iOS device are not claimed as validated. This release is intended for community testing with explicit limitations, not as a claim of universal compatibility.
