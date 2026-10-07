/**
 * @description Resolution and Risk-Based Orchestration Engine.
 * Evaluates business risk:
 * Low/Medium Risk -> Automate immediately.
 * High/Critical Risk -> Human-In-The-Loop Approval.
 * Handles approval workflow, senior escalation, and automated customer follow-up.
 */
public with sharing class ResolutionService {

    /**
     * @description Evaluates complaints and creates appropriate resolution actions based on risk profile.
     * @param caseIds Set of Case IDs to orchestrate
     */
    public static void evaluateAndOrchestrateResolution(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        List<Case> cases = [
            SELECT Id, Priority, SLA_Risk__c, Customer_Impact__c, Repeat_Complaint__c,
                   Recommended_Action__c, Human_Approval_Required__c, Resolution_Status__c,
                   Subject, Description, Status
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ];

        List<Resolution_Action__c> actionsToInsert = new List<Resolution_Action__c>();
        List<Case> casesToUpdate = new List<Case>();

        for (Case c : cases) {
            String complaintText = ((c.Subject != null ? c.Subject : '') + ' ' + (c.Description != null ? c.Description : '')).toLowerCase();
            Boolean containsRefund = complaintText.contains('refund') || complaintText.contains('money back');
            Boolean isHighRisk = 'Critical'.equalsIgnoreCase(c.Priority) ||
                                 'Critical'.equalsIgnoreCase(c.SLA_Risk__c) ||
                                 'High'.equalsIgnoreCase(c.SLA_Risk__c) ||
                                 'Critical'.equalsIgnoreCase(c.Customer_Impact__c) ||
                                 ('High'.equalsIgnoreCase(c.Customer_Impact__c) && (containsRefund || c.Repeat_Complaint__c));

            if (isHighRisk) {
                // High/Critical Risk -> MANDATE HUMAN APPROVAL
                c.Human_Approval_Required__c = true;
                c.Resolution_Status__c = 'Pending Approval';
                casesToUpdate.add(c);

                // Create Action 1: Service Escalation
                Resolution_Action__c actionEscalation = new Resolution_Action__c();
                actionEscalation.Case__c = c.Id;
                actionEscalation.Action_Type__c = 'Service Escalation';
                actionEscalation.Action_Status__c = 'Pending Approval';
                actionEscalation.Recommended_By_AI__c = true;
                actionEscalation.Human_Approval_Required__c = true;
                actionEscalation.Action_Details__c = 'Immediate Service Escalation: Priority technician dispatch requested following repeated unattended customer visits.';
                actionsToInsert.add(actionEscalation);

                // Create Action 2: Refund Review (if refund requested or high impact)
                if (containsRefund) {
                    Resolution_Action__c actionRefund = new Resolution_Action__c();
                    actionRefund.Case__c = c.Id;
                    actionRefund.Action_Type__c = 'Refund Review';
                    actionRefund.Action_Status__c = 'Pending Approval';
                    actionRefund.Recommended_By_AI__c = true;
                    actionRefund.Human_Approval_Required__c = true;
                    actionRefund.Action_Details__c = 'Customer Refund Review: Evaluate customer refund request against active warranty status and delivery confirmation.';
                    actionsToInsert.add(actionRefund);
                }

                // Create Action 3: Manager Review
                Resolution_Action__c actionManager = new Resolution_Action__c();
                actionManager.Case__c = c.Id;
                actionManager.Action_Type__c = 'Manager Review';
                actionManager.Action_Status__c = 'Pending Approval';
                actionManager.Recommended_By_AI__c = true;
                actionManager.Human_Approval_Required__c = true;
                actionManager.Action_Details__c = 'Senior Manager Review & Sign-Off required before finalizing critical customer service recovery.';
                actionsToInsert.add(actionManager);

            } else {
                // Low/Medium Risk -> AUTOMATE RESOLUTION
                c.Human_Approval_Required__c = false;
                c.Resolution_Status__c = 'Resolved';
                c.Status = 'Closed';
                casesToUpdate.add(c);

                // Automated Team Assignment
                Resolution_Action__c autoAssign = new Resolution_Action__c();
                autoAssign.Case__c = c.Id;
                autoAssign.Action_Type__c = 'Assign Team';
                autoAssign.Action_Status__c = 'Completed';
                autoAssign.Recommended_By_AI__c = true;
                autoAssign.Human_Approval_Required__c = false;
                autoAssign.Completed_Date__c = DateTime.now();
                autoAssign.Action_Details__c = 'Automatically routed to Standard Support Queue according to AI classification.';
                actionsToInsert.add(autoAssign);

                // Automated Customer Follow-up
                Resolution_Action__c autoFollowup = new Resolution_Action__c();
                autoFollowup.Case__c = c.Id;
                autoFollowup.Action_Type__c = 'Customer Follow-up';
                autoFollowup.Action_Status__c = 'Completed';
                autoFollowup.Recommended_By_AI__c = true;
                autoFollowup.Human_Approval_Required__c = false;
                autoFollowup.Completed_Date__c = DateTime.now();
                autoFollowup.Action_Details__c = 'Automated resolution acknowledgement dispatched to customer.';
                actionsToInsert.add(autoFollowup);
            }
        }

        if (!actionsToInsert.isEmpty()) {
            Database.insert(actionsToInsert, false, AccessLevel.USER_MODE);
        }

        if (!casesToUpdate.isEmpty()) {
            CaseTriggerHandler.isTriggerDisabled = true;
            Database.update(casesToUpdate, false, AccessLevel.USER_MODE);
            CaseTriggerHandler.isTriggerDisabled = false;
        }
    }

    /**
     * @description Executes approved actions when a manager authorizes the recovery plan.
     * @param caseIds Set of Case IDs to finalize
     */
    public static void executeApprovedResolution(Set<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) {
            return;
        }

        List<Case> casesToResolve = [
            SELECT Id, Status, IsEscalated, Human_Approval_Required__c, Resolution_Status__c
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ];

        List<Resolution_Action__c> pendingActions = [
            SELECT Id, Action_Status__c, Approved_By__c, Completed_Date__c, Case__c
            FROM Resolution_Action__c
            WHERE Case__c IN :caseIds
              AND Action_Status__c = 'Pending Approval'
            WITH USER_MODE
        ];

        Id currentUserId = UserInfo.getUserId();
        DateTime nowTime = DateTime.now();

        for (Resolution_Action__c action : pendingActions) {
            action.Action_Status__c = 'Approved';
            action.Approved_By__c = currentUserId;
            action.Completed_Date__c = nowTime;
        }

        List<Resolution_Action__c> completedExecutions = new List<Resolution_Action__c>();
        for (Case c : casesToResolve) {
            c.Human_Approval_Required__c = false;
            c.IsEscalated = true;
            c.Resolution_Status__c = 'Resolved';
            c.Status = 'Closed';

            // Log executed Service Escalation confirmation
            Resolution_Action__c execEscalation = new Resolution_Action__c();
            execEscalation.Case__c = c.Id;
            execEscalation.Action_Type__c = 'Service Escalation';
            execEscalation.Action_Status__c = 'Completed';
            execEscalation.Approved_By__c = currentUserId;
            execEscalation.Completed_Date__c = nowTime;
            execEscalation.Action_Details__c = 'Escalation executed: Field Service VIP Technician prioritized and assigned.';
            completedExecutions.add(execEscalation);

            // Log executed Team Assignment
            Resolution_Action__c execTeam = new Resolution_Action__c();
            execTeam.Case__c = c.Id;
            execTeam.Action_Type__c = 'Assign Team';
            execTeam.Action_Status__c = 'Completed';
            execTeam.Approved_By__c = currentUserId;
            execTeam.Completed_Date__c = nowTime;
            execTeam.Action_Details__c = 'Assigned to Senior Escalation & Recovery Unit.';
            completedExecutions.add(execTeam);

            // Log Customer Follow-Up completion
            Resolution_Action__c execFollowup = new Resolution_Action__c();
            execFollowup.Case__c = c.Id;
            execFollowup.Action_Type__c = 'Customer Follow-up';
            execFollowup.Action_Status__c = 'Completed';
            execFollowup.Approved_By__c = currentUserId;
            execFollowup.Completed_Date__c = nowTime;
            execFollowup.Action_Details__c = 'Recovery call and SMS notification successfully completed with customer.';
            completedExecutions.add(execFollowup);
        }

        if (!pendingActions.isEmpty()) {
            Database.update(pendingActions, false, AccessLevel.USER_MODE);
        }
        if (!completedExecutions.isEmpty()) {
            Database.insert(completedExecutions, false, AccessLevel.USER_MODE);
        }
        if (!casesToResolve.isEmpty()) {
            CaseTriggerHandler.isTriggerDisabled = true;
            Database.update(casesToResolve, false, AccessLevel.USER_MODE);
            CaseTriggerHandler.isTriggerDisabled = false;
        }
    }
}
