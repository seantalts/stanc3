// The loop calls `foo_lp(y[n])` as a statement and then adds
// `y[n] ~ normal(mu, 1)`. `foo_lp` reads `target()`, so it must see the
// densities of the earlier iterations and not those of the later ones.
// Desired outcome: left as a loop.
// A statement call to an `_lp` function counts as a read of `target`, the same
// as a `target()` expression.
functions {
  void foo_lp(real x) {
    target += 0.5 * target();
  }
}
data {
  int<lower=0> N;
  vector[N] y;
}
parameters {
  real mu;
}
model {
  for (n in 1 : N) {
    foo_lp(y[n]);
    y[n] ~ normal(mu, 1);
  }
}
