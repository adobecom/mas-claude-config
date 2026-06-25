#!/usr/bin/env node
import { readFileSync } from 'node:fs';

const JIRA_BASE = process.env.JIRA_BASE_URL ?? 'https://jira.corp.adobe.com';
const TOKEN = process.env.JIRA_PAT;
const EMAIL = process.env.JIRA_EMAIL;
const AUTH = TOKEN ? `Basic ${Buffer.from(`${EMAIL}:${TOKEN}`).toString('base64')}` : null;

let plan;
try {
    plan = JSON.parse(readFileSync(0, 'utf8')).filter((p) => p.target && p.ticket);
} catch {
    process.exit(0);
}
if (!plan.length) process.exit(0);

async function liveStatus(key) {
    try {
        const res = await fetch(`${JIRA_BASE}/rest/api/2/issue/${key}?fields=status`, {
            headers: { Authorization: AUTH },
        });
        if (!res.ok) return null;
        return (await res.json()).fields.status.name;
    } catch {
        return null;
    }
}

let pending;
if (TOKEN) {
    const withStatus = await Promise.all(plan.map(async (p) => ({ ...p, now: await liveStatus(p.ticket) })));
    pending = withStatus.filter((p) => p.now && p.now !== p.target);
} else {
    pending = plan.filter((p) => p.target === 'In Development' || p.target === 'Ready For QA');
}

if (!pending.length) process.exit(0);

const line = pending.map((p) => `#${p.number}→${p.target}`).join(', ');
console.log(`PR→Jira pending (/sync-pr-jira --apply to commit): ${line}`);
