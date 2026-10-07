/**
 * @description Single thin trigger for Case object.
 * Enforces: One Object -> One Trigger -> One Handler.
 */
trigger CaseTrigger on Case (after insert, after update) {
    CaseTriggerHandler handler = new CaseTriggerHandler();

    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            handler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            handler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
