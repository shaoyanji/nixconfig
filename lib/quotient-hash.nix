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
    lib.last fs;

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
    fs
    |> builtins.length
    |> lib.range 1
    |> builtins.filter (i: builtins.elemAt fs (i - 1) == term)
    |> builtins.head;

  indicesOf = n: let
    fs = fibs n;
  in
    n |> zeckendorf |> map (fibIndex fs);

  pattern = n: let
    fs = n |> fibs |> lib.reverseList;
    chosen = n |> zeckendorf;
  in
    fs
    |> lib.concatMapStrings (f:
      if chosen |> builtins.elem f
      then "1"
      else "0");

  sum = xs: xs |> builtins.foldl' (a: b: a + b) 0;

  hexInt = hex: "v = 0x${hex}" |> builtins.fromTOML |> (t: t.v);

  hashInt = {
    algorithm ? "sha256",
    digits ? 15,
  }: key: key |> builtins.hashString algorithm |> builtins.substring 0 digits |> hexInt;

  fingerprint = hashInt {};

  pow2 = e: e |> lib.range 1 |> builtins.foldl' (acc: _: acc * 2) 1;

  quotientHash = {
    key,
    digits ? 15,
    remainderBits ? 8,
  }: let
    fp = key |> hashInt {inherit digits;};
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
      quotient = idx |> builtins.head;
      remainder = fp - (terms |> builtins.head);
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
