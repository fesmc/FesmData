# Read the properties of an ISSM model (MATLAB classdef object `md`) from a MATLAB 7.3
# (HDF5) .mat file without MATLAB or ISSM.
#
# MATLAB stores classdef objects in the hidden subsystem `/#subsystem#/MCOS`, a cell
# array whose first element is a metadata blob (names of classes and properties, and
# for each object its class and properties) and whose other elements are the property
# values. The format is not documented; this follows its description in the readers of
# SciPy and `matio` (version 3 of the metadata), enough for ISSM models: objects whose
# properties are arrays, structs and other objects.

import HDF5

struct MCOSFile
    file::HDF5.File
    cells::Vector{HDF5.Reference}            # MCOS cell array
    names::Vector{String}                    # names of classes and properties
    classes::Vector{Int}                     # class name index of each class id
    objects::Vector{Dict{String,Tuple{Int,Int}}}   # properties of each object id: name => (flag, value)
    objclass::Vector{Int}                    # class id of each object id
end

function MCOSFile(file::HDF5.File)
    cells = vec(read(file["/#subsystem#/MCOS"]))
    meta = vec(read(file[cells[1]]))
    u32(i) = Int(reinterpret(UInt32, meta[i+1:i+4])[1])     # i: 0-based byte offset
    version, nstr = u32(0), u32(4)
    version == 3 || @warn "MCOS metadata version $version, expected 3"
    offs = [u32(8 + 4k) for k in 0:7]
    names = String[]
    pos = 40
    for _ in 1:nstr
        stop = findnext(==(0x00), meta, pos + 1)
        push!(names, String(meta[pos+1:stop-1]))
        pos = stop
    end
    classes = [u32(i + 4) for i in offs[1]:16:offs[2]-1]                 # (0, name, 0, 0)
    objinfo = [(u32(i), u32(i + 16)) for i in offs[3]:24:offs[4]-1]     # (class, 0, 0, 0, prop_id, dep)
    # properties of objects saved by value: per object, n and n x (name, flag, value), 8-byte aligned
    props = Dict{String,Tuple{Int,Int}}[]
    i = offs[4]
    while i < offs[5]
        n = u32(i)
        d = Dict{String,Tuple{Int,Int}}()
        for k in 0:n-1
            j = i + 4 + 12k
            d[names[u32(j)]] = (u32(j + 4), u32(j + 8))
        end
        push!(props, d)
        i += 4 + 12n
        i % 8 == 0 || (i += 4)
    end
    objects = [prop_id == 0 ? Dict{String,Tuple{Int,Int}}() : props[prop_id+1] for (_, prop_id) in objinfo]
    return MCOSFile(file, cells, names, classes, objects, [c for (c, _) in objinfo])
end

"Class name of object `id`."
classname(m::MCOSFile, id::Int) = m.names[m.classes[m.objclass[id+1]+1]]

"Object id of a stored object reference (uint32 array: magic, ndims, dims..., ids..., class)."
function object_id(dset::HDF5.Dataset)
    a = vec(read(dset))
    return Int(a[end-1])                    # a single object
end

"""
    property(m, id, name)

Value of property `name` of object `id`: an array, a dictionary for a struct, or the
object id (`Int`) of an object.
"""
function property(m::MCOSFile, id::Int, name::String)
    flag, value = m.objects[id+1][name]
    flag == 1 || error("property $name of $(classname(m, id)): flag $flag not supported")
    obj = m.file[m.cells[value+3]]          # value 0 is the third cell
    return read_value(obj)
end

const OBJECT_MAGIC = 0xdd000000

function read_value(obj)
    obj isa HDF5.Group && return Dict(k => read_value(obj[k]) for k in keys(obj))
    v = read(obj)
    # an object: a uint32 array starting with the magic number (properties of objects
    # are stored without the attribute MATLAB_object_decode of top-level variables)
    v isa AbstractArray{UInt32} && length(v) >= 6 && first(v) == OBJECT_MAGIC && return Int(vec(v)[end-1])
    return v
end

"Property path, e.g. property(m, md, \"mesh\", \"x2d\")."
function property(m::MCOSFile, id::Int, name::String, names::String...)
    v = property(m, id, name)
    return isempty(names) ? v : property(m, v::Int, names...)
end

"Object id of the top-level variable `var` (e.g. \"md\")."
model_id(m::MCOSFile, var::String="md") = object_id(m.file[var])
