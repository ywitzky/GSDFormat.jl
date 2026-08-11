module libgsd

import CBinding: values, fields
using  CBinding, libgsd_jll#,  Scratch, BinaryBuilder
#Libdl,

### use same unique id as in build step

libpath="$(libgsd_jll.artifact_dir)/lib/"

const c"int8_t"  = Int8
const c"int16_t" = Int16
const c"int32_t" = Int32
const c"int64_t" = Int64
const c"uint8_t"  = UInt8
const c"uint16_t" = UInt16
const c"uint32_t" = UInt32
const c"uint64_t" = UInt64
const c"size_t"  = Csize_t
const c"ssize_t" = Cssize_t
const c"NULL"= Nothing


#c`-std=c17 -Wall -I$(path) -L$(path) -I$(path)gsd.c -L$(libpath) -llibgsd.so`
c`-std=c17 -Wall "-I$(libgsd_jll.artifact_dir)/include"  -l$(libgsd_jll.artifact_dir)/lib/libgsd.so`

c"""
#include <gsd.h>
"""ji

#include <gsd.c>

function getNULL()::Cptr{Cvoid}
    return Cptr{Cvoid}(0x0000000000000000)
end

function isNULL(ptr::Cptr{T}) where {T<:Any}
    return ptr==Cptr{Cvoid}(0x0000000000000000)
end

removeNonASCII_(str::AbstractString) = String([Char(c) for c in str if isascii(c)])

end
