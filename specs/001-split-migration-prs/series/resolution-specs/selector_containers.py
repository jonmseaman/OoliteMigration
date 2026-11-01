# Shared by steps 8-15: the history's -cxx_getContainersOfCommodity:: has an unnamed second part, which
# Clang 23 reports (-Wmissing-selector-name) and clang-format will not let a space fix in a header. The
# part is named how_much:, as in upstream's -getContainersOfCommodity:how_much:.
CONTAINERS_RENAMES = [
    (r"\)commodity_name ?:\(OOCargoQuantity\)", r")commodity_name how_much:(OOCargoQuantity)"),
    (r"(cxx_getContainersOfCommodity:[^\]\n]*?\)|cxx_getContainersOfCommodity:\"Narcotics\"):(num|adjustment|how_many)\]",
     r"\1 how_much:\2]"),
    (r"-cxx_getContainersOfCommodity::", r"-cxx_getContainersOfCommodity:how_much:"),
]
