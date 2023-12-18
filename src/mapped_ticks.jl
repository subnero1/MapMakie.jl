"""
    MappedTicks(; ticks = Makie.automatic, plot_to_ticks, ticks_to_plot)

Map `ticks` using the given functions.

`plot_to_ticks` and `ticks_to_plot` should be mutually inverse, i.e.
`plot_to_ticks ∘ ticks_to_plot ≈ identity`.

# Example

```
scatter(
    Point2f[(0,0)];
    axis = (;
        # These ticks will make it look as if the point was at (0,1)
        yticks = MapMakie.MappedTicks(;
            plot_to_ticks = x->x+1,
            ticks_to_plot = x->x-1,
        ),
    ),
)
```
"""
@kwdef struct MappedTicks{T,P2T,T2P}
    ticks::T = Makie.automatic
    plot_to_ticks::P2T
    ticks_to_plot::T2P
end

function Makie.get_ticks(
    ticks::MappedTicks,
    scale,
    format,
    plot_min,
    plot_max,
)
    ticks_min, ticks_max = ticks.plot_to_ticks.((plot_min, plot_max))
    (ticks_vals, labels) = Makie.get_ticks(ticks.ticks, scale, format, ticks_min, ticks_max)
    return ticks.ticks_to_plot.(ticks_vals), labels
end