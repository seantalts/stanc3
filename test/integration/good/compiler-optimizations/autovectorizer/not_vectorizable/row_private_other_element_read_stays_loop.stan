// The loop writes `mu[n]` and the density reads both `mu[n]` and `mu[N]`.
// Iterations before the last one read `mu[N]` before the loop writes it. A
// vector statement for the write would run first and change what they read.
// Dependences: anti b->a {Lt} on `mu[N]`
// Desired outcome: left as a loop.
data {
  int<lower=1> N;
  vector[N] x;
  vector[N] y;
}
parameters {
  real<lower=0> sigma;
}
model {
  vector[N] mu = rep_vector(0.0, N);
  for (n in 1 : N) {
    mu[n] = x[n] + 1;
    target += normal_lpdf(y[n] | mu[n] + mu[N], sigma);
  }
}
