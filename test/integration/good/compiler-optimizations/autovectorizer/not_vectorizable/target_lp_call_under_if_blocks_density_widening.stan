// The loop adds `y[n] ~ normal(mu, 1)` and, for positive `y[n]`, calls
// `foo_lp(y[n])`, which reads `target()`.
// Desired outcome: left as a loop.
// An `_lp` call inside an `if` in the loop blocks widening the same way.
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
    y[n] ~ normal(mu, 1);
    if (y[n] > 0) {
      foo_lp(y[n]);
    }
  }
}
