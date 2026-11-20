# Source and runtime notices

This fork retains upstream copyright/license notices and the full EA GPLv3 license with additional terms in LICENSE.md. The modified engine and build integration are source, not a license to retail artwork, audio, movies, trademarks or third-party mod packages. No affiliation with EA, Valve, Apple, SWR Productions or SPE's author is claimed.

Runtime dependencies retain their respective upstream licenses: SDL3/SDL3_image, DXVK, MoltenVK, OpenAL Soft, FFmpeg and its enabled codec dependencies, FreeType, zlib, libpng and other packages selected by the pinned CMake/vcpkg manifests. Consult each pinned dependency's source/license for redistribution obligations, especially when redistributing binaries. vcpkg's installed share/<port>/copyright files are available in the local build tree and must accompany a binary redistribution as applicable. This repository does not relicense those libraries under a single new license.

The font helper uses Liberation Fonts 2.1.5, renamed to satisfy legacy font lookups. It retains the font license beside the staged fonts. Generated game/mod icons stay local and are excluded from Git. Screenshots supplied by the project owner illustrate the interface; third-party game/mod artwork remains owned by its respective creators.

A release binary containing game/mod content built locally is not an asset-free download. Public project releases should distribute source/build tooling and require users to supply their own installations. Do not publish provisioning profiles, private signing keys, Apple Account credentials, personal saves or complete retail/mod folders.
