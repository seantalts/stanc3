Unknown annotations warn and registered ones do not

  $ stanc --print-cpp latent_only.stan > /dev/null

  $ stanc --print-cpp latent.stan > /dev/null
  warning: Unknown annotation '@foo'.
      ┌─ latent.stan:7:3
    6 │    @latent vector[J] a;
    7 │    @foo real mu;
      │    ^^^^ Unknown annotation.
    8 │    real<lower=0> sigma;
      = This will be ignored by the compiler.

  $ stanc --allow-undefined --print-cpp latent_fn.stan > /dev/null
  warning: Unsupported annotation '@latent' for type (real) => real.
      ┌─ latent_fn.stan:2:3
    1 │  functions {
    2 │    @latent real f(real x);
      │    ^^^^^^^ Unsupported annotation.
    3 │  }
      = This will be ignored by the compiler.

The MIR carries the annotations on outvars

  $ stanc --debug-mir latent.stan 2>/dev/null | grep -B1 -A1 "(name latent)"
        (decl_annotations
         (((name latent) (args ())
           (loc
  --
        (decl_annotations
         (((name latent) (args ())
           (loc
  --
       (out_annotations
        (((name latent) (args ())
          (loc
