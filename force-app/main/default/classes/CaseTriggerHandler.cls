/**
 * @description Trigger Handler for Case object.
 * Enforces: One Object -> One Trigger -> One Handler architecture.
 * Controls recursion, bulkification, and triggers AI analysis and Async Queueable retrieval.
 */
public with sharing class CaseTriggerHandler {

    public static Boolean isTriggerDisabled = false;
    public static Set<Id> processedCaseIds = new Set<Id>();

    public void handleAfterInsert(List<Case> newCases) {
        if (isTriggerDisabled || newCases == null || newCases.isEmpty()) {
            return;
        }

        List<Case> casesToAnalyze = new List<Case>();
        Set<Id> caseIdsForQueueable = new Set<Id>();

        for (Case c : newCases) {
            if (!processedCaseIds.contains(c.Id) && 
                (String.isNotBlank(c.Description) || String.isNotBlank(c.Subject))) {
                casesToAnalyze.add(c);
                processedCaseIds.add(c.Id);
                caseIdsForQueueable.add(c.Id);
            }
        }

        if (!casesToAnalyze.isEmpty()) {
            // 1. Run AI complaint analysis synchronously
            ComplaintAnalysisService.analyzeCases(casesToAnalyze);

            // 2. Dispatch async customer context retrieval via Queueable Apex
            if (!caseIdsForQueueable.isEmpty() && !System.isQueueable() && !System.isFuture()) {
                System.enqueueJob(new CustomerContextQueueable(caseIdsForQueueable));
            }
        }
    }

    public void handleAfterUpdate(List<Case> newCases, Map<Id, Case> oldCaseMap) {
        if (isTriggerDisabled || newCases == null || newCases.isEmpty()) {
            return;
        }

        List<Case> casesToAnalyze = new List<Case>();
        Set<Id> caseIdsForQueueable = new Set<Id>();

        for (Case c : newCases) {
            Case oldCase = oldCaseMap.get(c.Id);
            // Re-trigger if complaint text changed significantly and not already analyzed
            Boolean textChanged = (c.Description != oldCase.Description && String.isNotBlank(c.Description));
            Boolean needsAnalysis = 'Pending'.equalsIgnoreCase(c.AI_Analysis_Status__c) || String.isBlank(c.AI_Analysis_Status__c);

            if (!processedCaseIds.contains(c.Id) && (textChanged || needsAnalysis) && String.isNotBlank(c.Description)) {
                casesToAnalyze.add(c);
                processedCaseIds.add(c.Id);
                caseIdsForQueueable.add(c.Id);
            }
        }

        if (!casesToAnalyze.isEmpty()) {
            ComplaintAnalysisService.analyzeCases(casesToAnalyze);

            if (!caseIdsForQueueable.isEmpty() && !System.isQueueable() && !System.isFuture()) {
                System.enqueueJob(new CustomerContextQueueable(caseIdsForQueueable));
            }
        }
    }
}
