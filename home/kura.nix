{
  pkgs,
  inputs,
  ...
}:
let
  llmAgentsPkgs = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [
    ./default.nix
  ];

  home.packages =
    with pkgs;
    [
      pfetch-rs
    ]
    ++ (with llmAgentsPkgs; [
      omp
      openskills
      skills
      skills-installer
    ]);
}
