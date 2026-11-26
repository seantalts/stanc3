// A profile block writes `v[n]` and the next statement reads `v[n]` in a
// density. Every mention of `v` in the loop is the element `v[n]`, so only
// iteration `n` touches it. Both statements vectorize and keep their order,
// and the write stays inside its profile block.
// Dependences: true a->b {Eq}
// Desired outcome: fully vectorized.
data {
  int<lower=0> N;
  vector[N] x;
  vector[N] y;
}
parameters {
  real<lower=0> sigma;
}
model {
  vector[N] v;
  for (n in 1 : N) {
    profile("mu") {
      v[n] = x[n] + 1;
    }
    target += normal_lpdf(y[n] | v[n], sigma);
  }
}
