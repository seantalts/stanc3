functions {
  @latent real f(real x);
}
parameters {
  real a;
}
model {
  a ~ normal(0, 1);
}
