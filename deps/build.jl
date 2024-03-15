using LibGit2, CMake, Scratch

### create unique id since it will use main in build step but the according module in wrapper otherwise
global cpp_dir = get_scratch!(Base.UUID(0),"gsd_cpp")

if !isempty(readdir(cpp_dir))
    println("GSD: Delete $cpp_dir if github should be checked for updates.")
else
    println("GSD: https://github.com/glotzerlab/gsd.git.")
    LibGit2.clone("https://github.com/glotzerlab/gsd.git", cpp_dir)
end

### TODO: remove implicit gcc & make dependency
println("GSD: Compile libgsd.so")
cd("$cpp_dir/gsd/")
run(`$cmake CMakeLists.txt`)
run(`make gsd.o`)
run(`gcc -g -shared -o libgsd.so ./CMakeFiles/fl.dir/gsd.o`)

include("../src/libgsd_wrapper.jl")


