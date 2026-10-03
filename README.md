# AgentForce Field Voice POC

A CLI-deployable **Agentforce Employee Agent with Agentforce Voice** for the Salesforce Mobile app. It reproduces the UI-based steps in the *Agentforce Voice – Field Voice – Employee Mobile Demo Setup Guide* as an Agent Script bundle, so the agent can be published to any SDO org with the `sf` CLI.

## What's in here

| Path | Purpose |
|---|---|
| `force-app/main/default/aiAuthoringBundles/Field_Voice_Agent/` | Agent Script (`.agent`) and bundle metadata |
| `force-app/main/default/permissionsets/Field_Voice_Agent_Access.permissionset-meta.xml` | Grants `agentAccesses` on the agent |
| `sfdx-project.json` | Source API version 67.0 |

## What the agent does

- **Type:** `AgentforceEmployeeAgent`
- **Router (`agent_router`)** sends each request to one of three subagents.
- **General CRM** finds and reads CRM records by voice, using two standard actions:
  - `IdentifyRecordByName` (`EmployeeCopilot__IdentifyRecordByName`)
  - `QueryRecords` (`EmployeeCopilot__QueryRecords`)
- **Off Topic** and **Ambiguous Question** are the template's guard-rail subagents.
- **General FAQ** and the *Answer Questions with Knowledge* action are intentionally removed, per the setup guide, to avoid confusing the voice agent.
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

# 4. Deploy the access permission set and assign it
sf project deploy start --target-org <org> \
  --source-dir force-app/main/default/permissionsets/Field_Voice_Agent_Access.permissionset-meta.xml
sf org assign permset --target-org <org> --name Field_Voice_Agent_Access \
  --on-behalf-of <username>
```

Prerequisites: Einstein and Agentforce turned on in the org, and the org's standard CRM actions available (they are in current SDO orgs).

## Try it on mobile

1. Install the Salesforce Mobile app and set a password for your SDO user.
2. At login tap the gear → *Choose Connection* → *Production – Log in with username*.
3. Tap the Agentforce launcher, choose **Field Voice Agent**, then tap the Agentforce Voice circle in the input bar.
4. Try: "Find the account Acme" or "Show my open opportunities created this week".

## Known limitations

- **General CRM is reduced.** The asset-library version has about 11 actions (update record, activities timeline, draft email, and others). The asset library isn't reachable from the CLI, so only the two actions with known schemas are wired. To get the rest, add *General CRM* from the asset library in Agent Builder and commit a new version.
- **Voice ID:** the setup guide's text and screenshot show different voice IDs; the text value is used.
- The permission set only grants agent access. Users still need normal object access to the records they query.
