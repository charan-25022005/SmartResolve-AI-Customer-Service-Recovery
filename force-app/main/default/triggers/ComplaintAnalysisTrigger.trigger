/**
 * @description Single thin trigger for Complaint_Analysis__c object.
 * Enforces: One Object -> One Trigger -> One Handler.
 */
trigger ComplaintAnalysisTrigger on Complaint_Analysis__c (before insert, after insert, after update) {
    ComplaintAnalysisTriggerHandler handler = new ComplaintAnalysisTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.handleBeforeInsert(Trigger.new);
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
