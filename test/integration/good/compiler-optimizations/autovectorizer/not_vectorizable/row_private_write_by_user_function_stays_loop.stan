// The loop writes `mu[n]` with a user function and then reads `mu[n]` in a
// density. The write cannot vectorize, because a user function has to be
// called once per iteration. The density must then stay in the loop too: a
// vector statement runs before what is left of the loop, and it would read
// `mu` before the loop writes it.
// Dependences: true a->b {Eq}, and a cannot move
// Desired outcome: left as a loop.
functions {
  real shift(real x) {
    print("shift ", x);
    return x + 1;
  }
}
data {
  int<lower=1> N;
  vector[N] x;
  vector[N] y;
}
parameters {
  real<lower=0> sigma;
}
model {
  vector[N] mu;
  for (n in 1 : N) {
    mu[n] = shift(x[n]);
    target += normal_lpdf(y[n] | mu[n], sigma);
  }
}
