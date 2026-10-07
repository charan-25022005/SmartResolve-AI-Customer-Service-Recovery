/**
 * @description Single thin trigger for Resolution_Action__c object.
 * Enforces: One Object -> One Trigger -> One Handler.
 */
trigger ResolutionActionTrigger on Resolution_Action__c (before update, after update) {
    ResolutionActionTriggerHandler handler = new ResolutionActionTriggerHandler();

    if (Trigger.isBefore && Trigger.isUpdate) {
        handler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }
}
