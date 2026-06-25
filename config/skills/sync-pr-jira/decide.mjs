#!/usr/bin/env node
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(here, 'config.json'), 'utf8'));

const qaLogins = new Set(config.qa.map((q) => q.githubLogin.toLowerCase()));
const ignorePatterns = config.ignoreChecks;
const isIgnored = (name) => ignorePatterns.some((p) => name.includes(p));

function gh(args) {
    return JSON.parse(execFileSync('gh', args, { encoding: 'utf8', maxBuffer: 1024 * 1024 * 32 }));
}

function ticketFromBranch(branch) {
    const match = branch.match(/MWPW-\d+/i);
    return match ? match[0].toUpperCase() : null;
}

function checksGreenExceptIgnored(rollup) {
    const relevant = rollup.filter((c) => !isIgnored(c.name));
    const failing = relevant.filter(
        (c) => c.status === 'COMPLETED' && c.conclusion && !['SUCCESS', 'SKIPPED', 'NEUTRAL'].includes(c.conclusion),
    );
    const pending = relevant.filter((c) => c.status !== 'COMPLETED');
    return { ok: failing.length === 0 && pending.length === 0, failing, pending };
}

function decide(pr) {
    const lastCommitAt = pr.commits.length ? new Date(pr.commits[pr.commits.length - 1].committedDate) : null;
    const reviews = pr.reviews ?? [];

    const blocking = reviews.filter((r) => {
        if (!['CHANGES_REQUESTED', 'COMMENTED'].includes(r.state)) return false;
        if (r.author.login.toLowerCase() === config.me.githubLogin.toLowerCase()) return false;
        if (!r.submittedAt) return false;
        return !lastCommitAt || new Date(r.submittedAt) > lastCommitAt;
    });

    const freshChangesRequested = blocking.filter((r) => r.state === 'CHANGES_REQUESTED');
    const qaComments = blocking.filter((r) => qaLogins.has(r.author.login.toLowerCase()));

    const approvalsByUser = new Map();
    for (const r of reviews) {
        if (r.state === 'APPROVED' || r.state === 'CHANGES_REQUESTED') {
            approvalsByUser.set(r.author.login, r.state === 'APPROVED');
        }
    }
    const approvalCount = [...approvalsByUser.values()].filter(Boolean).length;
    const checks = checksGreenExceptIgnored(pr.statusCheckRollup ?? []);

    let target = null;
    let reason = '';

    if (freshChangesRequested.length || qaComments.length) {
        target = config.statuses.inDevelopment;
        const who = [...new Set([...freshChangesRequested, ...qaComments].map((r) => r.author.login))].join(', ');
        const kind = qaComments.length ? 'QA/reviewer feedback' : 'changes requested';
        reason = `${kind} after last commit (${who})`;
    } else if (approvalCount >= config.requiredApprovals && checks.ok) {
        target = config.statuses.readyForQa;
        reason = `${approvalCount} approvals, checks green, no pending feedback → assign QA`;
    } else if (checks.ok) {
        target = config.statuses.codeReview;
        reason = `checks green (Nala Gate ignored), awaiting ${config.requiredApprovals} approvals (have ${approvalCount})`;
    } else {
        target = null;
        reason = checks.pending.length
            ? `checks still running: ${checks.pending.map((c) => c.name).join(', ')}`
            : `checks failing: ${checks.failing.map((c) => c.name).join(', ')}`;
    }

    return {
        number: pr.number,
        title: pr.title,
        ticket: ticketFromBranch(pr.headRefName),
        approvalCount,
        target,
        assignQa: target === config.statuses.readyForQa,
        reason,
    };
}

const list = gh(['pr', 'list', '--author', '@me', '--state', 'open', '--json', 'number', '--limit', '50']);

const prs = list.map((p) =>
    gh(['pr', 'view', String(p.number), '--json', 'number,title,headRefName,reviews,commits,statusCheckRollup']),
);

const decisions = prs.map(decide);
process.stdout.write(JSON.stringify(decisions, null, 2));
