/**
 * @description Invocable Apex Action for Salesforce Flow integration.
 * Allows Flow builders to trigger the end-to-end SmartResolve AI recovery pipeline declaratively.
 */
public with sharing class SmartResolveInvocableAction {

    @InvocableMethod(
        label='SmartResolve: Run AI Recovery Pipeline'
        description='Executes AI Complaint Analysis, History Evaluation, and Async External Verification.'
        category='SmartResolve AI'
    )
    public static List<FlowOutput> runRecoveryPipeline(List<FlowInput> inputs) {
        List<FlowOutput> outputs = new List<FlowOutput>();
        if (inputs == null || inputs.isEmpty()) {
            return outputs;
        }

        Set<Id> caseIds = new Set<Id>();
        for (FlowInput inp : inputs) {
            if (inp.caseId != null) {
                caseIds.add(inp.caseId);
            }
        }

        if (!caseIds.isEmpty()) {
            List<Case> casesToProcess = [
                SELECT Id, Subject, Description, CreatedDate, AccountId, ContactId
                FROM Case
                WHERE Id IN :caseIds
                WITH USER_MODE
            ];

            // 1. Synchronous AI Analysis
            Map<Id, Complaint_Analysis__c> analysisMap = ComplaintAnalysisService.analyzeCases(casesToProcess);

            // 2. Asynchronous Context Retrieval
            if (!System.isQueueable() && !System.isFuture()) {
                System.enqueueJob(new CustomerContextQueueable(caseIds));
            }

            for (FlowInput inp : inputs) {
                FlowOutput out = new FlowOutput();
                out.caseId = inp.caseId;
                out.isSuccess = true;
                if (analysisMap.containsKey(inp.caseId)) {
                    Complaint_Analysis__c ca = analysisMap.get(inp.caseId);
                    out.recommendedPriority = ca.Recommended_Priority__c;
                    out.slaRisk = ca.SLA_Risk__c;
                    out.sentiment = ca.Sentiment__c;
                }
                outputs.add(out);
            }
        }

        return outputs;
    }

    public class FlowInput {
        @InvocableVariable(label='Case Record ID' required=true)
        public Id caseId;
    }

    public class FlowOutput {
        @InvocableVariable(label='Case Record ID')
        public Id caseId;

        @InvocableVariable(label='Is Success')
        public Boolean isSuccess;

        @InvocableVariable(label='Recommended Priority')
        public String recommendedPriority;

        @InvocableVariable(label='SLA Risk')
        public String slaRisk;

        @InvocableVariable(label='Sentiment')
        public String sentiment;
    }
}
