export def npv [cf:float] {
  # let c = { |x| (1 + $dr / 12) ** (-1 * ($x)) }
  let model = {
    |c,r,y,dr|
    [$c]
    | append (generate {|i| if $i <= 12 * $y { {out: $r, next: ($i + 1)} }} 1)
    | enumerate
    | each { |x| (do  { |x| (1 + $dr / 12) ** (-1 * ($x)) } $x.index) * $x.item}
    | math sum
  }
  # let p = [ {b: -100  r: 1 y: 20} {b: -100  r: 1 y: 30} ]
  let p = generate {
    |i| if $i <= 100 {
    # |i| if $i <= 20 {
      {
        out: {
          c:-100
          # r:1
          # y:20
          r:(random float (0.8 * $cf)..$cf)
          y:(random int 15..20)
          dr: 0.1
          # dr: ($i * 0.01)
        },
        next: ($i + 1)
      }
    }
  } 1
  $p | each {do $model ($in.c) ($in.r) ($in.y) ($in.dr)} 
}

export def kc [prob:float, cf:float] {
  let kc = { |p,b| $p - (1 - $p) / $b }
  npv $cf | enumerate | where item > 0 | each {do $kc $prob $in.item} | enumerate | where item > 0 
}
