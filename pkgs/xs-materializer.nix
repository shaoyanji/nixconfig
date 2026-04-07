{
  lib,
  buildGoModule,
}:
buildGoModule {
  pname = "xs-materializer";
  version = "0.1.0";

  src = ../tools/xs-materializer;

  vendorHash = null;

  meta = with lib; {
    description = "Go-first xs stream materializer for task-view context packs";
    license = licenses.mit;
    mainProgram = "xs-materializer";
    platforms = platforms.linux;
  };
}
