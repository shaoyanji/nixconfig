# translates from german
export def "from german" [targetlang:string=en,sourcelang:string=de] {trans -b -s $sourcelang -t $targetlang}
# translates into german
export def "into german" [targetlang:string=de,sourcelang:string=en] {trans -b -s $sourcelang -t $targetlang}
# german language module fuzzy menu
export def de [] { print $"
  (ansi black)█████████████(ansi reset)
  (ansi red)█████████████(ansi reset)
  (ansi yellow)█████████████(ansi reset)"
  scope commands
    | where name starts-with "de "
    | get name
    | input list
    | nu -c $"source ($nu.config-path); ($in)"
  }
export def "de akk" [] { print "direct object"}
export def "de dat" [] {print "indirect object"}
export def "de gen" [] {print "possessive"}
# Konjunctiv II
export def "de konjunktivii" [] {
[[pronom, haben, sein, werden,Modalverbden];
["ich",hätte,wäre,würde,sollte]
["du",hättest,wärst,würdest,solltest]
["er/sie/es",hätte,wäre,würde,sollte]
["wir",hätten,wären,würden,sollten]
["ihr",hättet,wäret,würdet,solltet]
["sie, Sie",hätten,wären,würden,sollten]]
}
# german language module conjunctions
export def "de conjunctions" [] {
      [[German, English];
      [als, when]
      ["als ab", "as if"]
      [bevor,before]
      [bis,until]
      [da, as/because]
      [damit, "so that/in order that"]
      [dass,that]
      [nachdem,after/after]
      [ob,whether/if]
      [obwohl,although]
      [seitdem,since]
      ["so dass","so that"]
      [während,while]
      [weil,because]
      [wenn,when/if]]
}
# german language module pronouns
export def "de pronom" [] {
  [[nom, akk, dat];
    [ ich, mich, mir]
    [ du, dich, dir]
    [ er, ihr, ihm]
    [ sie, sie, ihr]
    [ es, es, ihm]
    [ wir, uns, uns]
    [ ihr, euch, euch]
    [ sie, sie, ihnen]
    [ Sie, Sie, Ihnen]]
}
# german language module adjectives
export def "de adjektiv" [] {
  [[nom, akk, dat];
    [ der, den, dem]
    [ das, das, dem]
    [ die, die, der]
    [ die, die, denen]]
}
# german language module pronouns possessive
export def "de pronom possessive" [] {
  {
  masculine:
  [[nom, akk, dat];
    [ mein, meinen, meinem]
    [ dein, deinen, deinem]
    [ sein, seinen, seinem]
    [ ihr, ihren, ihrem]
    [ sein, seinen, seinem]
    [ unser, unseren, unserem]
    [ euer, euren, eurem]
    [ ihr, ihren, ihrem]
    [ Ihr, Ihren, Ihrem]]
  feminine:
  [[nom, akk, dat];
    [ meine, meine, meiner]
    [ deine, deine, deiner]
    [ seine, seine, seiner]
    [ ihre, ihre, ihrer]
    [ seine, seine, seiner]
    [ unsere, unsere, unserer]
    [ eure, eure, eurer]
    [ ihre, ihre, ihrer]
    [ Ihre, Ihre, Ihrer]]
  neut:
  [[nom, akk, dat];
    [ mein, mein, meinem]
    [ dein, dein, deinem]
    [ sein, sein, seinem]
    [ ihr, ihr, ihrem]
    [ sein, sein, seinem]
    [ unser, unser, unserem]
    [ euer, eures, eurem]
    [ ihr, ihr, ihrem]
    [ Ihr, Ihr, Ihrem]]
  pl:
  [[nom, akk, dat];
    [ meine, meine, meinen]
    [ deine, deine, deinen]
    [ seine, seine, seinen]
    [ ihre, ihre, ihren]
    [ seine, seine, seinen]
    [ unsere, unsere, unseren]
    [ eure, eure, euren]
    [ ihre, ihre, ihren]
    [ Ihre, Ihre, Ihren]]
  }
}
# german language module reflexive pronouns
export def "de pronom reflexiv" [] {
  [[nom, akk, dat];
    [ich, mich, mir]
    [du, dich, dir]
    [er, sich, sich]
    [sie, sich, sich]
    [es, sich, sich]
    [wir, uns, uns]
    [ihr, euch, euch]
    [sie, sich, sich]
    [Sie, sich, sich]]
  
}
# german language module articles
export def "de artikel" [] {
  {
    definite:
      [[gender, nom, akk, dat, gen ];
      [masculine, der, den, dem, des ]
      [feminine, die,die, der, der]
      [neuter, das,das, dem, des]
      [plural, die,die,den,der]],
    indefinite:
      [[gender, nom, akk, dat, gen ];
      [masculine, ein, einen, einem, eines]
      [feminine, eine,eine, einer, einer]
      [neuter, ein,ein, einem, eines]]
  }
}
# german language module dictionary
export def "de dict" [] {
  http get https://raw.githubusercontent.com/Jonny-exe/German-Words-Library/master/German-words-5000-words.json
        | sk --format {} --preview {from german} | trans -s de
}
# german language module prepositions
export def "de preposition" [] {
[[german, english];
  [aus, of/from]
  [bei, at]
  [nach, after]
  [seit, since]
  [von, from]
  [zu, to]
  [genueber, opposite]
  [ausser, except]]
}
