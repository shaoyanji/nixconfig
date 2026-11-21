{lib}: let
  fibs = n: let
    go = a: b:
      if a > n
      then []
      else [a] ++ go b (a + b);
  in
    go 1 2;

  largestFib = n: let
    fs = fibs n;
  in
    builtins.elemAt fs (builtins.length fs - 1);

  zeckendorf = n: let
    go = m: acc:
      if m < 1
      then acc
      else let
        f = largestFib m;
      in
        go (m - f) (acc ++ [f]);
  in
    go n [];

  fibIndex = fs: term:
    builtins.head (builtins.filter (i: builtins.elemAt fs (i - 1) == term) (lib.range 1 (builtins.length fs)));

  indicesOf = n: let
    fs = fibs n;
  in
    map (fibIndex fs) (zeckendorf n);

  pattern = n: let
    fs = lib.reverseList (fibs n);
    chosen = zeckendorf n;
  in
    lib.concatMapStrings (f:
      if builtins.elem f chosen
      then "1"
      else "0")
    fs;

  sum = xs: builtins.foldl' (a: b: a + b) 0 xs;

  hexInt = hex: (builtins.fromTOML "v = 0x${hex}").v;

  hashInt = {
    algorithm ? "sha256",
    digits ? 15,
  }: key: hexInt (builtins.substring 0 digits (builtins.hashString algorithm key));

  fingerprint = hashInt {};

  pow2 = e: builtins.foldl' (acc: _: acc * 2) 1 (lib.range 1 e);

  quotientHash = {
    key,
    digits ? 15,
    remainderBits ? 8,
  }: let
    fp = hashInt {inherit digits;} key;
    m = pow2 remainderBits;
    quotient = builtins.div fp m;
  in {
    inherit fp quotient;
    remainder = fp - quotient * m;
  };

  zeckendorfQuotient = {key}: let
    fp = fingerprint key;
    terms = zeckendorf fp;
  in
    if terms == []
    then {
      inherit fp terms;
      quotient = 0;
      remainder = 0;
      indices = [];
      pattern = "";
    }
    else let
      idx = indicesOf fp;
    in {
      inherit fp terms;
      quotient = builtins.head idx;
      remainder = fp - builtins.head terms;
      indices = idx;
      pattern = pattern fp;
    };
in {
  inherit
    fibs
    largestFib
    zeckendorf
    indicesOf
    pattern
    fingerprint
    hashInt
    sum
    pow2
    quotientHash
    zeckendorfQuotient
    ;
}
