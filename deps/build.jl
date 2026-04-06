# deps/build.jl

using Libdl

println("Building bonmin bridge...")

# Paths (relative to deps/)
root = normpath(joinpath(@__DIR__, ".."))
src = joinpath(root, "deps", "src", "bonmin_bridge.cpp")
libdir = joinpath(root, "deps", "lib")

# Ensure output directory exists
mkpath(libdir)

# Output library name (portable extension)
libname = "libbonmin_bridge." * Libdl.dlext
out = joinpath(libdir, libname)

# Compiler command
cmd = `g++ -std=c++17 -fPIC -shared \
    $src \
    -o $out \
    -I/usr/include/coin \
    -I./include \
    -DHAVE_CSTDDEF \
    -lbonmin -lipopt`

println("Running: ", cmd)

# Execute build
try
    run(cmd)
    println("Build successful: ", out)
catch e
    println("Build failed!")
    rethrow(e)
end