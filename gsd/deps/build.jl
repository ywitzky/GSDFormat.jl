using LibGit2, CMake

println(pathof(LibGit2))
#folder_dir=strip(pathof(GSD), "src/LibGit2.jl")
#cpp_dir = "$(folder_dir)gsd_cpp/"

cpp_dir = "/uni-mainz.de/homes/ywitzky/Code_Projects/gsd/gsd/gsd_cpp"
println(cpp_dir)

if isdir(cpp_dir)
    println("GSD: Delete $cpp_dir if github should be checked for updates.")
else
    println("GSD: https://github.com/glotzerlab/gsd.git.")
    LibGit2.clone("https://github.com/glotzerlab/gsd.git", cpp_dir)
end

### TODO: move into Scratch space using Scratch.jl
### TODO: remove implicit gcc dependency
println("GSD: Compile libgsd.so")
cd("$cpp_dir/gsd/")
run(`$cmake CMakeLists.txt`)
run(`make gsd.o`)
run(`gcc -g -shared -o libgsd.so ./CMakeFiles/fl.dir/gsd.o`)

include("../src/libgsd_wrapper.jl")


