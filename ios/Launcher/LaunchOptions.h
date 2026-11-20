// GeneralsX @feature Codex 19/11/2026 Independent movie and shell-map preferences.
#pragma once
#include <string>
#include <vector>
inline std::vector<std::string> gxLaunchArguments(const std::string &anchor, int argc, char **argv,
                                                 bool staticMenu, bool disableMovies)
{
    std::vector<std::string> result{anchor};
    for (int i = 1; i < argc; ++i) result.emplace_back(argv[i]);
    if (staticMenu) result.emplace_back("-noshellmap");
    if (disableMovies) {
        result.emplace_back("-novideo");
        result.emplace_back("-nologo");
    }
    return result;
}
