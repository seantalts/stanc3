// The loop calls `foo_lp(y[n])`, which only adds to `target`, and then adds
// `y[n] ~ normal(mu, 1)`. Widening would only reorder a sum here, but the
// vectorizer does not look inside `foo_lp`.
// Desired outcome: left as a loop.
// Any `_lp` call in a loop prevents widening of the densities in that loop.
functions {
  void foo_lp(real x) {
    target += -x;
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
