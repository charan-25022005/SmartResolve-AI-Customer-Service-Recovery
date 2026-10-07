/**
 * @description Lightning UI Controller for the SmartResolve Recovery Hub.
 * Provides real-time case recovery intelligence, audit logs, and 1-click human approval.
 */
public with sharing class SmartResolveUIController {

    public class CaseRecoveryDetails {
        @AuraEnabled public Case caseRecord;
        @AuraEnabled public Complaint_Analysis__c complaintAnalysis;
        @AuraEnabled public List<Resolution_Action__c> resolutionActions;
        @AuraEnabled public List<Integration_Log__c> integrationLogs;
        @AuraEnabled public Boolean isApprovalPending;
    }

    @AuraEnabled(cacheable=true)
    public static CaseRecoveryDetails getCaseRecoveryDetails(Id caseId) {
        CaseRecoveryDetails details = new CaseRecoveryDetails();
        if (caseId == null) {
            return details;
        }

        List<Case> cases = [
            SELECT Id, CaseNumber, Subject, Description, Priority, Status, IsEscalated,
                   AI_Analysis_Status__c, AI_Priority__c, SLA_Risk__c, Customer_Impact__c,
                   Repeat_Complaint__c, Recommended_Action__c, Human_Approval_Required__c,
                   Resolution_Status__c, Contact.Name, Account.Name
            FROM Case
            WHERE Id = :caseId
            WITH USER_MODE
            LIMIT 1
        ];

        if (!cases.isEmpty()) {
            details.caseRecord = cases[0];
            details.isApprovalPending = cases[0].Human_Approval_Required__c;
        }

        List<Complaint_Analysis__c> analyses = [
            SELECT Id, Name, Sentiment__c, Issue_Type__c, Customer_Impact__c,
                   Repeat_Complaint__c, SLA_Risk__c, Recommended_Priority__c,
                   AI_Confidence__c, AI_Summary__c, Recommended_Action__c,
                   Analysis_Status__c, Analyzed_Date__c,
                   External_Order_Status__c, External_Payment_Status__c,
                   External_Delivery_Status__c, External_Warranty_Status__c
            FROM Complaint_Analysis__c
            WHERE Case__c = :caseId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!analyses.isEmpty()) {
            details.complaintAnalysis = analyses[0];
        }

        details.resolutionActions = [
            SELECT Id, Name, Action_Type__c, Action_Status__c, Recommended_By_AI__c,
                   Human_Approval_Required__c, Approved_By__r.Name, Action_Details__c,
                   Completed_Date__c, Failure_Reason__c
            FROM Resolution_Action__c
            WHERE Case__c = :caseId
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ];

        details.integrationLogs = [
            SELECT Id, Name, Integration_Type__c, Request_Status__c, External_Reference__c,
                   Response__c, Attempt_Number__c, Request_Date__c
            FROM Integration_Log__c
            WHERE Case__c = :caseId
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        return details;
    }

    @AuraEnabled
    public static void approveCaseRecovery(Id caseId) {
        if (caseId == null) {
            return;
        }
        ResolutionService.executeApprovedResolution(new Set<Id>{caseId});
    }

    @AuraEnabled
    public static void triggerAIEvaluation(Id caseId) {
        if (caseId == null) {
            return;
        }
        List<Case> cases = [
            SELECT Id, Subject, Description, CreatedDate, AccountId, ContactId
            FROM Case
            WHERE Id = :caseId
            WITH USER_MODE
        ];
        ComplaintAnalysisService.analyzeCases(cases);
        System.enqueueJob(new CustomerContextQueueable(new Set<Id>{caseId}));
    }
}
