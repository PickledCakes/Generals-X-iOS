// GeneralsX @feature Codex 20/11/2026 Bounded save validation and non-destructive import.
#pragma once
#include "Common/SaveGameWire.h"
#include <filesystem>
#include <fstream>
#include <atomic>
#include <chrono>
#include <algorithm>
#include <cstdio>
#include <cctype>
#include <stdexcept>
#include <set>
namespace gxsave {
struct FileInfo {std::filesystem::path path;Header header;};
inline FileInfo inspect(const std::filesystem::path &path) {
    std::ifstream in(path,std::ios::binary);if(!in)throw std::runtime_error("The save file could not be opened.");
    in.seekg(0,std::ios::end);auto end=in.tellg();if(end<24 || end>512LL*1024*1024)throw std::runtime_error("The file is empty, incomplete, or larger than 512 MB.");in.seekg(0);
    FileInfo info;info.path=path;bool first=true,logic=false,map=false,campaign=false;
    for(int chunks=0;chunks<1024;++chunks) {
        int n=in.get();if(n<=0 || n>128)break;
        std::string token(n,'\0');if(!in.read(token.data(),n))break;
        if(token=="SG_EOF") {if(!first && in.tellg()==end && campaign && (info.header.fileType==1 || (logic && map)))return info;break;}
        if(token.rfind("CHUNK_",0)!=0)break;
        if(token=="CHUNK_GameLogic")logic=true;if(token=="CHUNK_GameStateMap")map=true;if(token=="CHUNK_Campaign")campaign=true;
        uint8_t raw[4];if(!in.read(reinterpret_cast<char*>(raw),4))break;
        uint32_t size=little32(raw);auto pos=in.tellg();if(pos<0 || size>static_cast<uint64_t>(end-pos))break;
        if(first) {
            if(token!="CHUNK_GameState" || size>4096)break;
            std::vector<uint8_t> payload(size);if(!in.read(reinterpret_cast<char*>(payload.data()),size))break;
            if(!detectHeader(payload.data(),payload.size(),&info.header))break;
            first=false;
        } else in.seekg(size,std::ios::cur);
    }
    throw std::runtime_error("This is not a recognized, complete Generals save file.");
}
inline std::filesystem::path importFile(const std::filesystem::path &source,const std::filesystem::path &directory) {
    auto extension=source.extension().string();std::transform(extension.begin(),extension.end(),extension.begin(),[](unsigned char c){return std::tolower(c);});
    if(extension!=".sav")throw std::runtime_error("Choose a .sav file, not a replay or an archive.");
    if(!std::filesystem::is_regular_file(source) || std::filesystem::file_size(source)<24 || std::filesystem::file_size(source)>512ULL*1024*1024)
        throw std::runtime_error("Choose a complete .sav file no larger than 512 MB.");
    std::filesystem::create_directories(directory);
    static std::atomic<unsigned> sequence{0};
    auto stamp=std::chrono::steady_clock::now().time_since_epoch().count();
    auto staging=directory/(".import-"+std::to_string(stamp)+"-"+std::to_string(++sequence));
    struct Cleanup {std::filesystem::path path;~Cleanup(){std::error_code error;std::filesystem::remove(path,error);}} cleanup{staging};
    std::filesystem::copy_file(source,staging,std::filesystem::copy_options::none);
    inspect(staging);
    std::filesystem::permissions(staging,std::filesystem::perms::owner_read|std::filesystem::perms::owner_write,std::filesystem::perm_options::add);
    std::set<std::string> occupied;
    for(const auto &entry:std::filesystem::directory_iterator(directory)) {
        auto name=entry.path().filename().string();
        std::transform(name.begin(),name.end(),name.begin(),[](unsigned char c){return std::tolower(c);});occupied.insert(name);
    }
    for(unsigned i=0;i<100000000;++i) {
        char filename[32];std::snprintf(filename,sizeof(filename),"%08u.sav",i);
        if(occupied.count(filename))continue;
        auto destination=directory/filename;std::error_code error;
        std::filesystem::create_hard_link(staging,destination,error);
        if(!error)return destination;
        if(error && error!=std::errc::file_exists)throw std::filesystem::filesystem_error("The save could not be imported",destination,error);
    }
    throw std::runtime_error("No unused save slot is available.");
}
}
