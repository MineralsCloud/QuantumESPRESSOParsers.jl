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

export mark_lines, mark_ranges, parse_total_energy, parse_qe_version, parse_processors_num, parse_fft_dimensions

function mark_lines(patterns, lines)
    marks = LineNumber[]
    patterns = copy(PATTERNS)  # Cannot use `PATTERNS` directly, it will be modified!
    for (n, line) in enumerate(lines)
        for (i, p) in enumerate(patterns)
            if occursin(p, line)
                push!(marks, LineNumber(n))
                deleteat!(patterns, i)
            end
        end
    end
    marks
end # function mark_lines

function mark_ranges(patterns, lines)
    [LineRange(r) for r in split_to_ranges(collect(getfield(x, :n) for x in mark_lines(patterns, lines)))]
end # function mark_ranges

const PATTERNS = [
    r"Program PWSCF v\.(\d\.\d+\.?\d?)"i,
    r"(?:Parallel version \((.*)\), running on\s+(\d+)\s+processor|Serial version)"i,
    r"Parallelization info"i,
    r"bravais-lattice index"i,
    r"(\d+)\s*Sym\. Ops\., with inversion, found"i,
    r"number of k points=\s*(\d+)\s*(.*)width \(Ry\)=\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)"i,
    r"Dense  grid:\s*(\d+)\s*G-vectors     FFT dimensions: \((.*),(.*),(.*)\)"i,
    r"starting charge(.*), renormalised to(.*)"i,
    r"total cpu time spent up to now is\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*secs"i,
    r"End of self-consistent calculation"i,
    r"the Fermi energy is\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*ev"i,
    r"!\s+total energy\s+=\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*Ry"i,
    r"The total energy is the sum of the following terms:"i,
    r"convergence has been achieved in\s*(\d+)\s*iterations"i,
    r"Forces acting on atoms \(cartesian axes, Ry\/au\):"i,
    r"Computing stress \(Cartesian axis\) and pressure"i,
    r"Writing output data file\s*(.*)"i,
    r"This run was terminated on:\s*(.*)\s+(\w+)"i,
    r"JOB DONE\."i
]

# function parse_stress(lines)
#     stress_atomic = zeros(3, 3)
#     stress_kbar = zeros(3, 3)
#     stress = Dict("atomic" => stress_atomic, "kbar" => stress_kbar)
#     for line in lines
#         if occursin("total   stress", line)
#             for i in 1:3  # Read a 3x3 matrix
#                 readline()
#                 sp = split(line)
#                 stress_atomic[i][:] = map(x -> parse(Float64, FortranData(x)), sp)[1:3]
#                 stress_kbar[i][:] = map(x -> parse(Float64, FortranData(x)), sp)[4:6]
#             end
#         end
#     end
#     return stress
# end # function parse_stress

function parse_total_energy(line::AbstractString)
    m = match(r"!\s+total energy\s+=\s*([-+]?\d*\.?\d+((:?[ed])[-+]?\d+)?)\s*Ry"i, line)
    isnothing(m) && error("Match error!")
    return parse(Float64, FortranData(m.captures[1]))
end # function parse_total_energy

function parse_qe_version(line::AbstractString)
    m = match(r"Program PWSCF v\.(\d\.\d+\.?\d?)"i, line)
    isnothing(m) && error("Match error!")
    return "$(parse(Float64, FortranData(m.captures[1])))"
end # function parse_qe_version

function parse_processors_num(line::AbstractString)
    m = match(r"(?:Parallel version \((.*)\), running on\s+(\d+)\s+processor|Serial version)"i, line)
    isnothing(m) && error("Match error!")
    isnothing(m.captures) && return "Serial version"
    return m.captures[1], parse(Int, m.captures[2])
end # function parse_processors_num

function parse_fft_dimensions(line::AbstractString)
    m = match(r"Dense  grid:\s*(\d+)\s*G-vectors     FFT dimensions: \((.*),(.*),(.*)\)"i, line)
    isnothing(m) && error("Match error!")
    return map(x -> parse(Int, FortranData(x)), m.captures)
end # function parse_fft_dimensions

end
