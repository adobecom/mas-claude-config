#!/usr/bin/env node
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const config = JSON.parse(readFileSync(join(here, 'config.json'), 'utf8'));

const JIRA_BASE = process.env.JIRA_BASE_URL ?? 'https://jira.corp.adobe.com';
const JIRA_TOKEN = process.env.JIRA_PAT;
const JIRA_EMAIL = process.env.JIRA_EMAIL;
const APPLY = process.argv.includes('--apply');
const ALLOW_BACKWARD = process.env.ALLOW_BACKWARD === '1';

if (!JIRA_TOKEN || !JIRA_EMAIL) {
    console.error('JIRA_PAT and JIRA_EMAIL env vars are required (Basic auth).');
    process.exit(2);
}

const JIRA_AUTH = `Basic ${Buffer.from(`${JIRA_EMAIL}:${JIRA_TOKEN}`).toString('base64')}`;

const ORDER = [config.statuses.inDevelopment, config.statuses.codeReview, config.statuses.readyForQa];
const isBackward = (from, to) => ORDER.indexOf(to) < ORDER.indexOf(from);

async function jira(path, init = {}) {
    const res = await fetch(`${JIRA_BASE}/rest/api/2${path}`, {
        ...init,
        headers: {
            Authorization: JIRA_AUTH,
            'Content-Type': 'application/json',
            ...(init.headers ?? {}),
        },
    });
    if (!res.ok) throw new Error(`${init.method ?? 'GET'} ${path} → ${res.status} ${await res.text()}`);
    return res.status === 204 ? null : res.json();
}

async function currentStatus(key) {
    const data = await jira(`/issue/${key}?fields=status,assignee`);
    return { status: data.fields.status.name, assignee: data.fields.assignee?.name ?? null };
}

async function transitionTo(key, statusName) {
    const { transitions } = await jira(`/issue/${key}/transitions`);
    const match = transitions.find((t) => t.to.name === statusName);
    if (!match) return { ok: false, reason: `'${statusName}' not reachable from current status` };
    await jira(`/issue/${key}/transitions`, {
        method: 'POST',
        body: JSON.stringify({ transition: { id: match.id } }),
    });
    return { ok: true };
}

async function assign(key, jiraName) {
    await jira(`/issue/${key}/assignee`, { method: 'PUT', body: JSON.stringify({ name: jiraName }) });
}

const decisions = JSON.parse(readFileSync(0, 'utf8')).filter((d) => d.target && d.ticket);
const qaName = config.qa[0]?.jiraName;
const results = [];

for (const d of decisions) {
    try {
        const { status: now, assignee } = await currentStatus(d.ticket);
        const needsStatus = now !== d.target;
        const needsAssign = d.assignQa && assignee !== qaName;
        if (!needsStatus && !needsAssign) {
            results.push(`= ${d.ticket} already ${now}${d.assignQa ? ' + assigned' : ''} (no-op)`);
            continue;
        }
        const backward = needsStatus && isBackward(now, d.target);
        if (backward && !ALLOW_BACKWARD) {
            results.push(`⚠ ${d.ticket} ${now} → ${d.target} BACKWARD — skipped (set ALLOW_BACKWARD=1 to apply): ${d.reason}`);
            continue;
        }
        if (!APPLY) {
            results.push(`DRY ${d.ticket} ${now} → ${d.target}${needsAssign ? ' + assign QA' : ''}: ${d.reason}`);
            continue;
        }
        if (needsStatus) {
            const t = await transitionTo(d.ticket, d.target);
            if (!t.ok) {
                results.push(`✗ ${d.ticket} ${t.reason}`);
                continue;
            }
        }
        if (needsAssign) await assign(d.ticket, qaName);
        results.push(`✓ ${d.ticket} ${now} → ${d.target}${needsAssign ? ' + assigned QA' : ''}`);
    } catch (err) {
        results.push(`✗ ${d.ticket} ERROR: ${err.message}`);
    }
}

console.log(results.join('\n'));
console.log(APPLY ? '\nApplied.' : '\nDry-run. Re-run with --apply to commit.');
