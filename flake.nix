{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    agent-skills.url = "github:Kyure-A/agent-skills-nix";
    agent-skills.inputs.nixpkgs.follows = "nixpkgs";

    # skills/<id>/ に写す gist。更新は .github/workflows/vendor-gist-skills.yaml
    cognitive-rhythm-writing = { url = "git+https://gist.github.com/k16shikano/eb2929f13ed19c97188393d297be8432.git"; flake = false; };
    japanese-tech-writing = { url = "git+https://gist.github.com/k16shikano/fd287c3133457c4fd8f5601d34aa817d.git"; flake = false; };
  };

  outputs = inputs@{ nixpkgs, flake-utils, agent-skills, ... }:
    let
      agentLib = agent-skills.lib.agent-skills;
      ids = [ "cognitive-rhythm-writing" "japanese-tech-writing" ];
      # gist はルート直下に SKILL.md がある
      sources = nixpkgs.lib.genAttrs ids (id: { path = inputs.${id}.outPath; filter.maxDepth = 0; });
      catalog = agentLib.discoverCatalog sources;
      selection = agentLib.selectSkills {
        inherit catalog sources;
        allowlist = ids;
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        bundle = agentLib.mkBundle { inherit pkgs selection; };
      in {
        packages.default = bundle;
        checks.skills = bundle;

        # skill 単位で同期するので skills/ の他の skill には触らない
        apps.skills-vendor = {
          type = "app";
          program = "${pkgs.writeShellApplication {
            name = "skills-vendor";
            runtimeInputs = [ pkgs.rsync ];
            text = ''
              for id in ${toString ids}; do
                rsync -aL --delete --chmod=Du+w,Fu+w "${bundle}/$id/" "skills/$id/"
              done
            '';
          }}/bin/skills-vendor";
        };
      });
}
