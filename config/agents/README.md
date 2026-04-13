# MAS Project Agents

Specialized Claude Code agents for the Adobe MAS (Merch-at-Scale) project. These agents provide focused expertise for different aspects of development and testing.

## Available Agents

### Testing & QA

#### 🧪 [NALA Test Runner Agent](./nala-runner.md)
Runs, debugs, and fixes NALA E2E tests. Dispatches to the `nala-runner` skill for execution, pre-flight checks, failure diagnosis, and automated fixing.

#### ✍️ [NALA Test Author Agent](./nala-author.md)
Writes and modifies NALA E2E tests. Dispatches to the `nala-writer` skill for test creation following Category A/B/C patterns.

#### 🎯 [Studio Test Suite](./studio-test-suite.md)
Specializes in Adobe Studio component testing with deep knowledge of test patterns for edit, save, discard, and CSS validation.

### Development

#### 🏗️ [MAS Component Builder](./mas-component-builder.md)
Creates new MAS web components following Adobe patterns, implementing proper JavaScript structure and accessibility features.

#### ✏️ [RTE Field Specialist](./rte-field-specialist.md)
Handles Rich Text Editor modifications, including divider handling, formatting options, and editor configurations.

### Commerce & Pricing

#### 💰 [Expert Pricing Agent (AOS / WCS / MCS)](./commerce-pricing-agent.md)
Full-stack pricing expert: AOS offer discovery, WCS artifact resolution, MCS merchandising content, MCP pricing tools, price templates, tax display for 60+ locales, ICU literals, checkout URLs, and promotional pricing.

#### 🛒 [Merch Card Creator](./merch-card-creator.md)
End-to-end card creation: product lookup, offer selector creation, AEM fragment creation via MCP, offer linking, variant selection, tag management, and rendering validation. Integrates with figma-to-merch-card skill.

### Hydration & Fragments

#### 🔄 [Hydration & Fragment Architecture](./hydrate-fragment-agent.md)
Specialist for the hydrate.js pipeline (20+ process* functions), aemFragmentMapping schema, field-to-DOM mapping, and fragment store architecture (ReactiveStore → FragmentStore → Source/Preview pairing).

### Card Variants

#### 🃏 [Card Variant Developer](./card-variant-developer.md)
Guides creation and modification of card variants: VariantLayout base class, aemFragmentMapping structure, variant registration, stylesheet adoption, and height synchronization patterns across 18 variants.

### Collections

#### 📋 [Collection & Filtering Specialist](./collection-filtering-agent.md)
Manages merch-card-collection.js (1,094 lines): reducer pipeline, category/type/search filters, sorting, pagination, sidenav integration, and header component configuration.

### Design System

#### 🎨 [CSS & Design System Specialist](./css-design-system-agent.md)
Covers all --consonant-merch-* custom properties, breakpoints from media.js, variant stylesheet adoption, Spectrum CSS vs SWC decision tree, slot-based styling patterns, and typography scale.

### Architecture

#### 🏛️ [Studio State & Architecture](./studio-state-architecture-agent.md)
Specialist for the ReactiveStore/StoreController system: 30+ reactive stores, router-URL sync, fragment editing lifecycle, object reference stability, and common anti-patterns.

### Accessibility

#### ♿ [Accessibility & WCAG Specialist](./accessibility-audit-agent.md)
Handles ARIA patterns, focus management, Lighthouse audit workflows, card variant a11y requirements, dialog accessibility, price accessibility labels, and PR review checklists.

### I/O Runtime

#### ⚙️ [Expert I/O Runtime Agent](./io-pipeline-debugger.md)
Full-stack IO expert: Akamai CDN caching, fragment pipeline (7 transformers), Odin/AEM integration, WCS enrichment, Studio actions, state management, CI/CD workflows, Grafana/Splunk monitoring, and deployment.

### Milo Integration

#### 🔗 [Milo Integration Specialist](./milo-integration-specialist.md)
Expert at the MAS-Milo boundary: component consumption, maslibs/milolibs parameter resolution, fragment loading pipeline, hydration flow, WCS cache prefill, bundle architecture, JSON-LD structured data, and cross-repo debugging.

### Surface Configuration

