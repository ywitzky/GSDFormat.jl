# Julia wrapper for the GSD data format

This is a Julia wrapper for the gsd data format used by the [HOOMD-blue](https://glotzerlab.engin.umich.edu/hoomd-blue/) simulation package.

### Installation

```
using Pkg 
Pkg.add("GSD")
```

### Usage

```
trajectory = GSD.open("path/to/file")

for (i,frame) in enumerate(trajectory)
    position_subset = frame.particles.position[1:NAtoms,1:NDim]
    do_compute(position_subset)
end
```
This library tries to be as close to the usage of the [original python](https://gsd.readthedocs.io/en/v3.2.1/hoomd-examples.html) implementation of the [gsd package](https://github.com/glotzerlab/gsd).

### Support

Windows is not support since gsd builds on unix calls such as pwrite etc. Plattforms that are supported can be found in the Binaries at [JuliaBinaryWrappers](https://github.com/JuliaBinaryWrappers/libgsd_jll.jl).


### Warning 

GSD special particle type "type_shapes" is untested as of now. 

