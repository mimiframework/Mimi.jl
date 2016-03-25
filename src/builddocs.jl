using Lexicon
using Mimi

save(
    normpath(Pkg.dir("Mimi"), "doc", "reference.md"),
    Mimi,
    include_internal=false,
    md_subheader=:skip)
