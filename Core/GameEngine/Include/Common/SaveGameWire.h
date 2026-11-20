// GeneralsX @feature Codex 20/11/2026 Portable save metadata and Windows-compatible Unicode.
#pragma once
#include <cstdint>
#include <string>
#include <vector>
namespace gxsave {
struct Header { int characterBytes=0; unsigned version=0; uint32_t fileType=0; std::wstring description; std::string map, campaign; };
inline std::vector<uint16_t> toUtf16(const wchar_t *text, size_t length) {
    std::vector<uint16_t> out;
    for(size_t i=0;i<length;++i) {
        uint32_t cp=static_cast<uint32_t>(text[i]);
        if(sizeof(wchar_t)==2) { out.push_back(static_cast<uint16_t>(cp)); continue; }
        if(cp>0x10ffff || (cp>=0xd800 && cp<=0xdfff)) cp=0xfffd;
        if(cp<0x10000) out.push_back(static_cast<uint16_t>(cp));
        else { cp-=0x10000;out.push_back(0xd800+(cp>>10));out.push_back(0xdc00+(cp&1023)); }
    }
    return out;
}
inline std::wstring fromUnits(const uint32_t *units,size_t count,int width) {
    std::wstring out;
    for(size_t i=0;i<count;++i) {
        uint32_t cp=units[i];
        if(width==2 && cp>=0xd800 && cp<=0xdbff && i+1<count && units[i+1]>=0xdc00 && units[i+1]<=0xdfff)
            cp=0x10000+((cp-0xd800)<<10)+(units[++i]-0xdc00);
        else if(cp>0x10ffff || (cp>=0xd800 && cp<=0xdfff)) cp=0xfffd;
        if(sizeof(wchar_t)==2 && cp>0xffff) {cp-=0x10000;out.push_back(static_cast<wchar_t>(0xd800+(cp>>10)));out.push_back(static_cast<wchar_t>(0xdc00+(cp&1023)));}
        else out.push_back(static_cast<wchar_t>(cp));
    }
    return out;
}
inline uint32_t little32(const uint8_t *p) {return uint32_t(p[0])|(uint32_t(p[1])<<8)|(uint32_t(p[2])<<16)|(uint32_t(p[3])<<24);}
inline bool parseHeader(const uint8_t *data,size_t size,int width,Header &result) {
    if(!data || size<18 || (width!=2 && width!=4))return false;
    size_t pos=0;Header h;h.version=data[pos++];h.characterBytes=width;
    if(h.version<1 || h.version>2)return false;
    auto ascii=[&](std::string &out) {if(pos>=size)return false;size_t n=data[pos++];if(n>size-pos)return false;out.assign(reinterpret_cast<const char*>(data+pos),n);pos+=n;for(unsigned char c:out)if(c<32)return false;return true;};
    if(h.version>=2) {if(size-pos<4)return false;uint32_t kind=little32(data+pos);pos+=4;if(kind>1)return false;h.fileType=kind;std::string mission;if(!ascii(mission))return false;}
    if(size-pos<17)return false;pos+=16;size_t n=data[pos++];
    if(n>(size-pos)/width)return false;std::vector<uint32_t> units;
    for(size_t i=0;i<n;++i) {uint32_t cp=0;for(int b=0;b<width;++b)cp|=uint32_t(data[pos++])<<(8*b);if(cp>0x10ffff)return false;units.push_back(cp);}
    h.description=fromUnits(units.data(),units.size(),width);
    if(!ascii(h.map) || !ascii(h.campaign) || size-pos!=4)return false;
    result=h;return true;
}
inline int detectHeader(const uint8_t *data,size_t size,Header *metadata=nullptr) {
    Header h;
    for(int width:{2,4})if(parseHeader(data,size,width,h)){if(metadata)*metadata=h;return width;}
    return 0;
}
}
