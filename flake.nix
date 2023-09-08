{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs";
    };

    outputs = {self, nixpkgs}:
        let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in {
            defaultPackage.x86_64-linux = pkgs.hello;

            devShell.x86_64-linux =
                pkgs.mkShell {
                    buildInputs = [
                        pkgs.caddy
                        pkgs.perl
                        pkgs.perlPackages.ModernPerl
                        pkgs.perlPackages.Mojolicious
                        pkgs.perlPackages.URI
                        pkgs.perlPackages.LWP
                        pkgs.perlPackages.RoleTiny
                        pkgs.perlPackages.ScalarListUtils
                        pkgs.perlPackages.Memoize
                        # pkgs.perlPackages.SVG ## Not packaged
                        pkgs.perlPackages.XMLLibXML
                        pkgs.perlPackages.MathGeometryVoronoi
                        # pkgs.perlPackages.MathFractalNoisemaker ## Not packaged
                        pkgs.perlPackages.ListMoreUtils
                        pkgs.perlPackages.LWPProtocolHttps
                    ];
                };
        };
}

