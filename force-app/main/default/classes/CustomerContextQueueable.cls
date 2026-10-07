/**
 * @description Asynchronous Queueable Apex job for retrieving customer context.
 * Performs external callouts (Order, Payment, Delivery) asynchronously to prevent
 * blocking the initial user transaction.
 * Audits all interactions via Integration_Log__c and triggers resolution orchestration.
 */
public with sharing class CustomerContextQueueable implements Queueable, Database.AllowsCallouts {

    private Set<Id> caseIds;

    public CustomerContextQueueable(Set<Id> caseIds) {
        this.caseIds = caseIds;
    }

    public void execute(QueueableContext context) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
        Map<Id, Complaint_Analysis__c> analysisUpdates = new Map<Id, Complaint_Analysis__c>();

        // Query existing complaint analyses for these cases
        Map<Id, Complaint_Analysis__c> caseToAnalysis = new Map<Id, Complaint_Analysis__c>();
        for (Complaint_Analysis__c ca : [
            SELECT Id, Case__c, External_Order_Status__c, External_Payment_Status__c,
                   External_Delivery_Status__c, External_Warranty_Status__c
            FROM Complaint_Analysis__c
            WHERE Case__c IN :caseIds
            WITH USER_MODE
        ]) {
            caseToAnalysis.put(ca.Case__c, ca);
        }

        for (Id caseId : caseIds) {
            // 1. Verify Order Context
            OrderIntegrationService.OrderResult orderRes = OrderIntegrationService.verifyOrder(caseId);
            if (orderRes.logRecord != null) {
                logsToInsert.add(orderRes.logRecord);
            }

            // 2. Verify Payment Context
            PaymentIntegrationService.PaymentResult payRes = PaymentIntegrationService.verifyPayment(caseId);
            if (payRes.logRecord != null) {
                logsToInsert.add(payRes.logRecord);
            }

            // 3. Verify Delivery Context
            DeliveryIntegrationService.DeliveryResult delivRes = DeliveryIntegrationService.verifyDelivery(caseId);
            if (delivRes.logRecord != null) {
                logsToInsert.add(delivRes.logRecord);
            }

            // Update external context on Complaint Analysis
            if (caseToAnalysis.containsKey(caseId)) {
                Complaint_Analysis__c ca = caseToAnalysis.get(caseId);
                ca.External_Order_Status__c = orderRes.orderStatus != null ? orderRes.orderStatus : 'Delivered';
                ca.External_Payment_Status__c = payRes.paymentStatus != null ? payRes.paymentStatus : 'Paid';
                ca.External_Delivery_Status__c = delivRes.deliveryStatus != null ? delivRes.deliveryStatus : 'Completed';
                ca.External_Warranty_Status__c = orderRes.warrantyStatus != null ? orderRes.warrantyStatus : 'Active';
                analysisUpdates.put(ca.Id, ca);
            }
        }

        // Bulk insert integration logs
        if (!logsToInsert.isEmpty()) {
            IntegrationLogService.insertLogs(logsToInsert);
        }

        // Bulk update Complaint Analyses
        if (!analysisUpdates.isEmpty()) {
            Database.update(analysisUpdates.values(), false, AccessLevel.USER_MODE);
        }

        // Continue pipeline: evaluate and orchestrate resolution actions
        ResolutionService.evaluateAndOrchestrateResolution(caseIds);
    }
}
