# AgentForce Field Voice POC

A CLI-deployable **Agentforce Employee Agent with Agentforce Voice** for the Salesforce Mobile app. It reproduces the UI-based steps in the *Agentforce Voice – Field Voice – Employee Mobile Demo Setup Guide* as an Agent Script bundle, so the agent can be published to any SDO org with the `sf` CLI.

## What's in here

| Path | Purpose |
|---|---|
| `force-app/main/default/aiAuthoringBundles/Field_Voice_Agent/` | Agent Script (`.agent`) and bundle metadata |
| `force-app/main/default/classes/FieldVoiceEventPlanAction*.cls` | Apex invocable action for managed events, plus tests |
| `force-app/main/default/permissionsets/Field_Voice_Agent_Access.permissionset-meta.xml` | Grants agent access and the Apex class |
| `sfdx-project.json` | Source API version 67.0 |

## What the agent does

- **Type:** `AgentforceEmployeeAgent`, a voice assistant that knows Life Sciences Cloud (LSC).
- **Router (`agent_router`)** sends each request to one of these subagents:

| Subagent | Knows about | How it gets data |
|---|---|---|
| `lsc_concepts` | Glossary: visit, call, PATI, PAPI, advocacy, affiliations, medical insights, inquiries, managed events, off-label rules | Instructions only, no actions |
| `lsc_visits` | Visit and ProviderVisit (status, channel), detailing, discussions, leave-behinds, sample requests | `IdentifyRecordByName`, `QueryRecords` |
| `lsc_hcp_insights` | HCP profile: PATI (targeting, last/next visit, YTD count), PAPI (advocacy, cluster, prescribing patterns), ProviderAffiliation | `IdentifyRecordByName`, `QueryRecords` |
| `lsc_medical` | Medical insights and inquiries (medical inquiry, off-label question, product complaint, adverse event) | `IdentifyRecordByName`, `QueryRecords` |
| `lsc_events` | Managed events: EventPlan with participants, products, spend limits | Apex action `FieldVoiceEventPlanAction` |
| `general_crm` | Any other CRM record lookup | `IdentifyRecordByName`, `QueryRecords` |
| `off_topic`, `ambiguous_question` | Guard rails | None |

- **Standard actions** are `EmployeeCopilot__IdentifyRecordByName` and `EmployeeCopilot__QueryRecords`.
- **Managed events use Apex** because `QueryRecords` (text-to-SOQL) does not include `EventPlan` in its schema. `FieldVoiceEventPlanAction` runs in user mode (`with sharing`, `AccessLevel.USER_MODE`), filters by name, status, or upcoming only, and returns a short spoken summary with participant counts and spend.
- **Guard rails:** no off-label promotion; adverse events and product complaints are pointed to the company reporting process.
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
  --test-level RunSpecifiedTests --tests FieldVoiceEventPlanActionTest
sf project deploy start --target-org <org> \
  --source-dir force-app/main/default/permissionsets
sf org assign permset --target-org <org> --name Field_Voice_Agent_Access \
  --on-behalf-of <username>
```

Prerequisites: Einstein and Agentforce turned on in the org, and the org's standard CRM actions available (they are in current SDO orgs).

## Try it on mobile

1. Install the Salesforce Mobile app and set a password for your SDO user.
2. At login tap the gear → *Choose Connection* → *Production – Log in with username*.
3. Tap the Agentforce launcher, choose **Field Voice Agent**, then tap the Agentforce Voice circle in the input bar.
4. Try: "What's a visit?", "What does PATI stand for?", "Give me the PATI summary for Dr. <name>", "Who is this HCP affiliated with?", "Any open inquiries?", "Show recent medical insights", "Which managed events are active?"

## Known limitations

- **`QueryRecords` is text-to-SOQL.** It adds an owner filter when the question says "my", so the agent is told not to say "my" unless the user did. `IdentifyRecordByName` can return a Contact ID for person accounts, so the agent only accepts Account IDs (starting `001`).
- **`EventPlan` is not visible to `QueryRecords`**, hence the Apex action.
- The custom fields `MYM_Advocacy__c`, `MYM_Cluster__c`, `MYM_PrescribingPatterns__c`, and `Advocacy_Score__c` come from the demo org's data model and may not exist in other orgs; adjust the schema notes in the `.agent` file.
- Preview with `sf agent preview start --authoring-bundle Field_Voice_Agent --use-live-actions`; previewing the published employee agent by API name fails with "Invalid user ID".
- **General CRM is reduced.** The asset-library version has about 11 actions (update record, activities timeline, draft email, and others). The asset library isn't reachable from the CLI, so only the two actions with known schemas are wired. To get the rest, add *General CRM* from the asset library in Agent Builder and commit a new version.
- **Voice ID:** the setup guide's text and screenshot show different voice IDs; the text value is used.
- The permission set only grants agent access. Users still need normal object access to the records they query.
