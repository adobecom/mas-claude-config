---
name: jira-ticket-creator
description: Create, file, open, make, or log Jira tickets in the MWPW project via corp-jira MCP. Handles required fields (team, component, issue type) automatically. Use when the user wants to create/file/open/make/log a Jira ticket, task, story, bug, or issue — any phrasing including "create jira", "file a ticket", "open a story", "make a bug", "log a ticket", "new MWPW ticket", "raise a bug".
tags: [jira, ticket, task, story, bug, mwpw]
triggers:
  - "create jira"
  - "create ticket"
  - "create task"
  - "create story"
  - "create bug"
  - "file a ticket"
  - "open a jira"
  - "log a ticket"
  - "make a jira"
---

# Jira Ticket Creator

## Purpose
Create Jira tickets in the MWPW project via `mcp__corp-jira` MCP tools, with all required fields pre-configured for the MAS team.

## Required Fields

The MWPW project requires these fields for ticket creation (will fail silently without them):

| Field | API Key | Value | Notes |
|-------|---------|-------|-------|
| Project | `project.key` | `"MWPW"` | Always MWPW |
| Summary | `summary` | User-provided | Ticket title |
| Issue Type | `issuetype.name` | `"Story"` / `"Task"` / `"Bug"` | Default: Story |
| Team | `customfield_12900.value` | `"Cosmocats"` | **Required** - creation fails without this |
| Component | `components[].name` | `"Merch at Scale (M@S) Studio"` | Default component |

## Optional Fields

| Field | API Key | Example |
|-------|---------|---------|
| Priority | `priority.name` | `"Minor"` / `"Major"` / `"Critical"` |
| Assignee | `assignee.name` | `"axel"` |
| Description | `description` | Jira wiki markup text |
| Labels | `labels` | `["M@S-Plans", "abm"]` |
| Epic Link | `customfield_11800` | `"DOTCOM-110039"` |

## Workflow

### Step 1: Gather Information

Ask the user (if not already provided):
- **Title** (required): What should the ticket be called?
- **Type** (optional): Story, Task, or Bug? Default: Story
- **Priority** (optional): Minor, Major, Critical? Default: Major
- **Description** (optional): Details about the work
- **Assignee** (optional): Who should it be assigned to?

### Step 2: Create the Ticket

```javascript
// Minimum viable ticket
mcp__corp-jira__create_jira_issue({
  fields: {
    project: { key: "MWPW" },
    summary: "Ticket title here",
    issuetype: { name: "Story" },
    customfield_12900: { value: "Cosmocats" },
    components: [{ name: "Merch at Scale (M@S) Studio" }]
  }
})
```

```javascript
// Full ticket with all optional fields
mcp__corp-jira__create_jira_issue({
  fields: {
    project: { key: "MWPW" },
    summary: "Ticket title here",
    issuetype: { name: "Story" },
    customfield_12900: { value: "Cosmocats" },
    components: [{ name: "Merch at Scale (M@S) Studio" }],
    priority: { name: "Major" },
    assignee: { name: "axel" },
    description: "Description in Jira wiki markup format"
  }
})
```

### Step 3: Report Result

On success, return:
- Ticket key (e.g., MWPW-190453)
- Link: `https://jira.corp.adobe.com/browse/MWPW-190453`

## Description Formatting

Jira uses wiki markup, NOT markdown. Key differences:

| Purpose | Markdown | Jira Wiki |
|---------|----------|-----------|
| Bold | `**text**` | `*text*` |
| Italic | `_text_` | `_text_` |
| Heading | `## Text` | `h2. Text` |
| Code block | ` ```js ``` ` | `{code:javascript}...{code}` |
| Code inline | `` `text` `` | `{{text}}` |
| Link | `[text](url)` | `[text\|url]` |
| Bullet list | `- item` | `* item` |
| Numbered list | `1. item` | `# item` |

## Available Components

Common components for MAS tickets:
- `Merch at Scale (M@S) Studio` — Studio web app
- `Merch Cards (M@S)` — Card web components
- `CC Plans` — Creative Cloud plans pages

## Other Useful MCP Operations

```javascript
// Search tickets
mcp__corp-jira__search_jira_issues({ jql: "project = MWPW AND assignee = axel AND status != Done" })

// Add comment
mcp__corp-jira__add_jira_comment({ issueKey: "MWPW-190453", body: "Comment text" })

// Transition status
mcp__corp-jira__get_jira_transitions({ issueKey: "MWPW-190453" })
mcp__corp-jira__transition_jira_status_by_name({ issueKey: "MWPW-190453", statusName: "In Progress" })

// Update ticket
mcp__corp-jira__update_jira_issue({ issueKey: "MWPW-190453", fields: { description: "Updated description" } })
```

## Troubleshooting

### "Failed to create issue" with no details
The MCP tool gives unhelpful errors. Common causes:
1. **Missing team field** (`customfield_12900`) — most common, always include it
2. **Wrong issue type name** — must be exact: `"Story"`, `"Task"`, `"Bug"`
3. **Wrong component name** — must match exactly, case-sensitive
4. **Auth expired** — run `mcp__corp-jira__test_jira_auth` to verify

### Verify auth
```javascript
mcp__corp-jira__test_jira_auth()
```
