# AgentForce Field Voice POC

A CLI-deployable **Agentforce Employee Agent with Agentforce Voice** for the Salesforce Mobile app. It reproduces the UI-based steps in the *Agentforce Voice – Field Voice – Employee Mobile Demo Setup Guide* as an Agent Script bundle, so the agent can be published to any SDO org with the `sf` CLI.

See [PRD.md](PRD.md) for the product requirements.

## What's in here

| Path | Purpose |
|---|---|
| `force-app/main/default/aiAuthoringBundles/Field_Voice_Agent/` | Agent Script (`.agent`) and bundle metadata |
| `force-app/main/default/classes/FieldVoice*.cls` | Apex actions that return spoken answers, the object catalog, the HCP name resolver, the speech formatter, and tests (see Architecture) |
| `force-app/main/default/permissionsets/Field_Voice_Agent_Access.permissionset-meta.xml` | Grants agent access and the Apex class |
| `sfdx-project.json` | Source API version 67.0 |

## What the agent does

- **Type:** `AgentforceEmployeeAgent`, a voice assistant that knows Life Sciences Cloud (LSC).
- **Router (`agent_router`)** sends each request to one of these subagents:

| Subagent | Knows about | How it gets data |
|---|---|---|
| `lsc_concepts` | Glossary: visit, call, PATI, PAPI, affiliations, medical insights, inquiries, managed events, off-label rules | Instructions only, no actions |
| `lsc_visits` | Upcoming and recent visits, and which HCPs to visit next | Apex `FieldVoiceVisitsAction` |
| `lsc_hcp_insights` | One HCP: PATI targeting, last and next visit, visit count, open inquiries, insights, plus affiliations (primary organization, hard vs soft, strength, who influences whom) and the stored provider summary (engagement, discussion points, recent changes) | Apex `FieldVoiceHcpBriefAction`, `FieldVoiceAffiliationsAction`, `FieldVoiceProviderSummaryAction` |
| `lsc_medical` | Inquiries and medical insights, each with the HCP they are for | Apex `FieldVoiceInquiriesAction`, `FieldVoiceInsightsAction` |
| `lsc_events` | Event plans: participants and spend limits | Apex `FieldVoiceEventPlanAction` |
| `lsc_records` | **Any other LSC object**: presentations, managed events and their sessions, participants, budgets and products, sample limits, products, experts, assessments, activity plans and goals, territories, and more | Apex `FieldVoiceRecordsAction` with `FieldVoiceLscCatalog` |
| `general_crm` | Any other CRM record lookup | `IdentifyRecordByName`, `QueryRecords` |
| `off_topic`, `ambiguous_question` | Guard rails | None |

## Architecture

```
Field_Voice_Agent  (AgentforceEmployeeAgent, modality voice)
└── agent_router  (start_agent, only routes via @utils.transition)
    ├── lsc_concepts       glossary, no actions
    ├── lsc_visits         GetVisits        → FieldVoiceVisitsAction
    ├── lsc_hcp_insights   GetHcpBrief      → FieldVoiceHcpBriefAction
    │                      GetAffiliations  → FieldVoiceAffiliationsAction
    ├── lsc_medical        GetInquiries     → FieldVoiceInquiriesAction
    │                      GetInsights      → FieldVoiceInsightsAction
    ├── lsc_events         GetEvents        → FieldVoiceEventPlanAction
    ├── lsc_records        GetRecords       → FieldVoiceRecordsAction ──▶ FieldVoiceLscCatalog
    ├── general_crm        IdentifyRecordByName, QueryRecords (standard actions)
    ├── ambiguous_question
    └── off_topic
```

Every subagent has a `back_to_router` transition so a conversation can change topic. Every data subagent carries the same "HOW TO SPEAK" instructions.

### Apex classes

| Class | Role |
|---|---|
| `FieldVoiceVisitsAction` | Upcoming, recent, and suggested visits (who to see next); fills PATI last/next visit gaps from `Visit` |
| `FieldVoiceHcpBriefAction` | One-HCP snapshot: PATI targeting, last and next visit, visit count, open inquiries, insights |
| `FieldVoiceAffiliationsAction` | Primary and other organizations, hard vs soft, strength, influence; HCO side lists affiliated HCPs |
| `FieldVoiceProviderSummaryAction` | Reads the stored `PrvdAccountTerritorySummary` JSON (the Provider Summary card) as spoken sentences; prefers the current user's row; optional part: engagement, discussion, changes |
| `FieldVoiceInquiriesAction` | Inquiries with the HCP they are for |
| `FieldVoiceInsightsAction` | Medical insights with the HCPs they relate to |
| `FieldVoiceEventPlanAction` | Event plans: participants and spend against limits |
| `FieldVoiceRecordsAction` | Generic query over any LSC object: match object, resolve HCP, build user-mode SOQL, speak the rows |
| `FieldVoiceLscCatalog` | Data only: per-object description, synonyms, speakable fields, HCP filter, headline lookup, child counts |
| `FieldVoiceHcpResolver` | Spoken name to Account: strips titles, any name order, SOSL plus fuzzy match, asks when ambiguous |
| `FieldVoiceSpeech` | Spoken dates ("next Tuesday"), lists, counts, truncation |
| `*Test` classes | `FieldVoiceActionsTest`, `FieldVoiceEventPlanActionTest`, `FieldVoiceRecordsActionTest` |

