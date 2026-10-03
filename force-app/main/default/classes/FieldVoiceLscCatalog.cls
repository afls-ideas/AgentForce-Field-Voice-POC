/**
 * Catalog of Life Sciences Cloud objects the voice agent understands: what each one
 * is, the words people use for it, which fields matter when speaking about it, and
 * how it ties back to a doctor. FieldVoiceRecordsAction reads this to query any of
 * them dynamically. Objects not listed here are discovered at runtime from schema
 * describe (see FieldVoiceRecordsAction.discover), so the agent still copes.
 * Standard objects and fields only.
 */
public with sharing class FieldVoiceLscCatalog {

    public class ChildLink {
        public String objectName;
        public String lookupField;
        public String singular;
        public String plural;
    }

    public class Def {
        public String key;
        public String objectName;
        public String label;
        public String plural;
        public String description;
        public List<String> synonyms = new List<String>();
        public List<String> fields = new List<String>();
        public String nameField = 'Name';
        public String statusField;
        public String dateField;
        public String orderBy;
        // Lookup field whose related record name is the best headline for a row (used when Name is an auto-number).
        public String titleField;
        // Lookup fields whose related names are also searched by the search text.
        public List<String> searchVia = new List<String>();
        // SOQL condition that narrows this object to one doctor; uses the :hcpId bind. Null if not tied to a doctor.
        public String hcpFilter;
        public List<ChildLink> children = new List<ChildLink>();

        public Def syn(String csv) { synonyms.addAll(csv.split(',')); return this; }
        public Def flds(String csv) { fields.addAll(csv.split(',')); return this; }
        public Def status(String f) { statusField = f; return this; }
        public Def dated(String f) { dateField = f; return this; }
        public Def order(String o) { orderBy = o; return this; }
        public Def title(String f) { titleField = f; return this; }
        public Def via(String csv) { searchVia.addAll(csv.split(',')); return this; }
        public Def hcp(String cond) { hcpFilter = cond; return this; }
        public Def child(String obj, String lookup, String singular, String plural) {
            ChildLink c = new ChildLink();
            c.objectName = obj; c.lookupField = lookup; c.singular = singular; c.plural = plural;
            children.add(c);
            return this;
        }
    }

    private static List<Def> cache;

    private static Def def(String key, String objectName, String label, String plural, String description) {
        Def d = new Def();
        d.key = key; d.objectName = objectName; d.label = label; d.plural = plural; d.description = description;
        return d;
    }

    public static List<Def> all() {
        if (cache != null) {
            return cache;
        }
        cache = new List<Def>{
            def('presentation', 'Presentation', 'presentation', 'presentations',
                'A presentation is a digital detail aid, a slide deck of approved content that a rep shows an HCP during a visit. It has a status, a type such as zip or pdf, a version, and activation dates, and can be limited to specific accounts.')
                .syn('presentation,deck,slide deck,slides,detail aid,detailing content,sales aid,pitch,approved content,content')
                .flds('Status,Type,Version,ActivationDate,DeactivationDate,CanSendByEmail,IsPdfIncluded').status('Status').dated('ActivationDate')
                .hcp('Id IN (SELECT PresentationId FROM PresentationPartyAccess WHERE PartyId = :hcpId)')
                .child('PresentationPartyAccess', 'PresentationId', 'account with specific access', 'accounts with specific access'),
            def('presentation_page', 'PresentationPage', 'presentation page', 'presentation pages',
                'A presentation page is one slide or page inside a presentation. Pages can be mandatory, additional content, or regular.')
                .syn('presentation page,slide,page,mandatory page,mandatory slide')
                .flds('PageNumber,Type,Status,IsMandatory,IsAdditionalContent,ActivationDate').status('Status').order('PageNumber ASC'),
            def('presentation_access', 'PresentationPartyAccess', 'presentation access', 'presentation access records',
                'A presentation access record says a particular account, usually an HCP or organization, can use a presentation, with a role and effective dates.')
                .title('PresentationId')
                .syn('presentation access,presentation party access,who can see presentation,who can use presentation,presentation sharing,presentation assigned')
                .flds('PartyId,AccessRole,EffectiveStartDate,EffectiveEndDate').dated('EffectiveEndDate')
                .hcp('PartyId = :hcpId'),
            def('presentation_content', 'PresentationContent', 'presentation content', 'presentation content items',
                'Presentation content is the actual file or text behind a presentation, optionally targeted to an account, a user, or a territory, for a date range.')
                .title('ReferenceRecordId')
                .syn('presentation content,content item,content file,content assigned to doctor')
                .flds('TerritoryId,EffectiveStartDate,EffectiveEndDate').dated('EffectiveStartDate')
                .hcp('ReferenceRecordId = :hcpId'),
            def('managed_event', 'MngEvent', 'managed event', 'managed events',
                'A managed event is a compliant company event such as a speaker program, roundtable, advisory board, or congress. It has a type, status moving from draft through approval to execute and concluded, a mode of in person, virtual or hybrid, sessions, invited participants, products, and budgets.')
                .syn('managed event,event,speaker program,program,roundtable,advisory board,congress,dinner meeting,webinar,symposium,meeting,conference')
                .flds('Status,Mode,StartDateTime,EndDateTime,EstimatedParticipantCount,MngEventTypeId,EstimatedBudget,TotalActualExpenseAmount').status('Status').dated('StartDateTime')
                .hcp('Id IN (SELECT MngEventId FROM MngEventParticipant WHERE ParticipantId = :hcpId)')
                .child('MngEventSession', 'MngEventId', 'session', 'sessions')
                .child('MngEventParticipant', 'MngEventId', 'participant', 'participants')
                .child('MngEventProduct', 'MngEventId', 'product', 'products'),
            def('event_session', 'MngEventSession', 'event session', 'event sessions',
                'An event session is one scheduled talk or segment within a managed event, with its own start, end, mode, and location.')
                .via('MngEventId')
                .syn('event session,session,talk,agenda item,breakout')
                .flds('MngEventId,StartDateTime,EndDateTime,Mode,AccountId').dated('StartDateTime')
                .hcp('AccountId = :hcpId'),
            def('event_participant', 'MngEventParticipant', 'event participant', 'event participants',
                'An event participant is a doctor or other person invited to a managed event, with their response to the invitation, whether they attended, and how.')
                .title('ParticipantId').via('MngEventId,ParticipantId')
                .syn('event participant,participant,attendee,attendees,invitee,invitees,guest,guests,rsvp,who is attending,who attended,who is invited,invitation')
                .flds('MngEventId,ParticipantType,ParticipantResponse,AttendanceStatus,AttendanceMode,InvitationSentStatus').status('AttendanceStatus').dated('InvitationSentDateTime')
                .hcp('ParticipantId = :hcpId'),
            def('event_type', 'MngEventType', 'event type', 'event types',
                'An event type is a template category for managed events, like a dinner program or advisory board.')
                .syn('event type,event category,event template')
                .flds('Category,Subcategory,TargetTemplate'),
            def('event_budget', 'MngEventBudget', 'event budget', 'event budgets',
                'An event budget shows how much money was allocated to a managed event and how much has been estimated and actually spent.')
                .title('MngEventId')
                .syn('event budget,event spend,event cost,event expenses,budget,spend')
                .flds('AllocatedAmount,TotalEstimatedExpenseAmount,TotalActualExpenseAmount'),
            def('event_product', 'MngEventProduct', 'event product', 'event products',
                'An event product links a product to a managed event, meaning the product is being discussed there.')
                .title('MngEventId').via('ProductReferenceRecordId')
                .syn('event product,products at event,products for event,product discussed at event')
                .flds('ProductReferenceRecordId'),
            def('event_plan', 'EventPlan', 'event plan', 'event plans',
                'An event plan is the planning record behind a managed event, with its category, status, dates, and owner.')
                .syn('event plan,event planning,event plans')
                .flds('Status,Category,UsageType,StartDateTime,EndDateTime,PrimaryOwnerId').status('Status').dated('StartDateTime'),
            def('product', 'LifeSciMarketableProduct', 'product', 'products',
                'A marketable product is a drug or brand the company promotes, organized by therapeutic area, with sampling rules and launch dates. Products can roll up to brands and indications.')
                .syn('product,drug,brand,medication,medicine,therapy,marketable product,indication,competitor product,competitor')
                .flds('Type,TherapeuticArea,TherapeuticClass,IsActive,LaunchDate,Manufacturer,IsCompetitorProduct').dated('LaunchDate'),
            def('sample_limit', 'ProviderSampleLimit', 'sample limit', 'sample limits',
                'A sample limit is a compliance rule that caps which product samples a specific HCP may receive.')
                .title('AccountId').via('ProductId')
                .syn('sample limit,sample limits,sampling limit,sampling rule,sample rule,sample restriction,can i drop samples,samples')
                .flds('ProductId').hcp('AccountId = :hcpId'),
            def('product_detailing', 'ProviderVisitProdDetailing', 'product detailing', 'product detailings',
                'A product detailing record says which product was, or will be, discussed in a visit, in what priority order, and whether it was off label.')
                .title('ProductId').via('ProviderVisitAccountId')
                .syn('product detailing,detailing,product detail,products discussed,products detailed,what did i detail,what was discussed,detailed')
                .flds('ProviderVisitAccountId,Priority,IsOffLabel,ProviderVisitStatus,PrvdVisitPlannedStartTime').status('ProviderVisitStatus').dated('PrvdVisitPlannedStartTime')
                .hcp('ProviderVisitAccountId = :hcpId'),
            def('leave_behind', 'ProviderVisitMarketingItem', 'leave-behind', 'leave-behinds',
                'A leave-behind is a marketing item or promotional material physically left with an HCP during a visit.')
                .title('ProductId')
                .syn('leave behind,leave-behind,leave behinds,marketing item,promotional item,brochure,collateral,handout')
                .flds('Quantity,IsSignatureCaptured')
                .hcp('VisitId IN (SELECT Id FROM Visit WHERE AccountId = :hcpId)'),
            def('account_product', 'ProviderAcctProductInfo', 'account product info', 'account product info records',
                'Account product information holds notes about a product for a specific HCP or organization in a territory, such as prescribing context.')
                .title('AccountId').via('ProductId')
                .syn('account product info,account product information,product info for doctor,papi,product notes,prescribing notes')
                .flds('ProductId,TerritoryId,Description').hcp('AccountId = :hcpId'),
            def('expert', 'Expert', 'expert', 'experts',
                'An expert is an HCP identified as a key opinion leader or advisor, with an evaluation status and a primary organization. Experts are used for advisory boards and speaker programs.')
                .title('AccountId')
                .syn('expert,kol,key opinion leader,thought leader,advisor,speaker,advisory')
                .flds('PrimaryOrganizationId,Type,Status,EvaluationStatus,IsActive').status('Status').hcp('AccountId = :hcpId'),
            def('survey', 'Survey', 'survey', 'surveys',
                'A survey is a questionnaire template that can be given to HCPs, for example to assess preferences or needs.')
                .syn('survey,questionnaire,survey template,form')
                .flds('SurveyType,Description,TotalVersionsCount'),
            def('assessment', 'Assessment', 'assessment', 'assessments',
                'An assessment is a completed or in-progress questionnaire about an HCP, with a status, score, and rating.')
                .title('AccountId')
                .syn('assessment,assessments,questionnaire response,survey response,needs assessment,completed survey')
                .flds('Type,AssessmentStatus,AssessmentRating,Score,MaximumScore,EffectiveDateTime,CompletedDateTime').status('AssessmentStatus').dated('EffectiveDateTime')
                .hcp('AccountId = :hcpId'),
            def('activity_plan', 'ActivityPlan', 'activity plan', 'activity plans',
                'An activity plan is a time-boxed plan, for a rep or a team, that sets goals for how many visits and other activities to do against which accounts. Managers review and adjust it.')
                .syn('activity plan,call plan,visit plan,plan,target plan,goal plan,frequency plan')
                .flds('Type,Status,UsageType,AssigneeDueDate,ReviewerDueDate,IsActive').status('Status').dated('AssigneeDueDate')
                .child('ProviderActivityGoal', 'ActivityPlanId', 'account goal', 'account goals'),
            def('activity_goal', 'ProviderActivityGoal', 'activity goal', 'activity goals',
                'An activity goal is how many activities, usually visits, a rep should complete for one HCP in an activity plan, with how many are done and scheduled so far and the attainment percentage.')
                .title('AccountId').via('ActivityPlanId')
                .syn('activity goal,call goal,visit goal,account goal,attainment,goal attainment,how am i doing,progress against plan,call frequency')
                .flds('ActivityPlanId,OverallGoal,TotalActualActivityValue,TotalScheduledActivityValue,ActivityAttainmentPercentage').hcp('AccountId = :hcpId'),
            def('goal_definition', 'GoalDefinition', 'goal definition', 'goal definitions',
                'A goal definition describes a kind of goal reps are measured on, such as visit frequency or sample distribution, with its status, category, and scope.')
                .syn('goal definition,goal,goals,kpi,metric,target type')
                .flds('Status,Category,Type,UsageType,ScopeType,Description').status('Status'),
            def('territory', 'Territory2', 'territory', 'territories',
                'A territory is a sales geography or segment that reps are assigned to. HCPs are linked to territories through their account territory information, and territories roll up to parent territories.')
                .syn('territory,territories,region,patch,geography,district,area,team')
                .flds('Description,ParentTerritory2Id')
        };
        return cache;
    }
}
