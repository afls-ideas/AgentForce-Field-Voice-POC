@IsTest
private class FieldVoiceEventPlanActionTest {

    @IsTest
    static void returnsMatchingEventPlan() {
        insert new EventPlan(Name = 'Field Voice Test Summit', Status = 'Active', UsageType = 'ManagedEvent', StartDateTime = Datetime.now().addDays(10), EndDateTime = Datetime.now().addDays(11));

        FieldVoiceEventPlanAction.Request req = new FieldVoiceEventPlanAction.Request();
        req.eventName = 'Field Voice Test';
        req.status = 'Active';
        req.upcomingOnly = true;

        Test.startTest();
        List<FieldVoiceEventPlanAction.Result> results = FieldVoiceEventPlanAction.getEvents(new List<FieldVoiceEventPlanAction.Request>{ req });
        Test.stopTest();

        Assert.areEqual(1, results[0].eventCount);
        Assert.isTrue(results[0].summary.contains('Field Voice Test Summit'));
    }

    @IsTest
    static void reportsNoMatch() {
        FieldVoiceEventPlanAction.Request req = new FieldVoiceEventPlanAction.Request();
        req.eventName = 'No Such Event';

        List<FieldVoiceEventPlanAction.Result> results = FieldVoiceEventPlanAction.getEvents(new List<FieldVoiceEventPlanAction.Request>{ req });

        Assert.areEqual(0, results[0].eventCount);
        Assert.areEqual('No managed events matched.', results[0].summary);
    }
}
