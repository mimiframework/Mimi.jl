#
# To simplify debugging, export all symbols for use in REPL
#
macro import_all(pkg)
    function ok_to_import(symbol)
        ! (symbol in (:eval, :show, :include, :name) || string(symbol)[1] == '#')
    end

    symbols = Iterators.filter(ok_to_import, names(eval(pkg), all=true))
    symlist = join(symbols, ",")
    return Meta.parse("import $pkg: $symlist")
end

using Mimi
@import_all(Mimi)
