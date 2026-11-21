// The loop adds `y[n] ~ normal(mu, 1)` and then `target += bar_lp(y[n])`,
// where `bar_lp` reads `target()`.
// Desired outcome: left as a loop.
// A call to an `_lp` function inside an expression counts as a read of
// `target`.
functions {
  real bar_lp(real x) {
    return 0.5 * target();
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
    y[n] ~ normal(mu, 1);
    target += bar_lp(y[n]);
  }
}
