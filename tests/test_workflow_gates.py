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
                            check_transition, check_version_history, check_workflow,
                            git, handoff_errors, review_completion_errors)
from check_merge_authorization import approval_tag_errors, closure_tail_errors
from check_handoff_execution import execution_errors


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        git(self.root, 'init', '-b', 'phase/00-test')
        git(self.root, 'config', 'user.name', 'Test')
        git(self.root, 'config', 'user.email', 'test@example.invalid')
        # Git may otherwise launch background auto-gc after the tag-push test,
        # racing TemporaryDirectory cleanup on CI runners.
        git(self.root, 'config', 'gc.auto', '0')
        self.version('0.1.9')
        self.write('.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md', '# Review\nB-01 Blocker: original finding\n')
        self.commit()
        self.base = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'update-ref', 'refs/remotes/origin/main', self.base)
        self.write('.planning/STATE.md', f'---\nmain_baseline: {self.base}\nactive_branch: phase/00-test\n---\n')
        self.handoff('CODEX', 'codex')
        self.handoff('CLAUDE', 'claude')
        self.commit()
        git(self.root, 'update-ref', 'refs/remotes/origin/phase/00-test',
            git(self.root, 'rev-parse', 'HEAD').strip())

    def write(self, name, text):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def version(self, version):
        self.write('mfile', json.dumps({'version': version, 'title': f'boop Hunter {version}'}))
        self.write('src/scripts/boop/boop_init.lua', f'boop.version = "{version}"\n')
        self.write('CODEX.md', f'Current synchronized package version: `{version}`\n')

    def handoff(self, name, agent, status='idle', mode=None, branch=None, base=None, target=None):
        self.write(f'.planning/{name}-NEXT.md', (
            '---\n'
            'handoff_version: 1\n'
            f'status: {status}\n'
            f'agent: {agent}\n'
            f'mode: {mode or "null"}\n'
            f'branch: {branch or "null"}\n'
            f'task_base_sha: {base or "null"}\n'
            f'review_target_sha: {target or "null"}\n'
            'assigned_by: Human + ChatGPT/Neon\n'
            '---\n'))

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

    def advance_baseline_to_head(self):
        sha = git(self.root, 'rev-parse', 'HEAD').strip()
        self.write('.planning/STATE.md', f'---\nmain_baseline: {sha}\nactive_branch: phase/00-test\n---\n')

    def assert_baseline_rejected(self):
        for check in [check_version_history, check_workflow]:
            with self.subTest(check=check.__name__):
                self.assertIn('must be an ancestor of refs/remotes/origin/main',
                              ' '.join(check(self.root)))

    def test_legitimate_main_baseline_passes(self):
        self.assertEqual([], check_version_history(self.root))
        self.assertEqual([], check_workflow(self.root))

    def test_phase_only_baseline_rejected_in_worktree_index_and_history(self):
        self.advance_baseline_to_head()
        self.assert_baseline_rejected()
        self.stage()
        self.assert_baseline_rejected()
        self.commit()
        self.assert_baseline_rejected()

    def test_advanced_baseline_cannot_hide_unbumped_package_commit(self):
        self.write('README.md', 'unbumped package change')
        self.commit()
        self.assertIn('must increase', ' '.join(check_version_history(self.root)))
        self.advance_baseline_to_head()
        self.commit()
        self.assert_baseline_rejected()

    def test_advanced_baseline_cannot_hide_review_tampering(self):
        self.write('.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md', 'fabricated replacement')
        self.commit()
        self.assertIn('unchanged prefix', ' '.join(check_workflow(self.root)))
        self.advance_baseline_to_head()
        self.commit()
        self.assert_baseline_rejected()

    def test_missing_authoritative_main_fails_even_with_local_main(self):
        git(self.root, 'branch', 'main', self.base)
        git(self.root, 'update-ref', '-d', 'refs/remotes/origin/main')
        for check in [check_version_history, check_workflow]:
            self.assertIn('authoritative refs/remotes/origin/main unavailable',
                          ' '.join(check(self.root)))

    def test_phase_commit_on_local_main_is_not_authoritative(self):
        git(self.root, 'branch', 'main')
        self.advance_baseline_to_head()
        self.assert_baseline_rejected()

    def test_main_baseline_must_also_be_ancestor_of_head(self):
        phase_head = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'checkout', '-qb', 'main', self.base)
        self.write('.planning/main-only.md', 'main history beyond the branch start')
        self.commit()
        main_head = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'update-ref', 'refs/remotes/origin/main', main_head)
        git(self.root, 'checkout', '-q', 'phase/00-test')
        self.assertEqual(phase_head, git(self.root, 'rev-parse', 'HEAD').strip())
        self.assertEqual([], check_version_history(self.root))
        self.assertEqual([], check_workflow(self.root))
        self.write('.planning/STATE.md', f'---\nmain_baseline: {main_head}\nactive_branch: phase/00-test\n---\n')
        self.assertTrue(check_version_history(self.root))
        self.assertTrue(check_workflow(self.root))

    def test_uat_and_verification_append_passes_rewrite_and_delete_fail(self):
        for suffix in ['UAT', 'VERIFICATION']:
            with self.subTest(artifact=suffix):
                name = f'.planning/phases/00-test/00-{suffix}.md'
                original = '# Historical record\nPending human determination / original evidence\n'
                self.write(name, original)
                self.commit()
                self.write(name, original + '\n## 2026-09-04 — dated decision/evidence\nAuthor: test fixture\n')
                self.stage()
                self.assertEqual([], check_workflow(self.root))
                self.write(name, original.replace('Pending', 'Approved'))
                self.stage()
                self.assertIn('unchanged prefix', ' '.join(check_workflow(self.root)))
                (self.root / name).unlink()
                self.stage()
                self.assertIn('must not be deleted', ' '.join(check_workflow(self.root)))
                self.write(name, original)
                self.stage()

    def test_existing_human_decision_cannot_be_replaced(self):
        name = '.planning/phases/00-test/00-UAT.md'
        original = ('## 2026-09-04 — Human (synthetic fixture)\n'
                    'Live validation: required\nMerge: not authorized\n')
        self.write(name, original)
        self.commit()
        self.write(name, original.replace('required', 'not_applicable').replace('not authorized', 'authorized'))
        self.stage()
        self.assertIn('unchanged prefix', ' '.join(check_workflow(self.root)))
        self.write(name, original + '\n## 2026-09-05 — Human (synthetic fixture)\nAdditional checks required.\n')
        self.commit()
        self.assertEqual([], check_workflow(self.root))

    def test_later_restoration_cannot_hide_uat_or_verification_tampering(self):
        for suffix in ['UAT', 'VERIFICATION']:
            with self.subTest(artifact=suffix):
                name = f'.planning/phases/00-test/00-{suffix}.md'
                original = '# 2026-09-04 — Original evidence\nAuthor: test fixture\n'
                self.write(name, original)
                self.commit()
                self.write(name, 'replacement evidence')
                self.commit()
                self.write(name, original)
                self.commit()
                self.assertTrue(any(name in error for error in check_workflow(self.root)))

    def test_even_empty_created_artifacts_cannot_be_deleted(self):
        for suffix in ['ADVERSARIAL-REVIEW', 'UAT', 'VERIFICATION']:
            with self.subTest(artifact=suffix):
                name = f'.planning/phases/01-test/01-{suffix}.md'
                self.write(name, '')
                self.commit()
                (self.root / name).unlink()
                self.stage()
                self.assertIn('must not be deleted', ' '.join(check_workflow(self.root)))
                self.write(name, '')
                self.stage()

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

    def test_handoff_schema_and_role_enums_are_enforced(self):
        self.handoff('CODEX', 'claude')
        self.stage()
        self.assertIn('agent must be codex', ' '.join(handoff_errors(self.root)))
        self.handoff('CLAUDE', 'claude', 'ready', 'phase_bootstrap', 'phase/00-test', self.base, self.base)
        self.stage()
        errors = ' '.join(handoff_errors(self.root))
        self.assertIn('Claude may use only', errors)
        self.handoff('CODEX', 'codex', 'idle', 'active_phase')
        self.stage()
        self.assertIn('idle handoffs require mode: null', ' '.join(handoff_errors(self.root)))

    def test_ready_handoff_requires_valid_head_ancestor_and_active_branch(self):
        self.handoff('CODEX', 'codex', 'ready', 'active_phase', 'phase/00-test', 'f' * 40)
        self.stage()
        self.assertIn('task_base_sha must resolve', ' '.join(handoff_errors(self.root)))
        self.handoff('CODEX', 'codex', 'ready', 'active_phase', 'phase/01-wrong', self.base)
        self.stage()
        self.assertIn('must match STATE active_branch', ' '.join(handoff_errors(self.root)))

    def test_review_target_must_resolve_and_be_reachable(self):
        self.handoff('CLAUDE', 'claude', 'ready', 'active_phase', 'phase/00-test', self.base, 'f' * 40)
        self.stage()
        self.assertIn('review_target_sha must resolve', ' '.join(handoff_errors(self.root)))
        git(self.root, 'reset', '--hard', 'HEAD')
        git(self.root, 'checkout', '-qb', 'other', self.base)
        self.write('.planning/other.md', 'unreachable target')
        self.commit()
        unreachable = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'checkout', '-q', 'phase/00-test')
        self.handoff('CLAUDE', 'claude', 'ready', 'active_phase', 'phase/00-test', self.base, unreachable)
        self.stage()
        self.assertIn('review_target_sha must resolve', ' '.join(handoff_errors(self.root)))
        self.handoff('CLAUDE', 'claude', 'ready', 'active_phase', 'phase/00-test', self.base, self.base)
        self.stage()
        self.assertEqual([], handoff_errors(self.root))

    def test_consumed_handoff_is_structurally_valid_but_not_ready(self):
        self.handoff('CLAUDE', 'claude', 'consumed', 'active_phase', 'phase/00-test', self.base, self.base)
        self.assertEqual([], handoff_errors(self.root))

    def test_bootstrap_delivery_is_the_only_staged_branch_exception(self):
        fork_base = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'update-ref', 'refs/remotes/origin/main', fork_base)
        git(self.root, 'checkout', '-qb', 'phase/01-bootstrap', fork_base)
        self.handoff('CODEX', 'codex', 'ready', 'phase_bootstrap', 'phase/01-bootstrap', fork_base)
        self.stage()
        self.assertEqual([], check_staged_branch(self.root))
        self.commit()
        self.write('.planning/CODEX-NEXT.md', (self.root / '.planning/CODEX-NEXT.md').read_text() + '\n')
        self.stage()
        self.assertTrue(check_staged_branch(self.root))
        git(self.root, 'reset', '--hard', 'HEAD')
        self.write('.planning/extra.md', 'bypass')
        self.stage()
        self.assertTrue(check_staged_branch(self.root))

    def test_closure_tail_rejects_unreviewed_runtime_and_authority_changes(self):
        reviewed = git(self.root, 'rev-parse', 'HEAD').strip()
        review = '.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md'
        self.write('.planning/STATE.md', (self.root / '.planning/STATE.md').read_text().replace(
            'active_branch: phase/00-test\n',
            f'active_branch: phase/00-test\nindependent_review_target_sha: {reviewed}\n'))
        self.commit()
        self.write(review, (self.root / review).read_text() +
                   f'\n**Reviewed target SHA:** `{reviewed}`\n')
        self.commit()
        self.assertEqual([], closure_tail_errors(self.root, '00'))
        self.write('src/scripts/boop/runtime.lua', 'unreviewed')
        self.commit()
        self.assertIn('runtime.lua', ' '.join(closure_tail_errors(self.root, '00')))
        self.write('AGENTS.md', 'unreviewed authority change')
        self.commit()
        self.assertIn('AGENTS.md', ' '.join(closure_tail_errors(self.root, '00')))

    def test_review_prose_cannot_advance_state_anchor(self):
        reviewed = git(self.root, 'rev-parse', 'HEAD').strip()
        self.write('.planning/STATE.md', (self.root / '.planning/STATE.md').read_text().replace(
            'active_branch: phase/00-test\n',
            f'active_branch: phase/00-test\nindependent_review_target_sha: {reviewed}\n'))
        self.commit()
        self.write('src/scripts/boop/unreviewed.lua', 'return false\n')
        self.commit()
        unreviewed = git(self.root, 'rev-parse', 'HEAD').strip()
        review = '.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md'
        self.write(review, (self.root / review).read_text() +
                   f'\nReviewed target SHA: {unreviewed}\n**Reviewed SHA:** `{unreviewed}`\n')
        self.commit()
        errors = ' '.join(closure_tail_errors(self.root, '00'))
        self.assertIn('unreviewed.lua', errors)

    def test_review_anchor_requires_coupled_consumed_claude_handoff(self):
        target = git(self.root, 'rev-parse', 'HEAD').strip()
        self.handoff('CLAUDE', 'claude', 'ready', 'active_phase', 'phase/00-test', self.base, target)
        self.commit()
        self.write('.planning/STATE.md', (self.root / '.planning/STATE.md').read_text().replace(
            'active_branch: phase/00-test\n', 'active_branch: phase/00-test\nactive_phase: "00"\n'))
        self.commit()
        self.write('.planning/STATE.md', (self.root / '.planning/STATE.md').read_text().replace(
            'active_phase: "00"\n',
            f'active_phase: "00"\nindependent_review_target_sha: {target}\n'))
        self.write('.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md',
                   (self.root / '.planning/phases/00-test/00-ADVERSARIAL-REVIEW.md').read_text() + '\nreview completion\n')
        self.stage()
        self.assertIn('requires matching ready -> consumed CLAUDE handoff',
                      ' '.join(review_completion_errors(self.root, 'HEAD', ':')))
        self.handoff('CLAUDE', 'claude', 'consumed', 'active_phase', 'phase/00-test', self.base, target)
        self.stage()
        self.assertEqual([], review_completion_errors(self.root, 'HEAD', ':'))

    def test_handoff_execution_rejects_unexpected_source_history(self):
        self.handoff('CODEX', 'codex', 'ready', 'active_phase', 'phase/00-test', self.base)
        self.commit()
        git(self.root, 'update-ref', 'refs/remotes/origin/phase/00-test',
            git(self.root, 'rev-parse', 'HEAD').strip())
        self.assertEqual([], execution_errors(self.root, 'codex'))
        self.write('src/scripts/boop/unexpected.lua', 'return true\n')
        self.version('0.1.10')
        self.commit()
        git(self.root, 'update-ref', 'refs/remotes/origin/phase/00-test',
            git(self.root, 'rev-parse', 'HEAD').strip())
        self.assertIn('unexpected pre-execution change', ' '.join(execution_errors(self.root, 'codex')))

    def test_approval_tag_binds_name_annotation_target_and_remote_object(self):
        remote = self.root / 'remote.git'
        git(self.root.parent, 'init', '--bare', str(remote))
        git(self.root, 'remote', 'add', 'origin', str(remote))
        sha = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'push', '-q', 'origin', f'HEAD:phase/00-test')
        git(self.root, 'update-ref', 'refs/remotes/origin/phase/00-test', sha)
        tag = f'phase-00-test-approved-{sha[:12]}'
        git(self.root, 'tag', '-a', tag, '-m',
            f'Human authorization — 2026-09-04\n\nHuman authorizes Phase 00-test exact SHA {sha}.')
        git(self.root, 'push', '-q', 'origin', tag)
        self.assertEqual([], approval_tag_errors(self.root, '00-test'))
        git(self.root, 'tag', '-f', tag, self.base)
        self.assertTrue(approval_tag_errors(self.root, '00-test'))

    def test_approval_tag_timestamp_tie_fails_closed(self):
        remote = self.root / 'remote-tie.git'
        git(self.root.parent, 'init', '--bare', str(remote))
        git(self.root, 'remote', 'add', 'origin', str(remote))
        first = git(self.root, 'rev-parse', 'HEAD').strip()
        self.write('.planning/later.md', 'later planning evidence')
        self.commit()
        second = git(self.root, 'rev-parse', 'HEAD').strip()
        git(self.root, 'push', '-q', 'origin', 'HEAD:phase/00-test')
        git(self.root, 'update-ref', 'refs/remotes/origin/phase/00-test', second)
        for sha in [first, second]:
            tag = f'phase-00-test-approved-{sha[:12]}'
            env = dict(os.environ, GIT_COMMITTER_DATE='2026-09-05T00:00:00Z')
            subprocess.run(['git', '-C', str(self.root), 'tag', '-a', tag, sha, '-m',
                            f'Human authorization — 2026-09-05\n\nHuman authorizes Phase 00-test exact SHA {sha}.'],
                           check=True, env=env)
            git(self.root, 'push', '-q', 'origin', tag)
        self.assertIn('share newest tagger timestamp', ' '.join(approval_tag_errors(self.root, '00-test')))
        git(self.root, 'tag', '-f', tag, sha)
        self.write('.planning/post-authorization.md', 'branch mutation')
        self.commit()
        self.assertTrue(approval_tag_errors(self.root, '00-test'))


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
