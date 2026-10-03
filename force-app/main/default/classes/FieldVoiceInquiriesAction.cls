/**
 * Spoken answers about inquiries, with the HCP each one is for.
 */
public with sharing class FieldVoiceInquiriesAction {

    public class Request {
        @InvocableVariable(label='HCP name' description='Optional. Limit to inquiries for one doctor or organization.')
        public String hcpName;
        @InvocableVariable(label='open only' description='True to leave out inquiries that are already responded to or closed.')
        public Boolean openOnly;
        @InvocableVariable(label='type' description='Optional. Medical Inquiry, Off-Label Question, Product Quality Complaint, or Adverse Event.')
        public String inquiryType;
    }

    public class Result {
        @InvocableVariable(label='summary' description='Facts written as plain spoken sentences. Say them in your own words.')
        public String summary;
        @InvocableVariable(label='hcpName' description='The HCP that was matched, if one was named.')
        public String hcpName;
    }

    @InvocableMethod(label='Field Voice Inquiries' description='Answers in spoken sentences about inquiries, including which HCP each is for, its type, priority, and status.')
    public static List<Result> getInquiries(List<Request> requests) {
        List<Result> results = new List<Result>();
        for (Request req : requests) {
            Result res = new Result();
            try {
                run(req, res);
            } catch (Exception e) {
                res.summary = 'Something went wrong while looking up inquiries.';
            }
            results.add(res);
        }
        return results;
    }

    private static void run(Request req, Result res) {
        Account acct = null;
        String lead = '';
        if (String.isNotBlank(req.hcpName)) {
            FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve(req.hcpName);
            if (r.account == null) { res.summary = r.message; return; }
            acct = r.account;
            res.hcpName = acct.Name;
            if (!r.exact) lead = 'I matched that to ' + acct.Name + '. ';
        }

        String whereClause = ' WHERE Id != null';
        Map<String, Object> binds = new Map<String, Object>();
        if (acct != null) { whereClause += ' AND AccountId = :acctId'; binds.put('acctId', acct.Id); }
        if (req.openOnly == true) whereClause += ' AND Status NOT IN (\'Responded\', \'Closed\', \'Cancelled\')';
        if (String.isNotBlank(req.inquiryType)) { whereClause += ' AND Type = :inqType'; binds.put('inqType', req.inquiryType); }

        Integer total = Database.countQueryWithBinds('SELECT COUNT() FROM Inquiry' + whereClause, binds, AccessLevel.USER_MODE);
        String scope = (req.openOnly == true ? 'open ' : '') + (String.isNotBlank(req.inquiryType) ? req.inquiryType.toLowerCase() + ' ' : '');
        String forWho = acct != null ? ' for ' + acct.Name : '';
        if (total == 0) {
            res.summary = lead + 'I do not see any ' + scope + 'inquiries' + forWho + '.';
            return;
        }

        List<Inquiry> rows = Database.queryWithBinds(
            'SELECT Type, Priority, Status, SubmittedDateTime, CreatedDate, Account.Name FROM Inquiry' + whereClause
            + ' ORDER BY CreatedDate DESC LIMIT 3', binds, AccessLevel.USER_MODE);

        List<String> parts = new List<String>();
        for (Inquiry i : rows) {
            String type = String.isNotBlank(i.Type) ? i.Type.toLowerCase() : 'inquiry';
            String who = acct == null && i.Account != null ? ' for ' + i.Account.Name : '';
            String pri = String.isNotBlank(i.Priority) ? ', ' + i.Priority.toLowerCase() + ' priority' : '';
            String status = String.isNotBlank(i.Status) ? ', ' + i.Status.toLowerCase() : '';
            Datetime whenText = i.SubmittedDateTime != null ? i.SubmittedDateTime : i.CreatedDate;
            parts.add('a ' + type + who + pri + status + ', from ' + FieldVoiceSpeech.spokenDate(whenText));
        }
        String head = total == 1 ? 'There is one ' + scope + 'inquiry' + forWho + ': '
            : 'There are ' + total + ' ' + scope + 'inquiries' + forWho + '. The most recent ' + (parts.size() == 1 ? 'is ' : 'are ');
        res.summary = lead + head + FieldVoiceSpeech.joinNatural(parts) + '.';
    }
}
