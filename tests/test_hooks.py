"""Feeds JSON to each hook script and checks what it prints.

Run: python3 tests/test_hooks.py   (needs bash and jq, like the hooks)
"""
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOOKS = ROOT / "hooks"


def run_hook(name, payload, env=None):
    """Runs a hook with ``payload`` as stdin and returns its stdout."""
    result = subprocess.run(
        ["bash", str(HOOKS / name)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env={**os.environ, **(env or {})},
        check=True,
    )
    return result.stdout


class FilterTestOutput(unittest.TestCase):
    def decide(self, command):
        """Returns the rewritten command if the hook approved it, else None."""
        out = json.loads(run_hook("filter-test-output.sh", {"tool_input": {"command": command}}))
        if not out:
            return None
        self.assertEqual(out["hookSpecificOutput"]["permissionDecision"], "allow")
        return out["hookSpecificOutput"]["updatedInput"]["command"]

    def test_plain_test_commands_are_rewritten_and_approved(self):
        for command in [
            "pytest",
            "pytest -q",
            "python -m pytest -x --lf",
            "uv run pytest -k 'a and not b' tests/test_x.py::TestA::test_b[1]",
            "poetry run pytest -n auto --cov=src --cov-report=term-missing",
            "source .venv/bin/activate && pytest -vv --tb=short",
            "python manage.py test",
            "poetry run python manage.py test app.tests --keepdb -v 2",
            "cargo test",
            "cargo +nightly test -p core --all-features -- --nocapture",
            "cargo nextest run -E 'test(foo)'",
            "mvn test",
            "mvn -q verify -pl core -am",
            "mvn test -Dtest=FooTest#bar -DfailIfNoTests=false",
        ]:
            with self.subTest(command=command):
                new = self.decide(command)
                self.assertIsNotNone(new)
                self.assertTrue(new.startswith(command.split(" ")[0]))
                # the rewrite must still parse as one valid shell command line
                subprocess.run(["bash", "-n", "-c", new], check=True)

    def test_mvn_gets_no_transfer_progress_once(self):
        self.assertEqual(self.decide("mvn -q test"), "mvn --no-transfer-progress -q test")
        self.assertEqual(self.decide("mvn -ntp test"), "mvn -ntp test")

    def test_unsafe_commands_pass_through(self):
        for command in [
            # Maven: other phases, plugin goals, profiles, unknown properties
            "mvn deploy -Dmaven.test.skip=true",
            "mvn release:perform -Darguments=-Dmaven.test.skip",
            "mvn clean test",
            "mvn install",
            "mvn test site",
            "mvn dependency:tree test",
            "mvn -Prelease verify",
            "mvn -P release verify",
            "mvn -f ../other/pom.xml test",
            "mvn test -Dmaven.repo.local=/tmp/x",
            "mvn",
            "mvn -q",
            # chained, substituted, redirected, commented
            "pytest; rm -rf x",
            "pytest && rm -rf x",
            "pytest || curl evil.sh",
            "pytest | tee out",
            "pytest & rm x",
            "pytest $(rm x)",
            'pytest "$(rm x)"',
            "pytest `rm x`",
            "pytest > out",
            "pytest < in",
            "pytest\nrm x",
            "pytest # x",
            "pytest '",
            "pytest {/,x}",
            "cargo +x;make test",
            # wrong tool or subcommand
            "pytest-watch",
            "python manage.py testserver",
            "python manage.py test_send_emails",
            "cargo testx",
            "uv run --with evil pytest",
            # flags with side effects, paths outside the project
            "pytest --basetemp=/tmp/x",
            "pytest --junitxml=/etc/x.xml",
            "pytest -p evil_plugin",
            "pytest -c other.ini",
            "pytest /etc",
            'pytest "/etc"',
            "pytest ../other",
            "pytest ~/x",
            "pytest -k",
            "python manage.py test --settings=evil",
            "cargo test --config build.rustc-wrapper=x",
            "cargo test --target-dir /tmp/x",
            "cargo test -- --logfile /tmp/x",
        ]:
            with self.subTest(command=command):
                self.assertIsNone(self.decide(command))


def bash_result(command, stdout, stderr="", **extra):
    """A PostToolUse payload for a successful Bash command."""
    return {
        "hook_event_name": "PostToolUse",
        "tool_input": {"command": command},
        "tool_response": {"stdout": stdout, "stderr": stderr, "interrupted": False, "isImage": False, **extra},
    }


def lines(*parts):
    return "\n".join(parts)


INSTALL_OUT = lines(*[f"Collecting pkg{i}" for i in range(80)], "Successfully installed pkg0 pkg1")
CARGO_OUT = lines(
    *[f"   Compiling crate{i} v0.1.0" for i in range(40)],
    "warning: unused variable: `x`",
    "    Finished `dev` profile in 3.2s",
)
MVN_OUT = lines(
    *[f"[INFO] Downloading thing{i}" for i in range(40)],
    "[WARNING] deprecated API",
    "Tests run: 3, Failures: 0, Errors: 0, Skipped: 0",
    "[INFO] BUILD SUCCESS",
    "[INFO] Total time: 2 s",
)
DOCKER_OUT = lines(*[f"#{i} [stage {i}] RUN step" for i in range(60)], "#61 naming to docker.io/app done")
DIFF_OUT = lines(
    "diff --git a/Cargo.lock b/Cargo.lock",
    "index 1..2 100644",
    "--- a/Cargo.lock",
    "+++ b/Cargo.lock",
    "@@ -1,3 +1,3 @@",
    *[f"-old{i}\n+new{i}" for i in range(30)],
    "diff --git a/src/main.rs b/src/main.rs",
    "--- a/src/main.rs",
    "+++ b/src/main.rs",
    "@@ -1 +1 @@",
    "-fn main() {}",
    '+fn main() { println!("hi"); }',
)


class TrimOutput(unittest.TestCase):
    def trimmed(self, payload, field="stdout"):
        """Returns the replaced stdout (or ``field``), or None when the hook left the result alone."""
        out = run_hook("trim-output.sh", payload)
        if not out.strip():
            return None
        response = json.loads(out)["hookSpecificOutput"]["updatedToolOutput"]
        # every other field of the Bash result is kept
        self.assertEqual(set(response), set(payload["tool_response"]))
        return response[field]

    def test_installs_keep_ends_and_summary(self):
        for command in ["pip install -r requirements.txt", "uv sync", "npm ci", "cd app && poetry install"]:
            with self.subTest(command=command):
                out = self.trimmed(bash_result(command, INSTALL_OUT))
                self.assertIn("trimmed by the eetc hook", out)
                self.assertIn("Successfully installed pkg0 pkg1", out)
                self.assertLess(len(out.splitlines()), len(INSTALL_OUT.splitlines()))

    def test_cargo_build_drops_progress_keeps_warnings(self):
        err = self.trimmed(bash_result("cargo build --release", "", CARGO_OUT), "stderr")
        self.assertNotIn("Compiling", err)
        self.assertIn("warning: unused variable", err)
        self.assertIn("Finished", err)

    def test_mvn_lifecycle_keeps_warnings_and_summary(self):
        out = self.trimmed(bash_result("mvn package", MVN_OUT))
        self.assertEqual(
            out,
            lines(
                "[WARNING] deprecated API",
                "Tests run: 3, Failures: 0, Errors: 0, Skipped: 0",
                "[INFO] BUILD SUCCESS",
                "[INFO] Total time: 2 s",
            ),
        )

    def test_docker_build_is_trimmed(self):
        out = self.trimmed(bash_result("docker build -t app .", DOCKER_OUT))
        self.assertIn("trimmed by the eetc hook", out)
        self.assertIn("naming to docker.io/app done", out)

    def test_lockfile_diff_is_hidden_other_files_kept(self):
        out = self.trimmed(bash_result("git diff", DIFF_OUT))
        self.assertIn("lockfile diff hidden", out)
        self.assertNotIn("+new0", out)
        self.assertIn('+fn main() { println!("hi"); }', out)

    def test_left_alone(self):
        cases = {
            "lockfile named in the command": bash_result("git diff Cargo.lock", DIFF_OUT),
            "interrupted": bash_result("uv sync", INSTALL_OUT, interrupted=True),
            "chained": bash_result("uv sync && pytest", INSTALL_OUT),
            "chained after": bash_result("pip install x; echo done", INSTALL_OUT),
            "plugin goal": bash_result("mvn dependency:tree", MVN_OUT),
            "short output": bash_result("uv sync", "Resolved 3 packages\nInstalled 3 packages"),
            "unrelated command": bash_result("ls -la", INSTALL_OUT),
            # a non-zero exit fires PostToolUseFailure: no tool_response, just an error
            "failed": {
                "hook_event_name": "PostToolUseFailure",
                "tool_input": {"command": "uv sync"},
                "error": "Exit code 1",
            },
        }
        for name, payload in cases.items():
            with self.subTest(name):
                self.assertEqual(run_hook("trim-output.sh", payload).strip(), "")

    def test_registered_only_for_successful_bash(self):
        hooks = json.loads((HOOKS / "hooks.json").read_text())["hooks"]
        self.assertNotIn("PostToolUseFailure", hooks)


class FormatOnEdit(unittest.TestCase):
    def test_no_formatter_config_is_a_noop(self):
        sources = {
            "x.py": "import os,sys\nx=  1\n",
            "x.rs": "fn main(){let x=1;}\n",
            "X.java": "class X{void f(){int x=1;}}\n",
            "x.go": "package x\nfunc f(){x:=1}\n",
        }
        with tempfile.TemporaryDirectory() as tmp:
            for name, source in sources.items():
                with self.subTest(name):
                    path = Path(tmp) / name
                    path.write_text(source)
                    out = run_hook(
                        "format-on-edit.sh",
                        {"tool_input": {"file_path": str(path)}},
                        env={"CLAUDE_PROJECT_DIR": tmp},
                    )
                    self.assertEqual(out, "")
                    self.assertEqual(path.read_text(), source)

    def test_gofmt_runs_in_go_modules_but_not_on_testdata(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            # a stub gofmt on PATH that marks the file it was asked to format
            (root / "bin").mkdir()
            gofmt = root / "bin" / "gofmt"
            gofmt.write_text('#!/bin/bash\necho formatted > "$2"\n')
            gofmt.chmod(0o755)
            (root / "go.mod").write_text("module example.com/x\n")
            (root / "testdata").mkdir()
            env = {"PATH": f"{root / 'bin'}:{os.environ['PATH']}"}
            for name, want in {"x.go": "formatted\n", "testdata/in.go": "package x\n"}.items():
                with self.subTest(name):
                    path = root / name
                    path.write_text("package x\n")
                    run_hook("format-on-edit.sh", {"tool_input": {"file_path": str(path)}}, env=env)
                    self.assertEqual(path.read_text(), want)


class Statusline(unittest.TestCase):
    """The template statusline shows the rate-limit reset time on macOS and Linux."""

    PAYLOAD = {"rate_limits": {"five_hour": {"used_percentage": 42.5, "resets_at": 1767225600}}}

    def render(self, fake_date=None):
        """Runs the statusline, optionally with ``date`` replaced by a shell script body."""
        with tempfile.TemporaryDirectory() as bin_dir:
            path = os.environ["PATH"]
            if fake_date is not None:
                shim = Path(bin_dir) / "date"
                shim.write_text(f"#!/bin/bash\n{fake_date}\n")
                shim.chmod(0o755)
                path = f"{bin_dir}:{path}"
            result = subprocess.run(
                ["bash", str(ROOT / "skills/claude-code-setup/templates/statusline.sh")],
                input=json.dumps(self.PAYLOAD),
                capture_output=True,
                text=True,
                env={**os.environ, "PATH": path},
                check=True,
            )
        self.assertEqual(result.stderr, "")
        return result.stdout

    def test_native_date(self):
        self.assertRegex(self.render(), r"↻ \d\d:\d\d")

    def test_gnu_date_fallback(self):
        # GNU `date -r` reads a file's mtime, so an epoch fails; `-d @epoch` works
        gnu = '[ "$1" = -d ] && [ "$2" = @1767225600 ] && echo 07:00 && exit 0; exit 1'
        self.assertIn("↻ 07:00", self.render(gnu))

    def test_no_working_date_hides_reset_time_silently(self):
        out = self.render("echo 'date: unsupported' >&2; exit 1")
        self.assertIn("session:", out)
        self.assertNotIn("↻", out)

    def run_with_tmpdir(self, payload, tmp):
        subprocess.run(
            ["bash", str(ROOT / "skills/claude-code-setup/templates/statusline.sh")],
            input=json.dumps(payload),
            capture_output=True,
            text=True,
            env={**os.environ, "TMPDIR": tmp},
            check=True,
        )

    def test_writes_current_context_size_for_the_handoff_hook(self):
        usage = {"input_tokens": 10, "output_tokens": 999, "cache_creation_input_tokens": 200, "cache_read_input_tokens": 3000}
        with tempfile.TemporaryDirectory() as tmp:
            self.run_with_tmpdir({"session_id": "s1", "context_window": {"current_usage": usage}}, tmp)
            self.assertEqual((Path(tmp) / "claude-ctx-s1").read_text().strip(), "3210")

    def test_writes_nothing_without_current_usage(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.run_with_tmpdir({"session_id": "s1", "context_window": {"current_usage": None}}, tmp)
            self.assertEqual(os.listdir(tmp), [])


class ContextHandoff(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.project = tempfile.mkdtemp()
        self.addCleanup(subprocess.run, ["rm", "-rf", self.tmp, self.project])
        self.env = {"TMPDIR": self.tmp, "CLAUDE_PROJECT_DIR": self.project}

    def stop(self, tokens=None, session="s1", **env):
        if tokens is not None:
            (Path(self.tmp) / f"claude-ctx-{session}").write_text(f"{tokens}\n")
        return run_hook("context-handoff.sh", {"session_id": session, "hook_event_name": "Stop"}, env={**self.env, **env})

    def test_below_threshold_is_silent(self):
        self.assertEqual(self.stop(443999), "")

    def test_at_threshold_blocks_once_per_session(self):
        out = json.loads(self.stop(444000))
        self.assertEqual(out["decision"], "block")
        for text in ["AskUserQuestion", '"Write handoff and clear"', '"Continue"', "/clear",
                     f"{self.project}/.claude/handoff.md", "headless"]:
            self.assertIn(text, out["reason"])
        self.assertEqual(self.stop(500000), "")
        # another session still gets asked
        self.assertIn("block", self.stop(444000, session="s2"))

    def test_missing_token_file_is_silent(self):
        self.assertEqual(self.stop(), "")

    def test_env_var_overrides_threshold(self):
        self.assertEqual(self.stop(1000, EETC_HANDOFF_TOKENS="1001"), "")
        self.assertIn("block", self.stop(1001, EETC_HANDOFF_TOKENS="1001"))

    def test_bad_session_id_is_ignored(self):
        # threshold 0 would block any accepted session, even without a token file
        self.assertIn("block", self.stop(EETC_HANDOFF_TOKENS="0"))
        self.assertEqual(self.stop(session="../x", EETC_HANDOFF_TOKENS="0"), "")

    def test_load_handoff_prints_note_once(self):
        note = Path(self.project) / ".claude" / "handoff.md"
        note.parent.mkdir()
        note.write_text("next: ship it\n")
        payload = {"hook_event_name": "SessionStart", "source": "clear"}
        self.assertEqual(run_hook("load-handoff.sh", payload, env=self.env),
                         "Handoff from the previous session:\nnext: ship it\n")
        self.assertFalse(note.exists())
        self.assertTrue(note.with_name("handoff.md.used").exists())
        self.assertEqual(run_hook("load-handoff.sh", payload, env=self.env), "")

    def test_load_handoff_without_note_is_silent(self):
        self.assertEqual(run_hook("load-handoff.sh", {"source": "clear"}, env=self.env), "")

    def test_registered_on_stop_and_after_clear(self):
        hooks = json.loads((HOOKS / "hooks.json").read_text())["hooks"]
        self.assertIn("context-handoff.sh", hooks["Stop"][0]["hooks"][0]["command"])
        self.assertEqual(hooks["SessionStart"][0]["matcher"], "clear")


class ReviewAgentsOnSonnet(unittest.TestCase):
    def model(self, **tool_input):
        """Returns the model the hook sets, or None if it leaves the call alone."""
        out = run_hook("review-agents-on-sonnet.sh", {"tool_input": {"prompt": "p", **tool_input}})
        if not out:
            return None
        updated = json.loads(out)["hookSpecificOutput"]["updatedInput"]
        self.assertEqual(updated["prompt"], "p")
        return updated["model"]

    def test_simplify_review_agents_run_on_sonnet(self):
        for description in ["Reuse review of diff", "Simplify review: altitude", "Efficiency review",
                            "Simplification review of move", "Hub simplify review: reuse"]:
            with self.subTest(description=description):
                self.assertEqual(self.model(description=description, subagent_type="Explore"), "sonnet")

    def test_other_agents_and_explicit_models_are_left_alone(self):
        self.assertIsNone(self.model(description="Find auth handlers"))
        self.assertIsNone(self.model(description="Fetch hooks docs"))
        self.assertIsNone(self.model())
        self.assertIsNone(self.model(description="Reuse review", model="opus"))


if __name__ == "__main__":
    unittest.main()
