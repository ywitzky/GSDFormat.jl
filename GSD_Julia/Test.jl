include("./gsd.jl")

file = "/localscratch/HPS_DATA/HPS-Janka/RS31a/run1/MDhnRNPA1seqRS31a_IDR1_M17_NP1_T300_Box10_10_10_s1000000000.gsd"

function  open(name, mode="r")
    """Open a hoomd schema GSD file.

    The return value of `open` can be used as a context manager.

    Args:
        name (str): File name to open.
        mode (str): File open mode.

    Returns:
        `HOOMDTrajectory` instance that accesses the file **name** with the
        given **mode**.

    Valid values for ``mode``:

    +------------------+---------------------------------------------+
    | mode             | description                                 |
    +==================+=============================================+
    | ``'r'``          | Open an existing file for reading.          |
    +------------------+---------------------------------------------+
    | ``'r+'``         | Open an existing file for reading and       |
    |                  | writing.                                    |
    +------------------+---------------------------------------------+
    | ``'w'``          | Open a file for reading and writing.        |
    |                  | Creates the file if needed, or overwrites   |
    |                  | an existing file.                           |
    +------------------+---------------------------------------------+
    | ``'x'``          | Create a gsd file exclusively and opens it  |
    |                  | for reading and writing.                    |
    |                  | Raise :py:exc:`FileExistsError`             |
    |                  | if it already exists.                       |
    +------------------+---------------------------------------------+
    | ``'a'``          | Open a file for reading and writing.        |
    |                  | Creates the file if it doesn't exist.       |
    +------------------+---------------------------------------------+

    """
    #if fl is None:
    #    raise RuntimeError("file layer module is not available")
    #if gsd is None:
    #    raise RuntimeError("gsd module is not available")

    #gsdfileobj = fl.open(name=str(name),mode=mode, application="gsd.hoomd " #+ gsd.version.version,schema="hoomd",schema_version=[1, 4])
    gsdfileobj = open(String(name),mode; application="gsd.hoomd ", schema="hoomd", schema_version=(1, 4))
    
    return gsdfileobj
    #return HOOMDTrajectory(gsdfileobj)
end

gsdfileobj = open(file)


dimensions_arr = read_chunk(gsdfileobj, 1,"configuration/step" )
#self.file.read_chunk( frame=idx, name='configuration/dimensions')
println(dimensions_arr)

