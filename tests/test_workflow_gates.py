#!/usr/bin/env python3
"""Exercise workflow failures against temporary Git histories and a fake CI service."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from workflow_guard import (check_review_transition, check_staged_branch,
                            check_transition, check_version_history, check_workflow, git)


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        git(self.root, 'init', '-b', 'phase/00-test')
        git(self.root, 'config', 'user.name', 'Test')
        git(self.root, 'config', 'user.email', 'test@example.invalid')
        self.version('0.1.9')
        self.write('.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md', '# Review\nB-01 Blocker: original finding\n')
        self.commit()
        self.base = git(self.root, 'rev-parse', 'HEAD').strip()
        self.write('.planning/STATE.md', f'---\nmain_baseline: {self.base}\nactive_branch: phase/00-test\n---\n')
        self.commit()

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def version(self, version):
        self.write('mfile', json.dumps({'version': version, 'title': f'boop Hunter {version}'}))
        self.write('src/scripts/boop/boop_init.lua', f'boop.version = "{version}"\n')
        self.write('CODEX.md', f'Current synchronized package version: `{version}`\n')

    def stage(self):
        git(self.root, 'add', '-A')

    def commit(self):
        self.stage()
        git(self.root, 'commit', '-qm', 'test boundary')

    def test_planning_only_preserves_version(self):
        self.write('.planning/notes.md', 'evidence')
        self.stage()
        self.assertEqual([], check_version_history(self.root))
        self.assertEqual([], check_workflow(self.root))

    def test_package_change_without_bump_fails(self):
        self.write('README.md', 'changed')
        self.stage()
        self.assertIn('must increase', ' '.join(check_version_history(self.root)))

    def test_later_bump_does_not_hide_earlier_missed_bump(self):
        self.write('README.md', 'missing bump')
        self.commit()
        self.version('0.1.10')
        self.commit()
        self.assertIn('must increase', ' '.join(check_version_history(self.root)))

    def test_numeric_comparison_and_fourth_component(self):
        for version in ['0.1.9.1', '0.1.10']:
            with self.subTest(version=version):
                self.version(version)
                self.stage()
                self.assertEqual([], check_version_history(self.root))

    def test_decrease_and_equivalent_trailing_zero_fail(self):
        for version in ['0.1.8.99', '0.1.9.0']:
            with self.subTest(version=version):
                self.version(version)
                self.stage()
                self.assertIn('must increase', ' '.join(check_version_history(self.root)))

    def test_malformed_or_unsynchronized_versions_fail(self):
        self.version('0.1.10a')
        self.stage()
        self.assertTrue(check_version_history(self.root))
        self.version('0.1.10')
        self.write('CODEX.md', 'Current synchronized package version: `0.1.9`')
        self.stage()
        self.assertIn('four version checkpoints', ' '.join(check_version_history(self.root)))

    def test_unstaged_bump_cannot_mask_staged_missing_bump(self):
        self.write('README.md', 'changed')
        self.stage()
        self.version('0.1.10')
        self.assertTrue(check_transition(self.root, 'HEAD', ':'))

    def test_rename_out_of_planning_is_package_affecting(self):
        git(self.root, 'mv', '.planning/STATE.md', 'STATE.md')
        self.assertIn('must increase', ' '.join(check_transition(self.root, 'HEAD', ':')))

    def test_package_deletion_requires_bump(self):
        self.write('README.md', 'old')
        self.version('0.1.10')
        self.commit()
        (self.root / 'README.md').unlink()
        self.stage()
        self.assertTrue(check_version_history(self.root))

    def test_missing_history_fails_closed(self):
        self.write('.planning/STATE.md', '---\nmain_baseline: ' + 'f' * 40 + '\n---\n')
        self.assertIn('full Git history required', ' '.join(check_version_history(self.root)))

    def test_review_append_passes_but_rewrite_or_delete_fails(self):
        name = '.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md'
        original = (self.root / name).read_text()
        self.write(name, original + '\nCodex proposal: awaiting re-review\n')
        self.stage()
        self.assertEqual([], check_review_transition(self.root, 'HEAD', ':'))
        self.write(name, original.replace('Blocker', 'Low'))
        self.stage()
        self.assertTrue(check_review_transition(self.root, 'HEAD', ':'))
        (self.root / name).unlink()
        self.stage()
        self.assertTrue(check_review_transition(self.root, 'HEAD', ':'))

    def test_later_restoration_does_not_hide_review_rewrite(self):
        name = '.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md'
        original = (self.root / name).read_text()
        self.write(name, 'rewritten')
        self.commit()
        self.write(name, original)
        self.commit()
        self.assertTrue(check_workflow(self.root))

    def test_staged_main_detached_or_wrong_phase_is_rejected(self):
        self.write('.planning/notes.md', 'change')
        self.stage()
        self.assertEqual([], check_staged_branch(self.root))
        for branch in ['main', 'phase/01-wrong']:
            git(self.root, 'checkout', '-qb', branch)
            self.assertTrue(check_staged_branch(self.root))
        git(self.root, 'checkout', '--detach')
        self.assertTrue(check_staged_branch(self.root))

    def test_live_legacy_configuration_is_rejected(self):
        self.write('.planning/config.json', '{}')
        self.assertIn('retired', ' '.join(check_workflow(self.root)))


class ExactCITests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.repo = root / 'repo'
        self.repo.mkdir()
        (self.repo / 'tools').mkdir()
        shutil.copy(ROOT / 'tools/wait_for_exact_ci.sh', self.repo / 'tools')
        git(self.repo, 'init', '-b', 'phase/00-test')
        git(self.repo, 'config', 'user.name', 'Test')
        git(self.repo, 'config', 'user.email', 'test@example.invalid')
        git(self.repo, 'add', '.')
        git(self.repo, 'commit', '-qm', 'test')
        self.sha = git(self.repo, 'rev-parse', 'HEAD').strip()
        self.remote = root / 'remote.git'
        git(root, 'init', '--bare', str(self.remote))
        git(self.repo, 'remote', 'add', 'origin', str(self.remote))
        git(self.repo, 'push', '-q', 'origin', 'HEAD')
        fakebin = root / 'bin'
        fakebin.mkdir()
        gh = fakebin / 'gh'
        gh.write_text('''#!/usr/bin/env python3
import os, sys
args = sys.argv[1:]
if args[:2] == ['auth', 'status']:
    sys.exit(0)
if args[:2] == ['run', 'list']:
    # A newer green PR/other-branch run must never mask the selected push run.
    assert args[args.index('--event')+1] == 'push'
    assert args[args.index('--branch')+1] == 'phase/00-test'
    assert args[args.index('--commit')+1] == os.environ['TEST_SHA']
    print('101')
elif args[:2] == ['run', 'watch']:
    assert args[2] == '101'
    sys.exit(1 if os.environ.get('TEST_FAILED') else 0)
elif args[:2] == ['run', 'view']:
    key = args[args.index('--json')+1]
    values = dict(headSha=os.environ['TEST_SHA'], conclusion='success', url='https://example.invalid/run/101', event='push', headBranch='phase/00-test', attempt='2')
    if os.environ.get('TEST_TAMPER') == key:
        values[key] = 'wrong'
    print(values[key])
else:
    sys.exit(2)
''')
        gh.chmod(0o755)
        self.env = dict(os.environ, PATH=str(fakebin) + os.pathsep + os.environ['PATH'],
                        TEST_SHA=self.sha, BOOP_CI_DISCOVERY_TIMEOUT='1', BOOP_CI_POLL_SECONDS='0')

    def run_gate(self):
        return subprocess.run(['bash', 'tools/wait_for_exact_ci.sh', self.sha],
                              cwd=self.repo, env=self.env, capture_output=True, text=True)

    def test_exact_push_run_and_attempt_reported(self):
        result = self.run_gate()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('run=101 attempt=2', result.stdout)

    def test_failed_push_cannot_be_masked_by_green_pr(self):
        self.env['TEST_FAILED'] = '1'
        self.assertNotEqual(0, self.run_gate().returncode)

    def test_post_watch_identity_is_reverified(self):
        for field in ['headSha', 'event', 'headBranch']:
            with self.subTest(field=field):
                self.env['TEST_TAMPER'] = field
                self.assertNotEqual(0, self.run_gate().returncode)

    def test_dirty_worktree_is_rejected(self):
        (self.repo / 'untracked').write_text('change')
        self.assertIn('not clean', self.run_gate().stderr)

    def test_sha_on_other_remote_ref_is_not_enough(self):
        git(self.repo, 'push', '-q', 'origin', 'HEAD:refs/heads/phase/01-other')
        git(self.repo, 'push', '-q', 'origin', '--delete', 'phase/00-test')
        self.assertIn('does not point', self.run_gate().stderr)


if __name__ == '__main__':
    unittest.main()
