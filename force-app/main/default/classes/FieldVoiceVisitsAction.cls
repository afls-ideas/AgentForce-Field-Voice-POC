/**
 * Spoken answers about visits: what is coming up, what happened recently, or
 * which HCPs the rep should see next.
 */
public with sharing class FieldVoiceVisitsAction {

    public class Request {
        @InvocableVariable(label='timeframe' description='upcoming for planned visits, recent for completed visits, or suggested for which HCPs to visit next. Defaults to upcoming.')
        public String timeframe;
        @InvocableVariable(label='HCP name' description='Optional. Limit the answer to one doctor or organization.')
        public String hcpName;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='hcpName' description='The HCP that was matched, if one was named.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice Visits' description='Answers in spoken sentences about upcoming visits, recent visits, or which HCPs to visit next. Includes HCP names.')
    public static List<Result> getVisits(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                run(req, res);
            } catch (Exception e) {
                res.summary = 'Something went wrong while looking up visits.';
            }
            results.add(res);
        }
        return results;
    }

    private static void run(Request req, Result res) {
        String mode = String.isBlank(req.timeframe) ? 'upcoming' : req.timeframe.toLowerCase();
        Account acct = null;
        String lead = '';
        if (String.isNotBlank(req.hcpName)) {
            FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.hcpName);
            if (r.account == null) { res.summary = r.message; return; }
            acct = r.account;
            res.hcpName = acct.Name;
            if (!r.exact) lead = 'I matched that to ' + acct.Name + '. ';
        }

        if (mode.startsWith('sugg')) {
            res.summary = lead + suggest(acct);
        } else if (mode.startsWith('rec') || mode.startsWith('past') || mode.startsWith('last')) {
            res.summary = lead + recent(acct);
        } else {
            String up = upcoming(acct);
            res.summary = lead + (up != null ? up : 'There are no planned visits' + (acct != null ? ' for ' + acct.Name : ' on your schedule') + '.'
                + (acct == null ? ' ' + suggest(null) : ''));
        }
    }

    private static String upcoming(Account acct) {
        Id me = UserInfo.getUserId();
        String soql = 'SELECT Account.Name, PlannedVisitStartTime FROM Visit WHERE Status = \'Planned\' AND PlannedVisitStartTime >= :now'
            + (acct != null ? ' AND AccountId = :acctId' : ' AND OwnerId = :me')
            + ' ORDER BY PlannedVisitStartTime ASC LIMIT 4';
        Datetime now = Datetime.now();
        Id acctId = acct != null ? acct.Id : null;
        List<Visit> visits = Database.queryWithBinds(soql, new Map<String, Object>{'now' => now, 'acctId' => acctId, 'me' => me}, AccessLevel.USER_MODE);
        if (visits.isEmpty()) return null;
        List<String> parts = new List<String>();
        for (Visit v : visits) {
            String who = v.Account != null ? v.Account.Name : 'an unnamed account';
            parts.add(acct != null ? FieldVoiceSpeech.spokenDateTime(v.PlannedVisitStartTime)
                : who + ' ' + FieldVoiceSpeech.spokenDateTime(v.PlannedVisitStartTime));
        }
        if (acct != null) {
            return 'The next ' + (visits.size() == 1 ? 'visit with ' : 'visits with ') + acct.Name + (visits.size() == 1 ? ' is ' : ' are ') + FieldVoiceSpeech.joinNatural(parts) + '.';
        }
        return 'Your next ' + (visits.size() == 1 ? 'visit is ' : 'visits are ') + FieldVoiceSpeech.joinNatural(parts) + '.';
    }

    private static String recent(Account acct) {
        Id me = UserInfo.getUserId();
        String soql = 'SELECT Account.Name, ActualVisitStartTime FROM Visit WHERE Status = \'Completed\' AND ActualVisitStartTime != null'
            + (acct != null ? ' AND AccountId = :acctId' : ' AND OwnerId = :me')
            + ' ORDER BY ActualVisitStartTime DESC LIMIT 4';
        Id acctId = acct != null ? acct.Id : null;
        List<Visit> visits = Database.queryWithBinds(soql, new Map<String, Object>{'acctId' => acctId, 'me' => me}, AccessLevel.USER_MODE);
        if (visits.isEmpty()) return 'I do not see any completed visits' + (acct != null ? ' for ' + acct.Name : '') + '.';
        List<String> parts = new List<String>();
        for (Visit v : visits) {
            String whenText = FieldVoiceSpeech.spokenDate(v.ActualVisitStartTime);
            parts.add(acct != null ? whenText : (v.Account != null ? v.Account.Name : 'an unnamed account') + ' ' + whenText);
        }
        return (acct != null ? 'The last visits with ' + acct.Name + ' were ' : 'Your most recent visits were ') + FieldVoiceSpeech.joinNatural(parts) + '.';
    }

    private class Candidate {
        String name;
        Datetime lastSeen;
        Datetime nextPlanned;
    }

    /** Targeted HCPs in the rep's territories: soonest planned visit first, then the ones not seen for the longest. */
    private static String suggest(Account acct) {
        List<ProviderAcctTerritoryInfo> rows = [
            SELECT AccountId, Account.Name, LastProviderVisitDate, NextProviderVisitDate
            FROM ProviderAcctTerritoryInfo
            WHERE IsActive = true AND IsTargetedAccount = true AND AccountId != null
            ORDER BY LastProviderVisitDate ASC NULLS FIRST
            LIMIT 50
        ];
        Datetime now = Datetime.now();
        Set<Id> acctIds = new Set<Id>();
        for (ProviderAcctTerritoryInfo p : rows) acctIds.add(p.AccountId);
        // The PATI dates are often blank, so fill the gaps from the visits themselves.
        Map<Id, Datetime> lastSeen = new Map<Id, Datetime>();
        for (AggregateResult ar : [
            SELECT AccountId a, MAX(ActualVisitStartTime) t FROM Visit
            WHERE AccountId IN :acctIds AND Status = 'Completed' GROUP BY AccountId
        ]) {
            lastSeen.put((Id) ar.get('a'), (Datetime) ar.get('t'));
        }
        Map<Id, Datetime> nextPlanned = new Map<Id, Datetime>();
        for (AggregateResult ar : [
            SELECT AccountId a, MIN(PlannedVisitStartTime) t FROM Visit
            WHERE AccountId IN :acctIds AND Status = 'Planned' AND PlannedVisitStartTime >= :now GROUP BY AccountId
        ]) {
            nextPlanned.put((Id) ar.get('a'), (Datetime) ar.get('t'));
        }

        List<Candidate> planned = new List<Candidate>();
        List<Candidate> overdue = new List<Candidate>();
        Set<Id> seen = new Set<Id>();
        for (ProviderAcctTerritoryInfo p : rows) {
            if (!seen.add(p.AccountId)) continue;
            Candidate c = new Candidate();
            c.name = p.Account.Name;
            c.lastSeen = lastSeen.containsKey(p.AccountId) ? lastSeen.get(p.AccountId) : p.LastProviderVisitDate;
            c.nextPlanned = nextPlanned.containsKey(p.AccountId) ? nextPlanned.get(p.AccountId)
                : (p.NextProviderVisitDate != null && p.NextProviderVisitDate >= now ? p.NextProviderVisitDate : null);
            if (c.nextPlanned != null) planned.add(c); else overdue.add(c);
        }
        planned.sort(new ByNextVisit());
        overdue.sort(new ByLastVisit());

        List<String> parts = new List<String>();
        for (Candidate c : planned) {
            if (parts.size() >= 3) break;
            parts.add(c.name + ', planned ' + FieldVoiceSpeech.spokenDate(c.nextPlanned));
        }
        for (Candidate c : overdue) {
            if (parts.size() >= 3) break;
            parts.add(c.name + (c.lastSeen == null ? ', who has no visit on record' : ', last seen ' + FieldVoiceSpeech.spokenDate(c.lastSeen)));
        }
        if (parts.isEmpty()) return 'I do not see any targeted HCPs in your territories.';
        return 'The HCPs to focus on are ' + FieldVoiceSpeech.joinNatural(parts) + '.';
    }

    private class ByLastVisit implements System.Comparator<Candidate> {
        public Integer compare(Candidate a, Candidate b) {
            if (a.lastSeen == null && b.lastSeen == null) return 0;
            if (a.lastSeen == null) return -1;
            if (b.lastSeen == null) return 1;
            return a.lastSeen < b.lastSeen ? -1 : (a.lastSeen > b.lastSeen ? 1 : 0);
        }
    }

    private class ByNextVisit implements System.Comparator<Candidate> {
        public Integer compare(Candidate a, Candidate b) {
            return a.nextPlanned < b.nextPlanned ? -1 : (a.nextPlanned > b.nextPlanned ? 1 : 0);
        }
    }
}
