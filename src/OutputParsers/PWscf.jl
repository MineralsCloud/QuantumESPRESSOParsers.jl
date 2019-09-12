"""
# module PWscf



# Examples

```jldoctest
julia>
```
"""
module PWscf

using Fortran90Namelists.FortranToJulia

using Compat: isnothing

using QuantumESPRESSOParsers.Utils
using QuantumESPRESSOParsers.OutputParsers

export read_stress, read_total_energy, read_qe_version, read_processors_num, read_fft_dimensions, read_cell_parameters, isjobdone

const CELL_PARAMETERS_BLOCK_REGEX = r"""
^ [ \t]*
CELL_PARAMETERS [ \t]*
\(?\w+\s*=\s*[\-|\+]?(\d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?\)? \s* [\n]
(
(
\s*
(
[\-|\+]? ( \d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?\s*
){3}[\n]
){3}
)
"""imx
const CELL_PARAMETERS_ITEM_REGEX = r"""
^                        # Linestart
[ \t]*                   # Optional white space
(?P<x>                   # Get x
    [\-|\+]? ( \d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?
)
[ \t]+
(?P<y>                   # Get y
    [\-|\+]? (\d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?
)
[ \t]+
(?P<z>                   # Get z
    [\-|\+]? (\d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?
)
"""mx
const STRESS_BLOCK_REGEX = r"""
^[ \t]*
total\s+stress\s*\(Ry\/bohr\*\*3\)\s+
\(kbar\)\s+P=\s*([\-|\+]? (?: \d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?)
[\n]
(
(?:
\s*
(?:
[\-|\+]? (?: \d*[\.]\d+ | \d+[\.]?\d*)
    ([E|e|d|D][+|-]?\d+)?[ \t]*
){6}
){3}
)
"""imx
const JOB_DONE_REGEX = r"JOB DONE\."i

const PATTERNS = [
    r"Program PWSCF v\.(\d\.\d+\.?\d?)"i,
    r"Parallelization info"i,
    r"bravais-lattice index"i,
    r"(\d+)\s*Sym\. Ops\., with inversion, found"i,
    r"number of k points=\s*(\d+)\s*(.*)width \(Ry\)=\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)"i,
    r"starting charge(.*), renormalised to(.*)"i,
    r"total cpu time spent up to now is\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*secs"i,
    r"End of self-consistent calculation"i,
    r"the Fermi energy is\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*ev"i,
    r"The total energy is the sum of the following terms:"i,
    r"convergence has been achieved in\s*(\d+)\s*iterations"i,
    r"Forces acting on atoms \(cartesian axes, Ry\/au\):"i,
    r"Computing stress \(Cartesian axis\) and pressure"i,
    r"Writing output data file\s*(.*)"i,
    r"This run was terminated on:\s*(.*)\s+(\w+)"i,
]

function read_stress(str::AbstractString)
    pressures = Float64[]
    atomic_stresses = Matrix[]
    kbar_stresses = Matrix[]
    for m in eachmatch(STRESS_BLOCK_REGEX, str)
        pressure, content = m.captures[1], m.captures[3]
        push!(pressures, parse(Float64, pressure))

        stress_atomic = Matrix{Float64}(undef, 3, 3)
        stress_kbar = Matrix{Float64}(undef, 3, 3)
        for (i, line) in enumerate(split(content, '\n'))
            tmp = map(x -> parse(Float64, x), split(strip(line), " ", keepempty = false))
            stress_atomic[i, :], stress_kbar[i, :] = tmp[1:3], tmp[4:6]
        end
        push!(atomic_stresses, stress_atomic)
        push!(kbar_stresses, stress_kbar)
    end
    return pressures, atomic_stresses, kbar_stresses
end # function parse_stress

function read_cell_parameters(str::AbstractString)
    cell_parameters = Matrix[]
    for m in eachmatch(CELL_PARAMETERS_BLOCK_REGEX, str)
        alat = parse(Float64, m.captures[1])
        content = m.captures[3]

        data = Matrix{Float64}(undef, 3, 3)
        for (i, matched) in enumerate(eachmatch(CELL_PARAMETERS_ITEM_REGEX, content))
            captured = matched.captures
            data[i, :] = map(x -> parse(Float64, FortranData(x)), [captured[1], captured[4], captured[7]])
        end
        push!(cell_parameters, alat * data)
    end
    return cell_parameters
end # function read_cell_parameters

function read_total_energy(str::AbstractString)
    result = Float64[]
    for m in eachmatch(r"!\s+total energy\s+=\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*Ry"i, str)
        push!(result, parse(Float64, FortranData(m.captures[1])))
    end
    return result
end # function read_total_energy

function read_qe_version(line::AbstractString)
    m = match(r"Program PWSCF v\.(\d\.\d+\.?\d?)"i, line)
    isnothing(m) && error("Match error!")
    return "$(parse(Float64, FortranData(m.captures[1])))"
end # function read_qe_version

function read_processors_num(line::AbstractString)
    m = match(r"(?:Parallel version \((.*)\), running on\s+(\d+)\s+processor|Serial version)"i, line)
    isnothing(m) && error("Match error!")
    isnothing(m.captures) && return "Serial version"
    return m.captures[1], parse(Int, m.captures[2])
end # function read_processors_num

function read_fft_dimensions(line::AbstractString)
    m = match(r"Dense  grid:\s*(\d+)\s*G-vectors     FFT dimensions: \((.*),(.*),(.*)\)"i, line)
    isnothing(m) && error("Match error!")
    return map(x -> parse(Int, FortranData(x)), m.captures)
end # function read_fft_dimensions

isjobdone(str::AbstractString) = !isnothing(match(JOB_DONE_REGEX, str))

end
