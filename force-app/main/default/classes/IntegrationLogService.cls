/**
 * @description Service for managing auditable external integration logs.
 * All outbound API calls (Order, Payment, Delivery) are logged here.
 * Bulkified, secure, and governor-limit safe.
 */
public with sharing class IntegrationLogService {
    
    /**
     * @description Creates a structured integration log record.
     * @param caseId Parent Case record Id
     * @param integrationType System type ('Order', 'Payment', 'Delivery')
     * @param status Outcome status ('Success', 'Failed', 'Retry', 'Pending')
     * @param externalRef Reference identifier from external system
     * @param response Payload or message received
     * @param errorMessage Error details if failed
     * @param attemptNumber Sequence attempt count
     * @return Integration_Log__c The populated record (not yet inserted)
     */
    public static Integration_Log__c createLogRecord(
        Id caseId,
        String integrationType,
        String status,
        String externalRef,
        String response,
        String errorMessage,
        Integer attemptNumber
    ) {
        Integration_Log__c log = new Integration_Log__c();
        log.Case__c = caseId;
        log.Integration_Type__c = integrationType;
        log.Request_Status__c = status;
        log.External_Reference__c = externalRef != null && externalRef.length() > 255 ? externalRef.substring(0, 255) : externalRef;
        log.Response__c = response != null && response.length() > 32768 ? response.substring(0, 32768) : response;
        log.Error_Message__c = errorMessage != null && errorMessage.length() > 32768 ? errorMessage.substring(0, 32768) : errorMessage;
        log.Attempt_Number__c = attemptNumber != null ? attemptNumber : 1;
        log.Request_Date__c = DateTime.now();
        log.Response_Date__c = DateTime.now();
        return log;
    }

    /**
     * @description Bulk inserts a list of integration log records safely.
     * @param logs List of Integration_Log__c to insert
     */
    public static void insertLogs(List<Integration_Log__c> logs) {
        if (logs == null || logs.isEmpty()) {
            return;
        }
        try {
            Database.insert(logs, false, AccessLevel.USER_MODE);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, 'IntegrationLogService: Failed to save logs: ' + ex.getMessage());
        }
    }
}
