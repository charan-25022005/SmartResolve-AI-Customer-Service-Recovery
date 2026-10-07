/**
 * @description Trigger Handler for Complaint_Analysis__c object.
 * Enforces: One Object -> One Trigger -> One Handler.
 * Bulkified, governor-limit safe, and secure.
 */
public with sharing class ComplaintAnalysisTriggerHandler {

    public static Boolean isTriggerDisabled = false;

    public void handleBeforeInsert(List<Complaint_Analysis__c> newAnalyses) {
        if (isTriggerDisabled || newAnalyses == null || newAnalyses.isEmpty()) {
            return;
        }
        for (Complaint_Analysis__c ca : newAnalyses) {
            if (ca.Analyzed_Date__c == null) {
                ca.Analyzed_Date__c = DateTime.now();
            }
        }
    }

    public void handleAfterInsert(List<Complaint_Analysis__c> newAnalyses) {
        if (isTriggerDisabled || newAnalyses == null || newAnalyses.isEmpty()) {
            return;
        }
        syncAnalysisToCase(newAnalyses);
    }

    public void handleAfterUpdate(List<Complaint_Analysis__c> newAnalyses, Map<Id, Complaint_Analysis__c> oldMap) {
        if (isTriggerDisabled || newAnalyses == null || newAnalyses.isEmpty()) {
            return;
        }
        syncAnalysisToCase(newAnalyses);
    }

    private void syncAnalysisToCase(List<Complaint_Analysis__c> analyses) {
        Map<Id, Case> casesToUpdate = new Map<Id, Case>();
        for (Complaint_Analysis__c ca : analyses) {
            if (ca.Case__c != null) {
                Case c = new Case(Id = ca.Case__c);
                if (ca.Recommended_Priority__c != null) {
                    c.AI_Priority__c = ca.Recommended_Priority__c;
                }
                if (ca.SLA_Risk__c != null) {
                    c.SLA_Risk__c = ca.SLA_Risk__c;
                }
                if (ca.Customer_Impact__c != null) {
                    c.Customer_Impact__c = ca.Customer_Impact__c;
                }
                if (ca.Recommended_Action__c != null) {
                    c.Recommended_Action__c = ca.Recommended_Action__c;
                }
                casesToUpdate.put(c.Id, c);
            }
        }

        if (!casesToUpdate.isEmpty()) {
            CaseTriggerHandler.isTriggerDisabled = true;
            Database.update(casesToUpdate.values(), false, AccessLevel.USER_MODE);
            CaseTriggerHandler.isTriggerDisabled = false;
        }
    }
}
