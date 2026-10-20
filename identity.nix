# Public identity only. Host policy (key membership, state versions, passwords)
# stays with each host; no private key material belongs in the Nix store.
let
  sshKeys = {
    unicorn = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDw0aRfa+YINgWJP7FKsRZ+swvPOLE5cc94ZyijkZFoX unicorn";
    pwny = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrGOBlnxXx7U52BuS+M2swzKufwu1A76RyjfHK8w48A pwny";
    # Secretive Secure Enclave key named `yoru` on yoru (public half only; the
    # private half never leaves the enclave and cannot be exported).
    yoruEcdsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBKqitIfqaJ3cCYvqBrCn5AjkYOlkdw+706foxEHnwL/mP38nS59v6vJV3LIAojEgDzlUF6c2z+FFMsMoMvSmE3c= yoru@secretive.yoru.local";
    # The one key allowed to SSH into yoru, over the tailnet only.
    yoruLogin = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBM01ry/NcHpDTNGz0kkmtj11FsY8NvbAEX7fRfmQOfy9rAaJ4ZY/5EZJehSuJC1PvGTDf6YP1tZhqCf+fW/HgpA=";
  };
  git = {
    name = "ky";
    email = "ky@tilde.horse";
    signingkey = "~/.ssh/ky.pub";
  };
in
{
  user = {
    name = "ky";
    uid = 1000;
  };
  inherit git sshKeys;
  allowedSigner = "${git.email} ${builtins.replaceStrings [ " unicorn" ] [ "" ] sshKeys.unicorn}";
}