#### 🌍 [Surface Configuration Expert](./surface-configuration-expert.md)
Surface-specific configuration: locale definitions per surface (acom, ccd, express, adobe-home), WCS API key mapping, dictionary paths, corrector rules, settings application, and variant support per surface.

### Fragment Operations

#### 📦 [AEM Fragment Operations](./aem-fragment-operations.md)
Bulk and advanced fragment operations via MCP: card CRUD, collection management, cross-locale creation, tag management, offer linking, content auditing, orphan detection, and ETag-based optimistic concurrency.

### SEO

#### 🔍 [SEO & Structured Data](./seo-structured-data-agent.md)
JSON-LD schema.org Product/Offer markup: opt-in mechanism via jsonld=on links, price extraction from inline-price elements, promo pricing with priceSpecification, Google Rich Results validation, and Studio copy integration.

### Incident Response

#### 🚨 [Incident Response](./incident-response-agent.md)
Production triage: Grafana/Splunk dashboard interpretation, common failure patterns (timeouts, stale cache, WCS missing, auth failures), quick response commands, IO Runtime state debugging, and escalation paths.

### Studio UI

#### 🪟 [Studio Dialog & Modal Expert](./studio-dialog-modal-expert.md)
Dialog patterns: confirm dialog (Promise-based), create dialog (card/collection), copy dialog, variation dialog, OST integration, Spectrum component usage, field editors, form validation, and new dialog templates.

### Release & Deployment

#### 🚀 [Release Coordinator](./release-coordinator.md)
Release management: PR creation with templates, CI/CD workflow inventory (17 workflows), branch sync strategy, cross-repo coordination (MAS + Milo), deployment verification, and CI failure troubleshooting.

### Migration

#### 🔄 [Migration Agent](./migration-agent.md)
Content migration: Odin schema transformation, cross-surface migration with variant compatibility, new locale rollout workflows, content restructuring, collection reorganization, and post-migration validation.

### Performance

#### ⚡ [Performance & Bundle Agent](./performance-bundle-agent.md)
Web performance: bundle size analysis (mas.js 592KB), WCS request batching and cache architecture, loading optimization, LCP/CLS debugging, esbuild configuration, IO pipeline timeout tuning, and coverage thresholds.

### Translation

#### 🌐 [Translation Pipeline Specialist](./translation-pipeline-agent.md)
Manages the translation project lifecycle: create → edit items/locales → save → submit to I/O Runtime. Covers selection snapshots, disabled actions pattern, and store-based validation.

### Promotions

#### 📅 [Promotions & Scheduling Specialist](./promotions-scheduling-agent.md)
Handles promotion fragment model, status lifecycle (scheduled → active → expired), date/time UTC conversion, surfaces selection modal, tags integration, and status-based filtering.

### Placeholders

#### 📝 [Placeholders System Specialist](./placeholders-system-agent.md)
Manages placeholder CRUD with RTE integration, key normalization, pending state management to prevent race conditions, bulk operations, and event subscription lifecycle.

### Infrastructure

#### 📦 [MiloLibs Manager](./milolibs-manager.md)
Manages library configuration, switching between local, branch, and production libraries with proper URL parameters.

#### 🖥️ [AEM Server Manager](./aem-server-manager.md)
Handles AEM server lifecycle, proxy configuration, port management, and troubleshooting server issues.

#### 🌳 [Git Worktree Coordinator](./git-worktree-coordinator.md)
Creates and manages git worktrees for parallel development, enabling efficient multi-branch testing and development.

### Knowledge & Context

#### 🔍 [Fluffyjaws Context](./fluffyjaws-context.md)
Research-only agent that queries Fluffyjaws to gather and validate company context — Jira tickets, Confluence docs, Slack history, team conventions, and architectural decisions.

### Code Quality

#### 🧹 [Lint Enforcer](./lint-enforcer.md)
Enforces code quality standards, runs linters automatically, fixes common issues, and ensures no underscore-prefixed variables.

#### ⚡ [Playwright Optimizer](./playwright-optimizer.md)
Optimizes Playwright test performance, reduces flakiness, implements parallel execution, and improves test stability.

## How to Use These Agents

1. **Identify your task** - Determine which agent specializes in your needs
2. **Reference the agent** - Ask Claude Code to act as the specific agent
3. **Provide context** - Share relevant code, errors, or requirements
4. **Follow guidance** - The agent will provide specialized assistance

