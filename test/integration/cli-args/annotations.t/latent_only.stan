parameters {
  @latent array[3] real a;
  @latent real b;
}
model {
  a ~ normal(0, 1);
  b ~ normal(0, 1);
}
