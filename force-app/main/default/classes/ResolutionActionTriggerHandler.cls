/**
 * @description Trigger Handler for Resolution_Action__c object.
 * Enforces: One Object -> One Trigger -> One Handler.
 * Detects human approval events and drives automated escalation and case resolution.
 * Bulkified, governor-limit safe, and secure.
 */
public with sharing class ResolutionActionTriggerHandler {

    public static Boolean isTriggerDisabled = false;

    public void handleBeforeUpdate(List<Resolution_Action__c> newActions, Map<Id, Resolution_Action__c> oldMap) {
        if (isTriggerDisabled || newActions == null || newActions.isEmpty()) {
            return;
        }

        Id currentUserId = UserInfo.getUserId();
        DateTime nowTime = DateTime.now();

        for (Resolution_Action__c action : newActions) {
            Resolution_Action__c oldAction = oldMap.get(action.Id);
            // When action status transitioned to Approved
            if ('Approved'.equalsIgnoreCase(action.Action_Status__c) && !'Approved'.equalsIgnoreCase(oldAction.Action_Status__c)) {
                if (action.Approved_By__c == null) {
                    action.Approved_By__c = currentUserId;
                }
                if (action.Completed_Date__c == null) {
                    action.Completed_Date__c = nowTime;
                }
            }
        }
    }

    public void handleAfterUpdate(List<Resolution_Action__c> newActions, Map<Id, Resolution_Action__c> oldMap) {
        if (isTriggerDisabled || newActions == null || newActions.isEmpty()) {
            return;
        }

        Set<Id> casesWithApprovedActions = new Set<Id>();

        for (Resolution_Action__c action : newActions) {
            Resolution_Action__c oldAction = oldMap.get(action.Id);
            if ('Approved'.equalsIgnoreCase(action.Action_Status__c) && !'Approved'.equalsIgnoreCase(oldAction.Action_Status__c)) {
                if (action.Case__c != null) {
                    casesWithApprovedActions.add(action.Case__c);
                }
            }
        }

        if (!casesWithApprovedActions.isEmpty()) {
            // Orchestrate post-approval escalation and recovery completion
            ResolutionService.executeApprovedResolution(casesWithApprovedActions);
        }
    }
}
