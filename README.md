# AgentForce Field Voice POC

A CLI-deployable **Agentforce Employee Agent with Agentforce Voice** for the Salesforce Mobile app. It reproduces the UI-based steps in the *Agentforce Voice – Field Voice – Employee Mobile Demo Setup Guide* as an Agent Script bundle, so the agent can be published to any SDO org with the `sf` CLI.

## What's in here

| Path | Purpose |
|---|---|
| `force-app/main/default/aiAuthoringBundles/Field_Voice_Agent/` | Agent Script (`.agent`) and bundle metadata |
| `force-app/main/default/classes/FieldVoice*.cls` | Apex actions that return spoken answers, the HCP name resolver, the speech formatter, and tests |
| `force-app/main/default/permissionsets/Field_Voice_Agent_Access.permissionset-meta.xml` | Grants agent access and the Apex class |
| `sfdx-project.json` | Source API version 67.0 |

## What the agent does

- **Type:** `AgentforceEmployeeAgent`, a voice assistant that knows Life Sciences Cloud (LSC).
- **Router (`agent_router`)** sends each request to one of these subagents:

| Subagent | Knows about | How it gets data |
|---|---|---|
| `lsc_concepts` | Glossary: visit, call, PATI, PAPI, affiliations, medical insights, inquiries, managed events, off-label rules | Instructions only, no actions |
| `lsc_visits` | Upcoming and recent visits, and which HCPs to visit next | Apex `FieldVoiceVisitsAction` |
| `lsc_hcp_insights` | One HCP: PATI targeting, last and next visit, visit count, affiliations, open inquiries, insights | Apex `FieldVoiceHcpBriefAction` |
| `lsc_medical` | Inquiries and medical insights, each with the HCP they are for | Apex `FieldVoiceInquiriesAction`, `FieldVoiceInsightsAction` |
| `lsc_events` | Managed events: EventPlan with participants and spend limits | Apex `FieldVoiceEventPlanAction` |
| `general_crm` | Any other CRM record lookup | `IdentifyRecordByName`, `QueryRecords` |
| `off_topic`, `ambiguous_question` | Guard rails | None |

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

## Mapping to the setup guide

| Guide step | Here |
|---|---|
| 1–4 Create SDO, enable Einstein and Agentforce | Manual prerequisite (Setup → *Einstein Setup*, *Agentforce Agents*) |
| 5 Employee Agent template + General CRM, remove General FAQ | Encoded in the `.agent` file |
| 6 Append voice script | `modality voice` block |
| 7 Save, Commit, Activate | `sf agent publish` + `sf agent activate` |
| 8 Permission set → Agent Access, assign users | `Field_Voice_Agent_Access` permission set + `sf org assign permset` |
| Mobile app login and voice | Manual (see below) |

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
4. Try: "What's a visit?", "Who should I visit next?", "What does PATI stand for?", "Give me the PATI summary for Dr. <name>", "Who is this HCP affiliated with?", "Any open inquiries?", "Show recent medical insights", "Which managed events are active?"

## Known limitations

- `general_crm` still uses the standard `QueryRecords` action. It is text-to-SOQL, adds an owner filter when the question says "my", and returns IDs rather than related names, so the agent prefers the Apex actions for anything LSC-specific.
- `EventPlan` is not visible to `QueryRecords`, hence the Apex events action.
- **Standard objects and fields only.** The agent uses no custom (`__c`) fields, so it works in any org with Life Sciences Cloud.
- Preview with `sf agent preview start --authoring-bundle Field_Voice_Agent --use-live-actions`; previewing the published employee agent by API name fails with "Invalid user ID".
- **General CRM is reduced.** The asset-library version has about 11 actions (update record, activities timeline, draft email, and others). The asset library isn't reachable from the CLI, so only the two actions with known schemas are wired. To get the rest, add *General CRM* from the asset library in Agent Builder and commit a new version.
- **Voice ID:** the setup guide's text and screenshot show different voice IDs; the text value is used.
- The permission set only grants agent access. Users still need normal object access to the records they query.
