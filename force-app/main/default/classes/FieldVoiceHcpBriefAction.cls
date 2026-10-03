/**
 * Spoken snapshot of one HCP: territory targeting, last and next visit,
 * affiliations, and open inquiries and medical insights.
 */
public with sharing class FieldVoiceHcpBriefAction {

    public class Request {
        @InvocableVariable(label='HCP name' description='The name of the doctor or organization as the user said it. Titles like Dr are fine.' required=true)
        public String hcpName;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts about the HCP written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='hcpName' description='The full name of the HCP that was matched. Empty if no single HCP was found.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice HCP Brief' description='Gives a spoken snapshot of one healthcare professional or organization: targeting, last and next visit, affiliations, open inquiries, and medical insights.')
    public static List<Result> getBrief(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.hcpName);
                if (r.account == null) {
                    res.summary = r.message;
                } else {
                    res.hcpName = r.account.Name;
                    res.summary = (r.exact ? '' : 'I matched that to ' + r.account.Name + '. ') + build(r.account);
                }
            } catch (Exception e) {
                res.summary = 'Something went wrong while looking that up.';
            }
            results.add(res);
        }
        return results;
    }

    private static String build(Account a) {
        List<String> s = new List<String>();

        List<ProviderAcctTerritoryInfo> patis = [
            SELECT IsTargetedAccount, LastProviderVisitDate, NextProviderVisitDate,
                   NextProviderVisitObjective, YearToDatePrvdVisitCount, Territory2.Name
            FROM ProviderAcctTerritoryInfo
            WHERE AccountId = :a.Id AND IsActive = true
            ORDER BY IsTargetedAccount DESC, LastModifiedDate DESC
            LIMIT 1
        ];
        ProviderAcctTerritoryInfo pati = patis.isEmpty() ? null : patis[0];

        if (pati != null) {
            String terr = pati.Territory2 != null ? ' in the ' + pati.Territory2.Name + ' territory' : '';
            s.add(a.Name + (pati.IsTargetedAccount ? ' is a targeted account' : ' is not a targeted account') + terr + '.');
        } else {
            s.add('I do not see a territory assignment for ' + a.Name + '.');
        }

        List<Visit> last = [
            SELECT ActualVisitStartTime FROM Visit
            WHERE AccountId = :a.Id AND Status = 'Completed' AND ActualVisitStartTime != null
            ORDER BY ActualVisitStartTime DESC LIMIT 1
        ];
        Datetime lastAt = !last.isEmpty() ? last[0].ActualVisitStartTime : (pati != null ? pati.LastProviderVisitDate : null);
        s.add(lastAt != null ? 'The last visit was ' + FieldVoiceSpeech.spokenDate(lastAt) + '.' : 'There is no completed visit on record.');

        List<Visit> next = [
            SELECT PlannedVisitStartTime FROM Visit
            WHERE AccountId = :a.Id AND Status = 'Planned' AND PlannedVisitStartTime >= :Datetime.now()
            ORDER BY PlannedVisitStartTime ASC LIMIT 1
        ];
        Datetime nextAt = !next.isEmpty() ? next[0].PlannedVisitStartTime
            : (pati != null && pati.NextProviderVisitDate != null && pati.NextProviderVisitDate >= Datetime.now() ? pati.NextProviderVisitDate : null);
        if (nextAt != null) {
            String obj = pati != null && String.isNotBlank(pati.NextProviderVisitObjective)
                ? ' The objective is ' + FieldVoiceSpeech.shorten(pati.NextProviderVisitObjective, 160) + '.' : '';
            s.add('The next visit is ' + FieldVoiceSpeech.spokenDateTime(nextAt) + '.' + obj);
        } else {
            s.add('Nothing is scheduled yet.');
        }

        if (pati != null && pati.YearToDatePrvdVisitCount != null) {
            Integer n = (Integer) pati.YearToDatePrvdVisitCount;
            s.add('That makes ' + FieldVoiceSpeech.count(n, 'visit', 'visits') + ' so far this year.');
        }

        List<String> affs = new List<String>();
        for (ProviderAffiliation pa : [
            SELECT RelatedAccountName FROM ProviderAffiliation
            WHERE AccountId = :a.Id AND IsActive = true AND RelatedAccountName != null
            ORDER BY IsPrimary DESC, LastModifiedDate DESC LIMIT 3
        ]) {
            affs.add(pa.RelatedAccountName);
        }
        if (!affs.isEmpty()) s.add('They are affiliated with ' + FieldVoiceSpeech.joinNatural(affs) + '.');

        Integer openInquiries = [
            SELECT COUNT() FROM Inquiry
            WHERE AccountId = :a.Id AND Status NOT IN ('Responded', 'Closed', 'Cancelled')
        ];
        Integer insights = [SELECT COUNT() FROM MedicalInsightAccount WHERE AccountId = :a.Id];
        if (openInquiries > 0) s.add('There ' + (openInquiries == 1 ? 'is one open inquiry.' : 'are ' + openInquiries + ' open inquiries.'));
        if (insights > 0) s.add(FieldVoiceSpeech.count(insights, 'medical insight mentions', 'medical insights mention') + ' them.');

        return String.join(s, ' ');
    }
}
