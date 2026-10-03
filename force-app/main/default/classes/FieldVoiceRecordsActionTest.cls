@IsTest
private class FieldVoiceRecordsActionTest {

    private static FieldVoiceRecordsAction.Result ask(String objectName, String hcpName, String searchText, String mode) {
        FieldVoiceRecordsAction.Request req = new FieldVoiceRecordsAction.Request();
        req.objectName = objectName;
        req.hcpName = hcpName;
        req.searchText = searchText;
        req.mode = mode;
        return FieldVoiceRecordsAction.getRecords(new List<FieldVoiceRecordsAction.Request>{req})[0];
    }

    @IsTest
    static void catalogCoversPresentationsAndManagedEvents() {
        Set<String> keys = new Set<String>();
        for (FieldVoiceLscCatalog.Def d : FieldVoiceLscCatalog.all()) {
            keys.add(d.key);
        }
        System.assert(keys.contains('presentation'));
        System.assert(keys.contains('managed_event'));
        System.assert(keys.contains('event_participant'));
    }

    @IsTest
    static void presentationsAreFoundByTheWordsPeopleUse() {
        insert new Presentation(Name = 'Immunexis Overview', Status = 'Active');
        FieldVoiceRecordsAction.Result res = ask('slide decks', null, 'Immunexis', null);
        System.assertEquals('presentation', res.objectLabel);
        System.assert(res.summary.contains('Immunexis Overview'), res.summary);
    }

    @IsTest
    static void explainReturnsTheDescription() {
        FieldVoiceRecordsAction.Result res = ask('what is a presentation', null, null, 'explain');
        System.assert(res.summary.contains('detail aid'), res.summary);
    }

    @IsTest
    static void managedEventsCanBeCounted() {
        MngEventType type = new MngEventType(Name = 'Roundtable');
        insert type;
        insert new MngEvent(Name = 'Paris Roundtable', MngEventTypeId = type.Id, Status = 'Draft', StartDateTime = Datetime.now().addDays(10), EndDateTime = Datetime.now().addDays(10).addHours(2));
        FieldVoiceRecordsAction.Result res = ask('managed events', null, 'Paris', 'count');
        System.assert(res.summary.contains('1 managed event'), res.summary);
    }

    @IsTest
    static void unknownThingsGetAHelpfulAnswer() {
        FieldVoiceRecordsAction.Result res = ask('bananas', null, null, null);
        System.assert(res.summary.contains('presentations'), res.summary);
    }

    @IsTest
    static void doctorNameIsResolvedForDoctorScopedObjects() {
        Account doc = new Account(FirstName = 'Zelda', LastName = 'Testerson', RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1].Id);
        insert doc;
        FieldVoiceRecordsAction.Result res = ask('sample limits', 'Zelda Testerson', null, null);
        System.assertEquals('Zelda Testerson', res.hcpName);
    }
}
