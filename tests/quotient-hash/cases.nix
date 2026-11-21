let
  lib = import <nixpkgs/lib>;
  qh = import ../../lib/quotient-hash.nix {inherit lib;};

  nums = lib.range 1 5000;
  keys = map (n: "key-${toString n}") (lib.range 1 2000);
  terms = map qh.zeckendorf nums;
  idx = map qh.indicesOf nums;

  sumsOk = builtins.all (x: x) (lib.zipListsWith (n: z: qh.sum z == n) nums terms);

  nonAdjacentOk =
    builtins.all (i: (builtins.filter (d: d < 2) (lib.zipListsWith (a: b: a - b) i (lib.tail i))) == []) idx;

  distinct = builtins.length (lib.unique (map builtins.toJSON idx));
  uniqueOk = distinct == builtins.length nums;

  quotOk =
    builtins.all (x: x)
    (map (k: let
      z = qh.zeckendorfQuotient {key = k;};
      fs = qh.fibs z.fp;
    in
      z.terms
      != []
      && (builtins.head z.terms) + z.remainder == z.fp
      && builtins.elemAt fs (z.quotient - 1) == builtins.head z.terms)
    keys);

  classicCheck = map (k: let
    q = qh.quotientHash {
      key = k;
      digits = 4;
      remainderBits = 8;
    };
  in
    q.quotient < 256 && q.quotient * 256 + q.remainder == q.fp && q.remainder < 256)
  keys;
  classicOk = builtins.all (x: x) classicCheck;

  buckets = builtins.foldl' (acc: k: let
    q = qh.quotientHash {
      key = k;
      digits = 4;
      remainderBits = 8;
    };
    name = toString q.quotient;
  in
    acc
    // {
      ${name} = (acc.${name} or 0) + 1;
    }) {}
  keys;
  bucketCount = builtins.length (builtins.attrNames buckets);
  maxLoad = builtins.foldl' (m: v:
    if v > m
    then v
    else m)
  0 (builtins.attrValues buckets);
  bucketSpace = qh.pow2 (16 - 8);
  balanceOk = bucketCount >= 250 && maxLoad <= 25;

  classes = builtins.foldl' (acc: k: let
    c = toString (qh.zeckendorfQuotient {key = k;}).quotient;
  in
    acc
    // {
      ${c} = (acc.${c} or 0) + 1;
    }) {}
  keys;

  moved =
    builtins.length
    (builtins.filter (x: x)
      (map (n: let
        a = qh.quotientHash {
          key = "avalanche-${toString n}";
          remainderBits = 8;
        };
        b = qh.quotientHash {
          key = "avalanche-${toString n}!";
          remainderBits = 8;
        };
      in
        a.quotient != b.quotient)
      (lib.range 1 200)));
  avalancheOk = moved >= 180;

  checks = {
    zeckendorfSums = sumsOk;
    noAdjacentTerms = nonAdjacentOk;
    uniqueRepresentation = uniqueOk;
    quotientReconstructs = quotOk;
    classicSplitReconstructs = classicOk;
    classicBucketsBalanced = balanceOk;
    avalancheMovesBucket = avalancheOk;
  };

  failures = builtins.attrNames (lib.filterAttrs (_: v: v != true) checks);
in {
  ok = failures == [];
  inherit failures checks;
  stats = {
    numbers = builtins.length nums;
    keys = builtins.length keys;
    distinctRepresentations = distinct;
    classicBucketSpace = bucketSpace;
    classicBuckets = bucketCount;
    classicMaxLoad = maxLoad;
    avalancheMoved = moved;
    zeckendorfClasses = builtins.length (builtins.attrNames classes);
    classHistogram = classes;
    sample = qh.zeckendorfQuotient {key = "hello";};
  };
}
