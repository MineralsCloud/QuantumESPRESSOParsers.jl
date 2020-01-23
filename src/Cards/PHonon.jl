module PHonon

using Compat: isnothing, only
using Fortran90Namelists.FortranToJulia: FortranData
using QuantumESPRESSOBase.Cards.PHonon: SpecialQPoint, QPointsSpecsCard

const Q_POINTS_SPECIAL_BLOCK_REGEX = r"""
^ [ \t]* qPointsSpecs [ \t]*$\n
^ [ \t]* \S+ [ \t]* $\n  # nqs
(?P<block>
 (?:
  ^ [ \t]* \S+ [ \t]+ \S+ [ \t]+ \S+ [ \t]+ \S+ [ \t]* $\n?
 )+
)
"""imx

const Q_POINTS_SPECIAL_ITEM_REGEX = r"""
^ [ \t]* 
([\-|\+]?(?:\d*[\.]\d+ | \d+[\.]?\d*)
    (?:[E|e|d|D][+|-]?\d+)?)\h*
([\-|\+]?(?:\d*[\.]\d+ | \d+[\.]?\d*)
    (?:[E|e|d|D][+|-]?\d+)?)\h*
([\-|\+]?(?:\d*[\.]\d+ | \d+[\.]?\d*)
    (?:[E|e|d|D][+|-]?\d+)?)\h*
([\-|\+]?(?:\d*[\.]\d+ | \d+[\.]?\d*)
    (?:[E|e|d|D][+|-]?\d+)?)\h*
"""imx

function Base.parse(::Type{<:QPointsSpecsCard}, str::AbstractString)
    m = match(Q_POINTS_SPECIAL_BLOCK_REGEX, str)
    if !isnothing(m)
        captured = only(m.captures)
        data = SpecialQPoint[]
        for matched in eachmatch(Q_POINTS_SPECIAL_ITEM_REGEX, captured)
            # TODO: Match `nqs`
            point = SpecialQPoint(map(x -> parse(Float64, FortranData(x)), matched.captures)...)
            push!(data, point)
        end
        return QPointsSpecsCard(data)
    end
    @info "Cannot find card `Q_POINTS`!"
end # function Base.parse

end
