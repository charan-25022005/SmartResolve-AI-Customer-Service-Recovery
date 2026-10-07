/**
 * @description Exposes a REST API endpoint for external omnichannel complaint intake.
 * URL Mapping: /services/apexrest/smartresolve/v1/complaints
 * Automatically triggers AI analysis and the full SmartResolve orchestration pipeline.
 */
@RestResource(urlMapping='/smartresolve/v1/complaints')
global with sharing class SmartResolveRestService {

    global class ComplaintRequest {
        public String accountId;
        public String contactId;
        public String subject;
        public String description;
    }

    global class ComplaintResponse {
        public Boolean success;
        public String caseId;
        public String caseNumber;
        public String priority;
        public String sentiment;
        public String issueType;
        public String slaRisk;
        public String recommendedAction;
        public Boolean humanApprovalRequired;
        public String message;
    }

    @HttpPost
    global static ComplaintResponse ingestComplaint(ComplaintRequest request) {
        ComplaintResponse resp = new ComplaintResponse();

        if (request == null || String.isBlank(request.description)) {
            resp.success = false;
            resp.message = 'Complaint description is mandatory.';
            RestContext.response.statusCode = 400;
            return resp;
        }

        try {
            Case newCase = new Case(
                AccountId = String.isNotBlank(request.accountId) ? (Id) request.accountId : null,
                ContactId = String.isNotBlank(request.contactId) ? (Id) request.contactId : null,
                Subject = String.isNotBlank(request.subject) ? request.subject : 'External Complaint Intake',
                Description = request.description,
                Status = 'New',
                Origin = 'Web'
            );

            insert as user newCase;

            // Retrieve updated case record populated by trigger pipeline
            Case createdCase = [
                SELECT Id, CaseNumber, Priority, AI_Priority__c, SLA_Risk__c,
                       Recommended_Action__c, Human_Approval_Required__c
                FROM Case
                WHERE Id = :newCase.Id
                WITH USER_MODE
            ];

            List<Complaint_Analysis__c> analyses = [
                SELECT Sentiment__c, Issue_Type__c
                FROM Complaint_Analysis__c
                WHERE Case__c = :newCase.Id
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];

            resp.success = true;
            resp.caseId = createdCase.Id;
            resp.caseNumber = createdCase.CaseNumber;
            resp.priority = createdCase.Priority;
            resp.slaRisk = createdCase.SLA_Risk__c;
            resp.recommendedAction = createdCase.Recommended_Action__c;
            resp.humanApprovalRequired = createdCase.Human_Approval_Required__c;

            if (!analyses.isEmpty()) {
                resp.sentiment = analyses[0].Sentiment__c;
                resp.issueType = analyses[0].Issue_Type__c;
            }

            resp.message = 'Complaint ingested and processed by SmartResolve AI.';
            RestContext.response.statusCode = 201;

        } catch (Exception ex) {
            resp.success = false;
            resp.message = 'Error processing complaint: ' + ex.getMessage();
            RestContext.response.statusCode = 500;
        }

        return resp;
    }
}
