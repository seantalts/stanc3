# Upstream bugs fixed in this fork

This file lists compiler bugs that came from stan-dev/stanc3 and that this fork
had to fix. Most are in the `--O1` passes. Bugs that the fork introduced itself are not
listed. Add an entry in the same commit as the fix.

Each entry says what went wrong, how it was found, and which commit fixed it.
"Fuzzer" means stanli's differential fuzzer (seantalts/stanli#581), which
compares unoptimized and optimized output of the same program.

## Wrong results

| Pass | What went wrong | Found by | Fix |
| --- | --- | --- | --- |
| Function inlining | A `return` inside a `while` loop left only that loop. Execution fell through to the function's last `return`, and dead code elimination then removed the real value. A void `return` that was not the last statement was dropped, so the code after it always ran. | not recorded | f33307e73 |
| Function inlining | An inlined function kept the autodiff levels of its formal arguments after data actuals were substituted. A `~` statement then kept constant terms that unoptimized code drops: `tau ~ normal(0, widen(s))` with data `s` gave lp -1.7919 at O1 and -0.000139 at O0. (stan-dev/stanc3#1770) | EpiNow2 models | 06421a01e, 21015fae0, 9386c2d72 |
| Function inlining | A tuple argument with an effect, read twice in the body, was evaluated twice. RNG draws, prints and rejects repeated. | seantalts/stanli#568 | 43fb2ee62 |
| Function inlining | When the second operand of `&&` or `\|\|`, or a branch of a ternary, held an inlined call, the condition was evaluated twice: once to guard the inlined statements and once in the expression. The inliner also guarded empty statement lists, which evaluated the condition once more on its own. `if (0.5 > normal_rng(0, 1) \|\| 1)` drew twice, so every later draw in generated quantities differed from unoptimized code. | Fuzzer | 5416cfd41 |
| Function inlining | A call in a `while` condition or a `for` loop's upper bound was evaluated before the loop and again at the end of the body. A `continue` skipped the second evaluation, so the loop tested a stale value: `while (g(i) < 3) { i += 1; n += 1; if (n < 10) continue; }` ended with `n = 10` at O1 and `n = 3` at O0. Each nested loop of this kind also doubled the code. | Fuzzer, while studying slow compiles | cf3e2fd98 |
| Copy propagation | An assignment from a variable to a global, such as `a = y` for a generated quantity `a`, did not end the copies that read `a`. After `real c = a; a = y; b = c;`, `b = c` became `b = a`, and `b` took the new value. | Fuzzer | c15e9fc35 |
| Dead code elimination | An unused `_rng` call was removed, so every later draw differed from unoptimized code. | seantalts/stanli#568 | 1d9c02804 |
| Dead code elimination | An assignment to an unused vector, matrix or array was removed, and with it the check that the right-hand side has the declared size. An assignment through an unused index lost its bounds check the same way. `matrix[2, 3] z = [[1, 2, 3, 4], [4, 5, 6, 8]];` throws at O0 and ran at O1. The fix keeps the check in the MIR that stanli reads. The C++ backend still skips it, as listed under Open. | Fuzzer, on stanc3's own test models | 728a5e3c8 |
| Dead code elimination | An unused assignment whose right-hand side could throw was removed, so the error was lost. `real a = integrate_1d(foo, 0.2, ub, ...);` with `ub < 0.2` throws at O0 and ran at O1. | Fuzzer, on stanc3's own test models | b8ee375ae |
| Frontend, truncation | The terms that a truncation adds took the metadata of the bound or the default metadata. With an int bound, as in `y ~ foo(mu) T[1, ]`, the cdf call, `log_diff_exp`, the negation and the product with the outcome's length were typed int and data. The C++ backend ignores these types. stanli read them and truncated a user cdf's value to an integer: lp -8.8808 where -8.8608 is right. `z ~ normal(mu, 1) T[1, 5]` on a parameter vector lost its normalizer the same way. | Fuzzer, on stanc3's own test models | 6251b729b |
| Loop vectorization | When a density did not depend on the loop variable, its product with the trip count was typed int and data. stanli read it as an integer and gave lp 0 where -0.45 is right. The vectorized statements also ran when the loop had no iterations: a density with an invalid scalar argument threw, a user function printed, and `for (i in 3:1)` added -1 times the density. A user function called in a vectorized statement ran once instead of once per iteration, so its prints appeared once. A user function in a loop bound was called again by the vectorized code. | Fuzzer | 6f6cf55e0 |
| Loop vectorization | A statement call to an `_lp` function, such as `foo_lp(y[n]);`, did not count as a read of `target`. Only `target()` and `_lp` calls inside expressions did. A density in the same loop was moved in front of the loop while the call stayed in it, so a `foo_lp` that reads `target()` saw the wrong value: lp -8.40375 where -2.8925 is right. At O1 this needs a call that the inliner keeps, such as a call to an overloaded function. | Reading the vectorizer while checking stanli's compile-time passes | 9bb4945b0 |
| Partial evaluation | Sizes were read from uninitialized declarations. The inliner declares bound arguments and return values with zero extents, so `y[1:0]` on a bound argument became `y`, and `sum(y[1:k])` with `k = 0` summed the whole vector. | not recorded | 1f6796e36 |
| Partial evaluation | Integer expressions were folded with the host OCaml `int`: 63 bits natively and 32 bits under js_of_ocaml. The same program could fold to different constants in the two compilers, and neither matched the generated C++ on overflow. | native and JavaScript compilers disagreeing | 00714bc81 |
| Partial evaluation | An integer `a * b + c` became `fma(a, b, c)`, which returns a real, while the expression kept its integer type. The C++ backend then chose operators and overloads for a real. `real c = (d * N + 1) %/% 2;` with `d = 2` and `N = 3` gave 3.5 at O1 and 3 at O0, because the integer division became a real division. With `real f(int k)` and `real f(real k)`, `f(d * N + 1)` called the real overload and gave 14 where O0 gives 7.5. stanli reads the integer type from the MIR, so its results did not change. A rewrite now has to keep the type of the expression that it replaces. | Reading stanli's fast-mode MIR for ctsem_ctsm_400 | the commit that adds this row |

## Compile time and generated code

| Pass | What went wrong | Found by | Fix |
| --- | --- | --- | --- |
| Dataflow analyses | Compile time grew about cubically with the number of inlined calls: 100 calls of a 9-way dispatch function took 91 s. (stan-dev/stanc3#1769) | a model with 100 calls of a dispatch function | be157d02f |
| Function inlining | A nontrivial scalar argument used several times in the body was evaluated once per use. | not recorded | 767e8e5b0 |
| Dataflow passes | Constant propagation, copy propagation, dead code elimination and partial evaluation each ran twice over the program blocks, and once over each function body. Function bodies show that one run was intended. Removing the second run makes forced O1 about 1.9x faster on the largest stanli corpus models (mlumr_survival_relaxed 9.3 s to 4.8 s). | Reading `transform_program` while measuring O1 compile time | 2551bc4ce |

## Open

| Pass | What goes wrong | Found by | Tracking |
| --- | --- | --- | --- |
| Function inlining | Return temporaries are declared with zero sizes. A function that returns an empty `array[0] matrix[R, S]` fails to build in stanli. | seantalts/stanli#580 | seantalts/stanli#580 |
| Allow uninitialized declarations | A local that is declared and then assigned as a whole becomes uninitialized, and the C++ backend then declares it as an empty container. Stan does not check sizes when it assigns to an empty container, so `matrix[2, 3] z = [[1, 2, 3, 4], [4, 5, 6, 8]];` throws at O0 and runs at O1 in C++. stanli sizes the local from its declaration and is not affected. | reading the generated C++ | none |
