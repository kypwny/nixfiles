{
  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      cleanup = "zap";
      upgrade = false;
    };

    taps = [
      "homebrew/services"
    ];

    brews = [
      "mas"
    ];

    casks = [
      "ghostty"
      "visual-studio-code"
      "firefox"
    ];
  };
}
