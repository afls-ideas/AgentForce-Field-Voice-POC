public with sharing class FieldVoiceEventPlanAction {

    public class Request {
        @InvocableVariable(description='Optional. Part of the managed event name to search for.')
        public String eventName;
        @InvocableVariable(description='Optional. Draft, Active, or Archived.')
        public String status;
        @InvocableVariable(description='Optional. True to return only events that have not started yet.')
        public Boolean upcomingOnly;
    }

    public class Result {
        @InvocableVariable(description='Spoken-friendly summary of the matching managed events.')
        public String summary;
        @InvocableVariable(description='Number of matching managed events returned.')
        public Integer eventCount;
    }

    @InvocableMethod(label='Get Managed Events' description='Looks up managed events (event plans) with status, dates, owner, participant count, and spend against limits.' callout=false)
    public static List<Result> getEvents(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            results.add(lookup(req));
        }
        return results;
    }

    private static Result lookup(Request req) {
        List<String> conditions = new List<String>();
        Map<String, Object> binds = new Map<String, Object>();
        if (!String.isBlank(req.eventName)) {
            conditions.add('Name LIKE :nameLike');
            binds.put('nameLike', '%' + req.eventName.trim() + '%');
        }
        if (!String.isBlank(req.status)) {
            conditions.add('Status = :statusValue');
            binds.put('statusValue', req.status.trim());
        }
        if (req.upcomingOnly == true) {
            conditions.add('StartDateTime > :nowTime');
            binds.put('nowTime', Datetime.now());
        }
        String soql = 'SELECT Id, Name, Status, Category, StartDateTime, EndDateTime, PrimaryOwner.Name FROM EventPlan'
            + (conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND '))
            + ' ORDER BY StartDateTime ASC NULLS LAST LIMIT 5';
        List<EventPlan> plans = Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

        Result res = new Result();
        res.eventCount = plans.size();
        if (plans.isEmpty()) {
            res.summary = 'No managed events matched.';
            return res;
        }

        Map<Id, Integer> participantCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT EventPlanId planId, COUNT(Id) cnt
            FROM EventPlanParticipant
            WHERE EventPlanId IN :plans
            WITH USER_MODE
            GROUP BY EventPlanId
        ]) {
            participantCounts.put((Id) ar.get('planId'), (Integer) ar.get('cnt'));
        }

        Map<Id, Decimal> spend = new Map<Id, Decimal>();
        Map<Id, Decimal> limits = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT EventPlanId planId, SUM(CurrentTotalSpendAmount) spent, SUM(MaxSpendAmtLimit) cap
            FROM EventPlanProduct
            WHERE EventPlanId IN :plans
            WITH USER_MODE
            GROUP BY EventPlanId
        ]) {
            spend.put((Id) ar.get('planId'), (Decimal) ar.get('spent'));
            limits.put((Id) ar.get('planId'), (Decimal) ar.get('cap'));
        }

        List<String> lines = new List<String>();
        for (EventPlan p : plans) {
            String line = p.Name + ', status ' + p.Status;
            if (p.Category != null) {
                line += ', category ' + p.Category;
            }
            if (p.StartDateTime != null) {
                line += ', starts ' + p.StartDateTime.format('MMM d, yyyy');
            }
            if (p.EndDateTime != null) {
                line += ', ends ' + p.EndDateTime.format('MMM d, yyyy');
            }
            if (p.PrimaryOwner != null) {
                line += ', owner ' + p.PrimaryOwner.Name;
            }
            line += ', participants ' + (participantCounts.containsKey(p.Id) ? participantCounts.get(p.Id) : 0);
            if (limits.get(p.Id) != null) {
                line += ', spend ' + (spend.get(p.Id) == null ? 0 : spend.get(p.Id)) + ' of ' + limits.get(p.Id) + ' limit';
            }
            lines.add(line);
        }
        res.summary = String.join(lines, '. ');
        return res;
    }
}
