// The loop updates `mu[n]` twice and then reads it in a density. Every
// mention of `mu` in the loop is the element `mu[n]`, so only iteration `n`
// touches it. The three statements vectorize and keep their order. brms
// writes its linear predictors this way.
// Dependences: true and output edges, all {Eq}
// Desired outcome: fully vectorized.
//   `mu[1:N] = mu[1:N] + r1[j1[1:N]]`, `mu[1:N] = mu[1:N] + b * x[1:N]`,
//   then one `normal_lpdf`
data {
  int<lower=1> N;
  int<lower=1> J;
  array[N] int<lower=1, upper=J> j1;
  vector[N] x;
  vector[N] y;
}
parameters {
  real b;
  vector[J] r1;
  real<lower=0> sigma;
}
model {
  vector[N] mu = rep_vector(0.0, N);
  for (n in 1 : N) {
    mu[n] += r1[j1[n]];
    mu[n] += b * x[n];
    target += normal_lpdf(y[n] | mu[n], sigma);
  }
}