## Example Usage

```
"Act as the NALA Test Runner agent and help me run the Studio tests with local libraries"

"Use the MAS Component Builder agent to create a new merch card variant"

"As the AEM Server Manager agent, help me troubleshoot why the proxy isn't working"

"Use the Commerce & Pricing agent to debug why tax isn't showing for Japan"

"Act as the Hydration & Fragment agent to add a new field to the card"
```

## Agent Capabilities

Each agent has:
- **Deep domain knowledge** in their specific area
- **Best practices** and patterns specific to MAS project
- **Troubleshooting guides** for common issues
- **Code examples** and templates
- **Command references** for quick actions

## Project-Specific Rules

All agents follow these MAS project rules:
- ✅ Always run linter after code changes
- ✅ Use `milolibs=local` parameter for local development
- ✅ Run proxy from `@studio/` when AEM server is started
- ✅ Ensure AEM is running with `aem up` before NALA tests
- ❌ Never use underscore-prefixed variables

## Quick Reference

| Task | Agent | Key Command |
|------|-------|-------------|
| Run NALA tests | Expert NALA Agent | `npm run nala local -g=@tag mode=headed` |
| Fix failing test | Expert NALA Agent | Reproduce headed → check selector/timing → update page object |
| Create component | MAS Component Builder | Follow LitElement patterns |
| Manage libraries | MiloLibs Manager | `MILO_LIBS="&milolibs=local"` |
| Start dev environment | AEM Server Manager | `aem up && cd studio && npm run proxy` |
| Create worktree | Git Worktree Coordinator | `git worktree add ../mas-feature branch` |
| Fix linting issues | Lint Enforcer | `npm run lint:fix` |
| Optimize tests | Playwright Optimizer | Implement parallel execution |
| Company context lookup | Fluffyjaws Context | `fj chat "question"` |
| Debug pricing/tax | Expert Pricing Agent | Check `DISPLAY_TAX_MAP` → `resolveDisplayTaxForGeoAndSegment` |
| Create a new card | Merch Card Creator | list_products → create_offer_selector → create_card → link |
| MAS ↔ Milo issue | Milo Integration | Check maslibs, mas-commerce-service, aem-fragment loading |
| Surface locale issue | Surface Configuration | Check locales.js surface arrays, dictionary paths |
| Bulk card operations | AEM Fragment Operations | mcp__mas__search_cards → create/update/tag in batch |
| JSON-LD / SEO | SEO & Structured Data | Check jsonld=on param, inline-price resolution |
| Production incident | Incident Response | Triage tree → Grafana/Splunk → state inspection |
| Studio dialog issue | Studio Dialog Expert | Check dialog pattern, OST integration, Spectrum components |
| PR / deploy issue | Release Coordinator | Check CI workflow status → diagnose failure |
| Content migration | Migration Agent | Schema transform → surface compat → locale rollout |
| Bundle / perf issue | Performance & Bundle | Check bundle sizes, WCS batching, timeout config |
| Card not rendering | Hydration & Fragment | Trace `hydrate()` → process* function chain |
| Add new variant | Card Variant Developer | VariantLayout subclass → register → stylesheet |
| Collection filtering | Collection & Filtering | Debug reducer pipeline → filter functions |
| Fix layout/CSS | CSS & Design System | Check `--consonant-merch-*` → breakpoints → stylesheet adoption |
| Store not updating | Studio State & Architecture | Check `notify()` → subscription → StoreController |
| Check accessibility | Accessibility & WCAG | Lighthouse audit → ARIA patterns → focus management |
| Pipeline broken | I/O Pipeline Debugger | Trace 7-transformer sequence → check logs |
| Translation project | Translation Pipeline | Project lifecycle → selection snapshots → validation |
| Create promotion | Promotions & Scheduling | Fragment model → date handling → status lifecycle |
| Edit placeholder | Placeholders System | Key normalization → RTE integration → pending state |

## Contributing

When updating agents:
1. Keep documentation current with codebase changes
2. Add new patterns and solutions as discovered
3. Update examples with real project scenarios
4. Maintain consistency across all agents

## Support

For issues or improvements to these agents, update the relevant `.md` file in the `.claude/agents/` directory.
