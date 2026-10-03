@IsTest
private class FieldVoiceActionsTest {

    @IsTest
    static void speechFormatsRelativeDates() {
        System.assertEquals('today', FieldVoiceSpeech.spokenDate(Datetime.now()));
        System.assertEquals('tomorrow', FieldVoiceSpeech.spokenDate(Datetime.now().addDays(1)));
        System.assertEquals('yesterday', FieldVoiceSpeech.spokenDate(Datetime.now().addDays(-1)));
        System.assert(FieldVoiceSpeech.spokenDate(Datetime.now().addDays(4)).startsWith('on '));
        System.assert(FieldVoiceSpeech.spokenDate(Datetime.now().addDays(-21)).contains('weeks ago'));
        System.assertEquals('a, b, and c', FieldVoiceSpeech.joinNatural(new List<String>{'a', 'b', 'c'}));
        System.assertEquals('22nd', FieldVoiceSpeech.ordinal(22));
        System.assertEquals('11th', FieldVoiceSpeech.ordinal(11));
    }

    @IsTest
    static void resolverHandlesTitlesOrderAndMishearings() {
        Account a = new Account(Name = 'Aaron Morita');
        insert a;
        Test.setFixedSearchResults(new List<Id>{a.Id});
        System.assertEquals(a.Id, FieldVoiceHcpResolver.resolve('Dr. Aaron Morita').account.Id);
        System.assertEquals(a.Id, FieldVoiceHcpResolver.resolve('Morita, Aaron').account.Id);
        System.assertEquals(a.Id, FieldVoiceHcpResolver.resolve('morita').account.Id);
        FieldVoiceHcpResolver.Resolution fuzzy = FieldVoiceHcpResolver.resolve('Erin Morita');
        System.assertEquals(a.Id, fuzzy.account.Id);
        System.assertEquals(false, fuzzy.exact);
        System.assertEquals(null, FieldVoiceHcpResolver.resolve('Zzyzx Qqqq').account);
    }

    @IsTest
    static void resolverAsksWhenAmbiguous() {
        insert new List<Account>{ new Account(Name = 'Sam Lee'), new Account(Name = 'Sam Lee') };
        FieldVoiceHcpResolver.Resolution r = FieldVoiceHcpResolver.resolve('Sam Lee');
        System.assertEquals(null, r.account);
        System.assert(r.message.contains('Which one'));
    }

    @IsTest
    static void briefNamesTheHcp() {
        Account a = new Account(Name = 'Aaron Morita');
        insert a;
        FieldVoiceHcpBriefAction.Request req = new FieldVoiceHcpBriefAction.Request();
        req.hcpName = 'Aaron Morita';
        List<FieldVoiceHcpBriefAction.Result> out = FieldVoiceHcpBriefAction.getBrief(new List<FieldVoiceHcpBriefAction.Request>{req});
        System.assertEquals('Aaron Morita', out[0].hcpName);
        System.assert(out[0].summary.contains('Aaron Morita'));
    }

    @IsTest
    static void visitsInquiriesAndInsightsRespondInSentences() {
        Account a = new Account(Name = 'Aaron Morita');
        insert a;

        FieldVoiceVisitsAction.Request vr = new FieldVoiceVisitsAction.Request();
        vr.timeframe = 'upcoming';
        System.assert(!FieldVoiceVisitsAction.getVisits(new List<FieldVoiceVisitsAction.Request>{vr})[0].summary.contains('\n'));
        vr.timeframe = 'suggested';
        System.assertNotEquals(null, FieldVoiceVisitsAction.getVisits(new List<FieldVoiceVisitsAction.Request>{vr})[0].summary);
        vr.timeframe = 'recent';
        vr.hcpName = 'Aaron Morita';
        System.assert(FieldVoiceVisitsAction.getVisits(new List<FieldVoiceVisitsAction.Request>{vr})[0].summary.contains('Aaron Morita'));

        FieldVoiceInquiriesAction.Request ir = new FieldVoiceInquiriesAction.Request();
        ir.hcpName = 'Aaron Morita';
        ir.openOnly = true;
        System.assert(FieldVoiceInquiriesAction.getInquiries(new List<FieldVoiceInquiriesAction.Request>{ir})[0].summary.contains('Aaron Morita'));

        FieldVoiceInsightsAction.Request nr = new FieldVoiceInsightsAction.Request();
        nr.hcpName = 'Aaron Morita';
        System.assert(FieldVoiceInsightsAction.getInsights(new List<FieldVoiceInsightsAction.Request>{nr})[0].summary.contains('Aaron Morita'));
        nr.hcpName = null;
        nr.topOnly = true;
        System.assertNotEquals(null, FieldVoiceInsightsAction.getInsights(new List<FieldVoiceInsightsAction.Request>{nr})[0].summary);
    }

    @IsTest
    static void affiliationsSpeakPrimaryFirstAndCoverBothDirections() {
        Account doc = new Account(FirstName = 'Andrew', LastName = 'Kim', RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id);
        Account hospital = new Account(Name = 'UCSF Medical Center');
        Account clinic = new Account(Name = 'Pacific Oncology Associates');
        insert new List<Account>{doc, hospital, clinic};
        insert new List<ProviderAffiliation>{
            new ProviderAffiliation(AccountId = doc.Id, RelatedAccountId = hospital.Id, IsPrimary = true, IsActive = true, AffiliationType = 'Hard', Role = 'Attending'),
            new ProviderAffiliation(AccountId = doc.Id, RelatedAccountId = clinic.Id, IsActive = true, AffiliationType = 'Soft', Role = 'Consulting')
        };
        FieldVoiceAffiliationsAction.Request req = new FieldVoiceAffiliationsAction.Request();
        req.accountName = 'Andrew Kim';
        String out = FieldVoiceAffiliationsAction.getAffiliations(new List<FieldVoiceAffiliationsAction.Request>{req})[0].summary;
        System.assert(out.contains('primary one is UCSF Medical Center'), out);
        System.assert(out.contains('Pacific Oncology Associates'), out);
        req.accountName = 'UCSF Medical Center';
        out = FieldVoiceAffiliationsAction.getAffiliations(new List<FieldVoiceAffiliationsAction.Request>{req})[0].summary;
        System.assert(out.contains('Andrew Kim'), out);
    }
}
