/**
 * @description Customer Context and History intelligence service.
 * Performs bulkified analysis of customer case history, previous escalations,
 * and unresolved complaints to identify repeat issues.
 * Adheres strictly to Governor Limits (No SOQL in loops).
 */
public with sharing class CustomerContextService {

    public class CustomerHistorySummary {
        public Integer previousComplaintsCount = 0;
        public Integer previousEscalationsCount = 0;
        public Integer openCasesCount = 0;
        public Boolean isRepeatComplaint = false;
        public String historyNotes = '';
    }

    /**
     * @description Bulk evaluates customer history for a collection of Cases.
     * @param cases List of Case records to evaluate
     * @return Map<Id, CustomerHistorySummary> Mapping Case ID to customer history summary
     */
    public static Map<Id, CustomerHistorySummary> evaluateCustomerHistory(List<Case> cases) {
        Map<Id, CustomerHistorySummary> resultMap = new Map<Id, CustomerHistorySummary>();
        if (cases == null || cases.isEmpty()) {
            return resultMap;
        }

        Set<Id> currentCaseIds = new Set<Id>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> contactIds = new Set<Id>();

        for (Case c : cases) {
            if (c.Id != null) {
                currentCaseIds.add(c.Id);
            }
            if (c.AccountId != null) {
                accountIds.add(c.AccountId);
            }
            if (c.ContactId != null) {
                contactIds.add(c.ContactId);
            }
            resultMap.put(c.Id, new CustomerHistorySummary());
        }

        // Query historical cases safely in USER_MODE
        List<Case> historicalCases = new List<Case>();
        if (!accountIds.isEmpty() || !contactIds.isEmpty()) {
            historicalCases = [
                SELECT Id, AccountId, ContactId, Status, Priority, IsEscalated, IsClosed, CreatedDate, Subject
                FROM Case
                WHERE (AccountId IN :accountIds OR ContactId IN :contactIds)
                  AND Id NOT IN :currentCaseIds
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 500
            ];
        }

        // Map historical cases by AccountId and ContactId
        Map<Id, List<Case>> accountToHistory = new Map<Id, List<Case>>();
        Map<Id, List<Case>> contactToHistory = new Map<Id, List<Case>>();

        for (Case hCase : historicalCases) {
            if (hCase.AccountId != null) {
                if (!accountToHistory.containsKey(hCase.AccountId)) {
                    accountToHistory.put(hCase.AccountId, new List<Case>());
                }
                accountToHistory.get(hCase.AccountId).add(hCase);
            }
            if (hCase.ContactId != null) {
                if (!contactToHistory.containsKey(hCase.ContactId)) {
                    contactToHistory.put(hCase.ContactId, new List<Case>());
                }
                contactToHistory.get(hCase.ContactId).add(hCase);
            }
        }

        // Evaluate each case in the batch
        for (Case c : cases) {
            CustomerHistorySummary summary = resultMap.get(c.Id);
            Set<Id> seenHistoricalCaseIds = new Set<Id>();
            List<Case> relevantHistory = new List<Case>();

            if (c.AccountId != null && accountToHistory.containsKey(c.AccountId)) {
                for (Case h : accountToHistory.get(c.AccountId)) {
                    if (seenHistoricalCaseIds.add(h.Id)) {
                        relevantHistory.add(h);
                    }
                }
            }
            if (c.ContactId != null && contactToHistory.containsKey(c.ContactId)) {
                for (Case h : contactToHistory.get(c.ContactId)) {
                    if (seenHistoricalCaseIds.add(h.Id)) {
                        relevantHistory.add(h);
                    }
                }
            }

            for (Case h : relevantHistory) {
                summary.previousComplaintsCount++;
                if (h.IsEscalated || 'Critical'.equalsIgnoreCase(h.Priority) || 'High'.equalsIgnoreCase(h.Priority)) {
                    summary.previousEscalationsCount++;
                }
                if (!h.IsClosed) {
                    summary.openCasesCount++;
                }
            }

            // Detect repeat signals from complaint text
            String complaintText = ((c.Subject != null ? c.Subject : '') + ' ' + (c.Description != null ? c.Description : '')).toLowerCase();
            Boolean textIndicatesRepeat = complaintText.contains('called twice') ||
                                          complaintText.contains('called three') ||
                                          complaintText.contains('called again') ||
                                          complaintText.contains('nobody came') ||
                                          complaintText.contains('second time') ||
                                          complaintText.contains('repeatedly') ||
                                          complaintText.contains('no one came') ||
                                          complaintText.contains('still waiting');

            if (summary.previousComplaintsCount >= 1 || summary.openCasesCount >= 1 || textIndicatesRepeat) {
                summary.isRepeatComplaint = true;
            }

            summary.historyNotes = 'Previous Complaints: ' + summary.previousComplaintsCount +
                                   ', Previous Escalations: ' + summary.previousEscalationsCount +
                                   ', Open Cases: ' + summary.openCasesCount;
        }

        return resultMap;
    }
}
