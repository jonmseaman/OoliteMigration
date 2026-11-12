# Exceptions list: spec 009

The places a converted pattern may remain (FR-022, data-model.md *Exceptions list*). A row is added
in the same commit as the code it permits.

`check.sh` reads this table: it drops a search hit whose file equals the row's `file` and whose
line contains the row's `match` (a fixed substring of the permitted line, written without the
surrounding backticks), for the row's `category`. A row whose construct a clang-tidy guard flags
is a conflict to record here, never a suppression.

| category | file | match | construct | required by | owner / release | commit |
|---|---|---|---|---|---|---|
| alloc | `src/Core/OODemangle.h` | `&std::free` | `std::free` as the `std::unique_ptr` deleter of the demangled name | `abi::__cxa_demangle` returns `malloc` memory the caller must `free` | the `unique_ptr` in `OODemangle`, released at scope exit | T014 |
