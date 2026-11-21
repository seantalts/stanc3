// The loop calls `foo(y[n])`, a user function that only prints, and adds
// `y[n] ~ normal(mu, 1)`.
// Desired outcome: partially vectorized. The density becomes one vector
//   statement and the call stays in a loop.
// A user function without the `_lp` suffix cannot read or change `target`.
functions {
  void foo(real x) {
    print(x);
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
    foo(y[n]);
    y[n] ~ normal(mu, 1);
  }
}
