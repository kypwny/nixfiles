"""Exercise real portable Bash helpers; all external actions are mocked."""
import json
import os
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest

SCRIPTS = Path(__file__).resolve().parents[1] / "shells" / "scripts"
BASH = shutil.which("bash") or "/bin/bash"


class ShellHelpers(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="shell-helpers-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls.jsonl"
        self.env = dict(os.environ, HOME=str(self.root / "home"),
                        RESEARCH_WORKSPACE=str(self.root / "work"),
                        PATH=str(self.bin) + ":" + os.environ.get("PATH", "/usr/bin:/bin"),
                        MOCK_LOG=str(self.log))
        for key in ("HTB_ROOT", "WORK", "KDIR", "O", "JOBS", "UDID", "PORT",
                    "SSH_USER", "KBUILD_ELF_INCLUDE", "HOSTLD", "HOSTAR",
                    "HOSTNM", "HOSTRANLIB", "HOSTCFLAGS", "ARCH", "CROSS_COMPILE"):
            self.env.pop(key, None)
        self.mock("python3", "os.execv(sys.executable, [sys.executable] + sys.argv[1:])", log=False)
        for name in ("sudo", "ssh", "rsync", "reboot", "systemctl", "kexec",
                     "make", "nmap", "ncat", "rlwrap", "openvpn", "pkill",
                     "ping", "iproxy", "ideviceinfo", "frida-ps", "frida-trace",
                     "ipsw", "sysctl", "nproc", "ps", "kill"):
            self.mock(name)

    def mock(self, name, body="pass", log=True):
        code = ("#!" + sys.executable + "\nimport json, os, sys\nfrom pathlib import Path\n")
        if log:
            code += ("with open(os.environ['MOCK_LOG'], 'a') as f:\n"
                     "    f.write(json.dumps([Path(sys.argv[0]).name] + sys.argv[1:]) + '\\n')\n")
        code += body + "\n"
        path = self.bin / name
        path.write_text(code)
        path.chmod(0o755)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def run_helper(self, name, *args, **updates):
        env = dict(self.env, **updates)
        return subprocess.run([BASH, str(getattr(self, "scripts", SCRIPTS) / name), *args], env=env,
                              cwd=self.root, text=True, capture_output=True, timeout=10)

    def assert_ok(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_htb_new_creates_sourceable_explicit_environment(self):
        work = self.root / "space ' quoted $ work"
        result = self.run_helper("htb.sh", "new", "Blue", "10.10.10.5", "10.10.14.2",
                                 RESEARCH_WORKSPACE=str(work))
        self.assert_ok(result)
        directory = work / "htb" / "Blue"
        self.assertTrue((directory / "scans").is_dir())
        sourced = subprocess.run([BASH, "-eu", "-c",
                                  '. "$1"; printf "%s\\n" "$RHOST" "$LHOST" "$HTB_MACHINE" "$PWD"',
                                  "test", str(directory / "env.sh")], env=self.env,
                                 text=True, capture_output=True)
        self.assert_ok(sourced)
        self.assertEqual(sourced.stdout.splitlines(),
                         ["10.10.10.5", "10.10.14.2", "Blue", str(directory)])
        self.assertEqual(self.calls(), [])

    def test_htb_new_rejects_unsafe_inputs_before_writes(self):
        for name, remote, local in [("../escape", "10.1.1.1", "10.1.1.2"),
                                    ("Blue;touch pwn", "10.1.1.1", "10.1.1.2"),
                                    ("Blue", "999.1.1.1", "10.1.1.2"),
                                    ("Blue", "10.1.1.1", "$(touch pwn)"),
                                    ("Blue", "-sV", "10.1.1.2")]:
            with self.subTest(name=name, remote=remote, local=local):
                result = self.run_helper("htb.sh", "new", name, remote, local)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("invalid", result.stderr)
                self.assertFalse((self.root / "work").exists())
        self.assertEqual(self.calls(), [])

    def test_htb_new_preserves_existing_config_and_root_override(self):
        override = self.root / "custom htb"
        self.assert_ok(self.run_helper("htb.sh", "new", "Blue", "10.1.1.1", "10.1.1.2", HTB_ROOT=str(override)))
        directory = override / "Blue"
        (directory / "env.sh").write_text("user configuration\n")
        (directory / "notes.md").write_text("user notes\n")
        self.assert_ok(self.run_helper("htb.sh", "new", "Blue", "10.2.2.1", "10.2.2.2", HTB_ROOT=str(override)))
        self.assertEqual((directory / "env.sh").read_text(), "user configuration\n")
        self.assertEqual((directory / "notes.md").read_text(), "user notes\n")
        self.assertFalse((self.root / "work").exists())

    def test_htb_default_workspace_is_generic(self):
        self.env.pop("RESEARCH_WORKSPACE", None)
        self.assert_ok(self.run_helper("htb.sh", "new", "Blue", "10.1.1.1", "10.1.1.2"))
        expected = Path(self.env["HOME"]) / "workspace" / "htb" / "Blue"
        self.assertTrue((expected / "env.sh").is_file())
        self.assertEqual(self.calls(), [])

    def test_htb_refuses_repository_store_and_symlink_workspaces(self):
        import shutil
        fake_repo = self.root / "repo"
        copied = fake_repo / "shells" / "scripts"
        shutil.copytree(SCRIPTS, copied)
        self.scripts = copied
        self.mock("mkdir", "sys.exit(9)")  # Catch missing validation without unsafe writes.
        linked = self.root / "linked"
        linked.symlink_to(fake_repo, target_is_directory=True)
        for path in (fake_repo / "work", linked / "work", Path("/nix/store/helper-test-work")):
            with self.subTest(path=str(path)):
                result = self.run_helper("htb.sh", "new", "Blue", "10.1.1.1", "10.1.1.2", HTB_ROOT=str(path))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("refusing", result.stderr)
        self.assertFalse((fake_repo / "work").exists())

    def test_htb_listener_binds_only_supplied_address(self):
        self.assert_ok(self.run_helper("htb.sh", "shell", "10.10.14.2", "4444"))
        self.assertEqual(self.calls(), [["rlwrap", "-cAr", str(self.bin / "ncat"),
                                        "--listen", "10.10.14.2", "4444"]])
        self.log.unlink()
        for ip, port in [("bad", "4444"), ("10.1.1.1", "0"),
                         ("10.1.1.1", "65536"), ("10.1.1.1", "4;touch pwn")]:
            self.assertNotEqual(self.run_helper("htb.sh", "shell", ip, port).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_htb_scan_uses_fresh_output_and_explicit_target(self):
        self.mock("nmap", "p = Path(sys.argv[sys.argv.index('-oA') + 1] + '.nmap')\np.write_text('22/tcp open ssh\\n443/tcp open https\\n80/tcp closed http\\n')")
        out = self.root / "scan output"
        self.assert_ok(self.run_helper("htb.sh", "scan", "10.10.10.5", str(out)))
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        prefix = calls[0][calls[0].index("-oA") + 1]
        self.assertEqual(Path(prefix).parent.parent, out)
        self.assertEqual(calls[0], ["nmap", "-Pn", "-sT", "-p-", "-oA", prefix, "10.10.10.5"])
        self.assertEqual(calls[1], ["nmap", "-Pn", "-sT", "-sV", "-sC", "-p", "22,443", "-oA",
                                    str(Path(prefix).with_name("detail")), "10.10.10.5"])
        self.log.unlink()
        self.assertNotEqual(self.run_helper("htb.sh", "scan", "--script=all", str(out)).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_htb_vpn_is_explicit_foreground_with_owned_pidfile(self):
        config = self.root / "lab profile.ovpn"
        config.write_text("user-supplied profile\n")
        self.assert_ok(self.run_helper("htb.sh", "vpn", str(config)))
        pidfile = self.root / "work" / "htb" / ".vpn.pid"
        self.assertEqual(self.calls(), [["sudo", str(self.bin / "openvpn"), "--config", str(config), "--writepid", str(pidfile)]])
        self.assertEqual(config.read_text(), "user-supplied profile\n")
        self.assertTrue((pidfile.parent / ".vpn.command").is_file())

    def test_htb_down_signals_only_exact_owned_vpn_process(self):
        root = self.root / "work" / "htb"
        root.mkdir(parents=True)
        pidfile = root / ".vpn.pid"
        metadata = root / ".vpn.command"
        command = f"{self.bin / 'openvpn'} --config {self.root / 'lab.ovpn'} --writepid {pidfile}"
        metadata.write_text(command + "\n")
        pidfile.write_text("12345\n")
        self.mock("ps", "print(os.environ['MOCK_COMMAND'] if sys.argv[-1] == 'command=' else '0')")
        self.assert_ok(self.run_helper("htb.sh", "down", MOCK_COMMAND=command))
        self.assertEqual(self.calls()[-1], ["sudo", "/bin/kill", "-TERM", "12345"])
        self.assertFalse(pidfile.exists())
        self.assertFalse(metadata.exists())
        for pid, running in [("12345", "/some/other/openvpn --config unrelated"),
                             ("-1", command), ("1", command), ("abc", command)]:
            self.log.unlink(missing_ok=True)
            metadata.write_text(command + "\n")
            pidfile.write_text(pid + "\n")
            result = self.run_helper("htb.sh", "down", MOCK_COMMAND=running)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("refusing", result.stderr)
            self.assertFalse(any(c[0] in ("sudo", "kill", "pkill") for c in self.calls()))
            self.assertTrue(pidfile.exists())

    def test_ios_info_requires_and_selects_explicit_udid(self):
        self.assert_ok(self.run_helper("ios-device.sh", "info", "device-123"))
        self.assertEqual(self.calls(), [["ideviceinfo", "-u", "device-123"]])
        self.log.unlink()
        for args in [("info",), ("info", "-n"), ("info", "device;touch pwn")]:
            result = self.run_helper("ios-device.sh", *args)
            self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_ios_frida_commands_select_device_not_first_usb(self):
        self.assert_ok(self.run_helper("ios-device.sh", "ps", "device-123"))
        self.assert_ok(self.run_helper("ios-device.sh", "trace", "device-456", "open*"))
        self.assertEqual(self.calls(), [["frida-ps", "-D", "device-123"],
                                        ["frida-trace", "-D", "device-456", "-i", "open*"]])

    def test_ios_ssh_preserves_device_host_keys_and_interactive_credentials(self):
        self.mock("iproxy", "import time\nPath(os.environ['MOCK_PROXY_PID']).write_text(str(os.getpid()))\ntime.sleep(5)")
        pidfile = self.root / "proxy.pid"
        self.assert_ok(self.run_helper("ios-device.sh", "ssh", "device-123", "researcher", "2223",
                                      MOCK_PROXY_PID=str(pidfile)))
        self.assertEqual(self.calls(), [["iproxy", "-u", "device-123", "2223", "22"],
                                        ["ssh", "-p", "2223", "-o", "StrictHostKeyChecking=ask",
                                         "-o", "HostKeyAlias=ios-device-123", "researcher@127.0.0.1"]])
        with self.assertRaises(ProcessLookupError):
            os.kill(int(pidfile.read_text()), 0)
        self.log.unlink()
        for user, port in [("root;reboot", "2223"), ("-oProxyCommand=bad", "2223"), ("researcher", "0")]:
            self.assertNotEqual(self.run_helper("ios-device.sh", "ssh", "device-123", user, port).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_deployment_is_quarantined_without_actions(self):
        result = self.run_helper("kernel-deploy.sh", "user@host", "--reboot")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("quarantined", result.stderr.lower())
        self.assertIn("unsupported", result.stderr.lower())
        self.assertEqual(self.calls(), [])
        self.assert_ok(self.run_helper("kernel-deploy.sh", "--help"))
        self.assertEqual(self.calls(), [])


class FirmwareAndBuildHelpers(unittest.TestCase):
    # Reuse the CLI harness without inheriting (and duplicating) its tests.
    root: Path
    bin: Path
    log: Path
    env: dict
    setUp = ShellHelpers.setUp
    mock = ShellHelpers.mock
    calls = ShellHelpers.calls
    run_helper = ShellHelpers.run_helper
    assert_ok = ShellHelpers.assert_ok
    def test_firmware_download_is_explicit_isolated_and_manifested(self):
        self.mock("ipsw", "out = Path(sys.argv[sys.argv.index('--output') + 1])\n(out / 'selected.ipsw').write_bytes(b'firmware')")
        work = self.root / "quoted ' $ workspace"
        self.assert_ok(self.run_helper("ios-pull.sh", "iPhone15,2", "17.0.1", RESEARCH_WORKSPACE=str(work)))
        call = self.calls()[0]
        out = Path(call[call.index("--output") + 1])
        self.assertEqual(out.parent, work / "ios" / "iPhone15,2" / "17.0.1")
        self.assertEqual(call, ["ipsw", "download", "ipsw", "--device", "iPhone15,2",
                                "--version", "17.0.1", "--output", str(out), "--confirm"])
        manifest = json.loads((out / "manifest.json").read_text())
        import hashlib
        self.assertEqual(manifest["model"], "iPhone15,2")
        self.assertEqual(manifest["version"], "17.0.1")
        self.assertEqual(manifest["artifacts"], [{"file": "selected.ipsw", "sha256": hashlib.sha256(b"firmware").hexdigest()}])
        self.assert_ok(self.run_helper("ios-pull.sh", "iPhone15,2", "17.0.1", RESEARCH_WORKSPACE=str(work)))
        self.assertNotEqual(self.calls()[1][self.calls()[1].index("--output") + 1], str(out))

    def test_firmware_rejects_missing_or_invalid_model_version_before_actions(self):
        for args in [(), ("iPhone15,2",), ("--latest", "17.0"), ("iPhone15,2", "latest"),
                     ("iPhone15,2/escape", "17.0"), ("iPhone15,2", "17.0;bad"),
                     ("iPhone15,2", "17.0", "a", "b")]:
            with self.subTest(args=args):
                result = self.run_helper("ios-pull.sh", *args)
                self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.root / "work").exists())

    def test_firmware_default_workspace_is_generic(self):
        self.env.pop("RESEARCH_WORKSPACE", None)
        self.mock("ipsw", "out = Path(sys.argv[sys.argv.index('--output') + 1])\n(out / 'selected.ipsw').write_bytes(b'firmware')")
        self.assert_ok(self.run_helper("ios-pull.sh", "iPad14,1", "17.0"))
        call = self.calls()[0]
        output = Path(call[call.index("--output") + 1])
        self.assertEqual(output.parent, Path(self.env["HOME"]) / "workspace" / "ios" / "iPad14,1" / "17.0")

    def test_firmware_refuses_unsafe_roots_and_symlink_artifacts(self):
        import shutil
        repo = self.root / "repo"
        self.scripts = repo / "shells" / "scripts"
        shutil.copytree(SCRIPTS, self.scripts)
        outside = self.root / "outside"
        outside.mkdir()
        linked = self.root / "linked"
        linked.symlink_to(outside, target_is_directory=True)
        for root in (repo / "work", Path("/nix/store/helper-test"), linked / "new"):
            with self.subTest(root=str(root)):
                result = self.run_helper("ios-pull.sh", "iPad14,1", "17.0", str(root))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("refusing", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertFalse((outside / "new").exists())
        artifact = outside / "unrelated.ipsw"
        artifact.write_bytes(b"unrelated")
        self.mock("ipsw", "out = Path(sys.argv[sys.argv.index('--output') + 1])\n(out / 'selected.ipsw').symlink_to(os.environ['MOCK_ARTIFACT'])")
        result = self.run_helper("ios-pull.sh", "iPad14,1", "17.0", MOCK_ARTIFACT=str(artifact))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing", result.stderr)
        self.assertEqual(list((self.root / "work").rglob("manifest.json")), [])

    def test_firmware_never_selects_old_artifacts_or_masks_download_failure(self):
        out = self.root / "existing"
        out.mkdir()
        (out / "old.ipsw").write_bytes(b"old")
        result = self.run_helper("ios-pull.sh", "iPod9,1", "15.0", str(out))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no IPSW", result.stderr)
        self.assertEqual(list(out.rglob("manifest.json")), [])
        self.mock("ipsw", "sys.exit(7)")
        result = self.run_helper("ios-pull.sh", "iPod9,1", "15.0", str(out))
        self.assertEqual(result.returncode, 7)
        self.assertEqual(list(out.rglob("manifest.json")), [])
        self.assertEqual((out / "old.ipsw").read_bytes(), b"old")

    def kernel_fixture(self, arch="x86_64"):
        source = self.root / "kernel source ' $"
        out = self.root / "kernel output ' $"
        source.mkdir()
        (source / "Makefile").write_text("# fake kernel source; make is mocked\n")
        out.mkdir()
        symbol = "CONFIG_X86_64=y" if arch == "x86_64" else "CONFIG_ARM64=y"
        (out / ".config").write_text(symbol + "\n# existing user configuration\n")
        return source, out

    def test_kbuild_linux_uses_explicit_config_and_separate_output(self):
        source, out = self.kernel_fixture()
        before = (out / ".config").read_bytes()
        self.mock("uname", "print('Linux')", log=False)
        self.assert_ok(self.run_helper("kbuild.sh", "--jobs", "2", str(source), str(out)))
        self.assertEqual(self.calls(), [["make", "-C", str(source), "O=" + str(out),
                                        "ARCH=x86_64", "LLVM=1", "CROSS_COMPILE=x86_64-linux-gnu-", "-j2", "vmlinux"]])
        self.assertEqual((out / ".config").read_bytes(), before)
        self.assertFalse((source / ".config").exists())

    def test_kbuild_requires_existing_external_separate_config(self):
        source, out = self.kernel_fixture()
        self.mock("uname", "print('Linux')", log=False)
        original = (out / ".config").read_bytes()
        (out / ".config").unlink()
        result = self.run_helper("kbuild.sh", str(source), str(out))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(".config", result.stderr)
        self.assertFalse((out / ".config").exists())
        (out / ".config").write_bytes(original)
        inside = source / "output"
        inside.mkdir()
        (inside / ".config").write_bytes(original)
        linked = self.root / "linked-output"
        linked.symlink_to(out, target_is_directory=True)
        source_link = self.root / "linked-source"
        source_link.symlink_to(source, target_is_directory=True)
        for src, dst in [(source, source), (source, inside), (out, source),
                         (source, linked), (source_link, out), (source, Path("/nix/store/helper-out")),
                         (SCRIPTS.parent.parent, out)]:
            with self.subTest(src=str(src), dst=str(dst)):
                result = self.run_helper("kbuild.sh", str(src), str(dst))
                self.assertNotEqual(result.returncode, 0)
        (out / ".config").unlink()
        (out / ".config").symlink_to(inside / ".config")
        self.assertNotEqual(self.run_helper("kbuild.sh", str(source), str(out)).returncode, 0)
        self.assertEqual(self.calls(), [])

    def test_kbuild_darwin_is_explicitly_gated_and_host_overrides_are_scoped(self):
        source, out = self.kernel_fixture()
        self.mock("uname", "print('Darwin')", log=False)
        result = self.run_helper("kbuild.sh", str(source), str(out))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("--darwin-experimental", result.stderr)
        self.assertEqual(self.calls(), [])
        self.assert_ok(self.run_helper("kbuild.sh", "--darwin-experimental", str(source), str(out)))
        call = self.calls()[0]
        for arg in ("HOSTLD=/usr/bin/ld", "HOSTAR=/usr/bin/ar", "HOSTNM=/usr/bin/nm", "HOSTRANLIB=/usr/bin/ranlib"):
            self.assertIn(arg, call)
        self.assertFalse(any(c[0] in ("sudo", "sysctl", "ssh") for c in self.calls()))
        self.log.unlink()
        self.mock("uname", "print('Linux')", log=False)
        self.mock("make", "assert os.environ['HOSTLD'] == 'user-host-linker'")
        self.assert_ok(self.run_helper("kbuild.sh", "--darwin-experimental", str(source), str(out), HOSTLD="user-host-linker"))
        self.assertFalse(any(arg.startswith("HOST") for arg in self.calls()[0][1:]))

    def test_kbuild_aligns_architecture_cross_prefix_config_and_target(self):
        source, out = self.kernel_fixture("arm64")
        self.mock("uname", "print('Linux')", log=False)
        self.assert_ok(self.run_helper("kbuild.sh", "--arch", "arm64", "--target", "Image", str(source), str(out)))
        call = self.calls()[0]
        self.assertIn("ARCH=arm64", call)
        self.assertIn("CROSS_COMPILE=aarch64-linux-gnu-", call)
        self.assertEqual(call[-1], "Image")
        self.log.unlink()
        for options in [("--arch", "x86_64"), ("--arch", "arm64", "--target", "bzImage"),
                        ("--arch", "arm64", "--cross-compile", "x86_64-linux-gnu-"),
                        ("--arch", "arm64", "--target", "install"), ("--jobs", "0"),
                        ("--jobs", "2;bad"), ("--arch", "riscv"), ("--target", "defconfig")]:
            with self.subTest(options=options):
                self.assertNotEqual(self.run_helper("kbuild.sh", *options, str(source), str(out)).returncode, 0)
        self.assertEqual(self.calls(), [])
        self.assert_ok(self.run_helper("kbuild.sh", "--arch", "arm64", "--cross-compile", "aarch64-unknown-linux-gnu-", str(source), str(out)))
        self.assertIn("CROSS_COMPILE=aarch64-unknown-linux-gnu-", self.calls()[0])
        self.mock("make", "sys.exit(9)")
        self.assertEqual(self.run_helper("kbuild.sh", "--arch", "arm64", str(source), str(out)).returncode, 9)

    def test_kbuild_darwin_elf_include_does_not_leak_to_linux(self):
        source, out = self.kernel_fixture()
        headers = self.root / "isolated elf headers"
        headers.mkdir()
        (headers / "elf.h").write_text("/* isolated ELF header */\n")
        self.mock("uname", "print('Darwin')", log=False)
        self.assert_ok(self.run_helper("kbuild.sh", "--darwin-experimental", str(source), str(out),
                                      KBUILD_ELF_INCLUDE=str(headers), HOSTCFLAGS="-O2"))
        call = self.calls()[0]
        hostflags = [arg for arg in call if arg.startswith("HOSTCFLAGS=")]
        self.assertEqual(len(hostflags), 1)
        self.assertIn("-O2", hostflags[0])
        import shlex
        self.assertIn("-I" + str(headers), shlex.split(hostflags[0].split("=", 1)[1]))
        self.log.unlink()
        (headers / "elf.h").unlink()
        self.assertNotEqual(self.run_helper("kbuild.sh", "--darwin-experimental", str(source), str(out),
                                            KBUILD_ELF_INCLUDE=str(headers)).returncode, 0)
        self.assertEqual(self.calls(), [])
        self.mock("uname", "print('Linux')", log=False)
        self.assert_ok(self.run_helper("kbuild.sh", str(source), str(out), KBUILD_ELF_INCLUDE=str(headers)))
        self.assertFalse(any(arg.startswith("HOSTCFLAGS=") for arg in self.calls()[0]))

    def test_kbuild_refuses_symlinked_output_children_before_make(self):
        source, out = self.kernel_fixture()
        self.mock("uname", "print('Linux')", log=False)
        (out / "include").symlink_to(SCRIPTS.parent, target_is_directory=True)
        result = self.run_helper("kbuild.sh", str(source), str(out))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_new_helper_help_is_action_free(self):
        for name in ("ios-pull.sh", "kbuild.sh"):
            with self.subTest(name=name):
                result = self.run_helper(name, "--help")
                self.assert_ok(result)
                self.assertIn("Usage:", result.stdout)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