All actions are `with sharing`, use user-mode queries, and return a `summary` of spoken sentences (plus the matched `hcpName`). Request flow: user speech → router → subagent picks an action → action calls `FieldVoiceHcpResolver` (if a doctor was named) → query → `FieldVoiceSpeech` formatting → the model restates the summary in its own words.

The permission set `Field_Voice_Agent_Access` grants the agent and every class above. Add a class to it whenever you add an action.

### Adding a new LSC object

Add one `def(...)` entry to `FieldVoiceLscCatalog.all()`. No agent change is needed, because `lsc_records` already routes to the generic action.

## Built for voice

The first version returned raw records through the standard `QueryRecords` action. That gave text-shaped answers with no HCP names, because a query on `Inquiry` or `Visit` returns the `AccountId` but not the related account's name. The Apex actions fix both problems.

- **Spoken results.** Each action returns plain sentences, not lists or HTML. `FieldVoiceSpeech` turns dates into "tomorrow", "next Tuesday", "about three weeks ago" or "October 7th" (year only when it differs), and lists into "A, B, and C".
- **HCP names come back.** The actions query the related Account and include its name in every answer.
- **Name resolution.** `FieldVoiceHcpResolver` turns a spoken name into an Account. It drops titles ("Dr."), accepts either name order, uses search plus a fuzzy fallback, and forgives one misheard word when another word matches exactly ("Erin Morita" finds "Aaron Morita"). If two accounts fit it asks which one; if the match was approximate the agent says the name it matched.
- **Agent instructions** tell the model to talk in short sentences, never use bullets, tables or markdown, never read a full calendar date, lead with the answer, and give at most three items.
- **Security.** Actions use `with sharing` and user-mode queries, so reps only hear about records they can see.

- **Voice-friendly answers:** short sentences, top three items, no record IDs.
- **General FAQ** and *Answer Questions with Knowledge* are intentionally removed, per the setup guide.
- **Voice** is enabled with the `modality voice` block at the bottom of the script:

```yaml
modality voice:
    voice_id: "88afc8096500"
    outbound_speed: 1
    outbound_stability: 0.5
    outbound_similarity: 0.75
```

Tune the voice afterwards in Agent Builder → *Voice Settings*.

## One framework for every LSC object

Writing one action per object does not scale, and the agent used to say it knew nothing about presentations. `lsc_records` fixes that with a catalog plus a generic query action.

- **`FieldVoiceLscCatalog`** lists each LSC object with a plain-English description, the words people use for it ("deck", "slides", "attendees", "KOL", "call plan"), the handful of fields worth saying out loud, how it ties back to a doctor, which lookup gives the best headline when `Name` is an auto-number, and child counts (a managed event has N sessions and N participants). Adding an object is one entry.
- **`FieldVoiceRecordsAction`** takes what the user said (`objectName`), optional `hcpName`, `searchText`, `status`, `timeframe` (upcoming or past), and `mode` (list, count, or explain). It matches the object through the catalog, falls back to schema describe for objects that are not listed, resolves the doctor with `FieldVoiceHcpResolver`, and builds a user-mode dynamic query. Fields are checked for read access first, related names replace IDs, and dates and numbers are spoken.
- **Explain mode** answers "what is a presentation?" from the catalog description.
- Catalog coverage: presentations (and pages, access, content), managed events (sessions, participants, types, budgets, products), event plans, products, sample limits, product detailing, leave-behinds, account product info, experts, surveys, assessments, activity plans and goals, goal definitions, and territories.

## Mapping to the setup guide

