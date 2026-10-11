{
  lib,
  systems,
  pkgsFor,
  ...
}:
lib.genAttrs systems.default (system: {
  simplex-chat = (pkgsFor system).simplex-chat;
})