| Guide step | Here |
|---|---|
| 1–4 Create SDO, enable Einstein and Agentforce | Manual prerequisite (Setup → *Einstein Setup*, *Agentforce Agents*) |
| 5 Employee Agent template + General CRM, remove General FAQ | Encoded in the `.agent` file |
| 6 Append voice script | `modality voice` block |
| 7 Save, Commit, Activate | `sf agent publish` + `sf agent activate` |
| 8 Permission set → Agent Access, assign users | `Field_Voice_Agent_Access` permission set + `sf org assign permset` |
| Mobile app login and voice | Manual (see below) |

## Lessons learned: building for voice

Building a conversational agent is different from building one that returns text.

- **Cater to the response channel.** You can write once and deploy everywhere, but the best experience comes from shaping the response for how it is consumed. This repo does it with voice-specific Apex actions and instructions. An alternative is a prompt template placed in front of the response that rewrites it for the channel, voice chat or agent chat.
- **Speak, don't format.** Bullets, tables, HTML, and emoji are noise when read aloud. Return plain sentences, lead with the answer, give at most three items, and end with one short follow-up question.
- **Say dates the way people do.** "Tomorrow", "next Tuesday", or "about three weeks ago" instead of "September 5th, 2026". Say the year only when it differs from this one.
- **IDs are not answers.** When a query returns an ID, a conversational agent has no name to say. Query the related record (for example `Account.Name`) and return the name. Standard `QueryRecords` returns `AccountId` without the related name.
- **Resolve spoken names yourself.** Transcripts drop titles, swap name order, and mishear first names. Match loosely, ask when two people fit, and say the name you matched so the user can correct it.
- **Some agents can't do voice.** Specialized agent types, such as the Search Agent, don't support voice.

## Deploy

```bash
# 1. Publish the Agent Script (creates Bot / BotVersion / GenAi metadata)
sf agent publish authoring-bundle --target-org <org> --api-name Field_Voice_Agent

# 2. Activate. Required after every publish; each publish creates a new inactive BotVersion.
sf agent activate --target-org <org> --api-name Field_Voice_Agent

# 3. Verify the newest version is Active
sf data query --target-org <org> --query \
  "SELECT Status, VersionNumber FROM BotVersion WHERE BotDefinition.DeveloperName='Field_Voice_Agent' ORDER BY VersionNumber"

# 4. Deploy the Apex action (run tests), then the permission set, and assign it.
#    Deploy the classes before publishing the agent, since the agent references the Apex class.
sf project deploy start --target-org <org> --source-dir force-app/main/default/classes \
  --test-level RunSpecifiedTests --tests FieldVoiceActionsTest --tests FieldVoiceEventPlanActionTest
sf project deploy start --target-org <org> \
  --source-dir force-app/main/default/permissionsets
sf org assign permset --target-org <org> --name Field_Voice_Agent_Access \
  --on-behalf-of <username>
```

Prerequisites: the Apex classes must be deployed before the agent is published. Einstein and Agentforce turned on in the org, and the org's standard CRM actions available (they are in current SDO orgs).

## Try it on mobile

1. Install the Salesforce Mobile app and set a password for your SDO user.
2. At login tap the gear → *Choose Connection* → *Production – Log in with username*.
3. Tap the Agentforce launcher, choose **Field Voice Agent**, then tap the Agentforce Voice circle in the input bar.
4. Try: "What's a visit?", "Who should I visit next?", "What does PATI stand for?", "Give me the PATI summary for Dr. <name>", "Who is this HCP affiliated with?", "Any open inquiries?", "Show recent medical insights", "Which managed events are coming up?", "Who is attending the Paris roundtable?", "What presentations do we have for Immunexis?", "Where does Dr. <name> work?", "Who influences Dr. <name>?", "What sample limits does Dr. <name> have?"

## Known limitations

- `general_crm` still uses the standard `QueryRecords` action. It is text-to-SOQL, adds an owner filter when the question says "my", and returns IDs rather than related names, so the agent prefers the Apex actions for anything LSC-specific.
- `EventPlan` is not visible to `QueryRecords`, hence the Apex events action.
- **Standard objects and fields only.** The agent uses no custom (`__c`) fields, so it works in any org with Life Sciences Cloud.
- Preview with `sf agent preview start --authoring-bundle Field_Voice_Agent --use-live-actions`; previewing the published employee agent by API name fails with "Invalid user ID".
- **General CRM is reduced.** The asset-library version has about 11 actions (update record, activities timeline, draft email, and others). The asset library isn't reachable from the CLI, so only the two actions with known schemas are wired. To get the rest, add *General CRM* from the asset library in Agent Builder and commit a new version.
- **Voice ID:** the setup guide's text and screenshot show different voice IDs; the text value is used.
- The permission set only grants agent access. Users still need normal object access to the records they query.
