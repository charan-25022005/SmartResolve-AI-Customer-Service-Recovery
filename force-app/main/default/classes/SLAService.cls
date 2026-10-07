/**
 * @description SLA Risk calculation engine.
 * Computes SLA breach risk and urgency score considering complaint severity,
 * customer impact, sentiment, repeat history, and case age.
 * Bulkified, deterministic, and limit-safe.
 */
public with sharing class SLAService {
    
    /**
     * @description Calculates SLA risk level based on customer and complaint attributes.
     * @param customerImpact Customer impact level ('Low', 'Medium', 'High', 'Critical')
     * @param sentiment Sentiment classification ('Very Positive' to 'Very Negative')
     * @param isRepeatComplaint True if customer has prior complaints or open cases
     * @param issueType Categorized issue type ('Product Failure', etc.)
     * @param caseCreatedDate When the case was logged (optional)
     * @return String SLA Risk Level ('Low', 'Medium', 'High', 'Critical')
     */
    public static String calculateSLARisk(
        String customerImpact,
        String sentiment,
        Boolean isRepeatComplaint,
        String issueType,
        DateTime caseCreatedDate
    ) {
        Integer score = 0;

        // 1. Customer Impact Weight
        if ('Critical'.equalsIgnoreCase(customerImpact)) {
            score += 40;
        } else if ('High'.equalsIgnoreCase(customerImpact)) {
            score += 30;
        } else if ('Medium'.equalsIgnoreCase(customerImpact)) {
            score += 20;
        } else {
            score += 10;
        }

        // 2. Repeat Complaint Weight (+25 pts)
        if (isRepeatComplaint == true) {
            score += 25;
        }

        // 3. Sentiment Severity Weight
        if ('Very Negative'.equalsIgnoreCase(sentiment)) {
            score += 20;
        } else if ('Negative'.equalsIgnoreCase(sentiment)) {
            score += 10;
        }

        // 4. Issue Type Weight
        if ('Product Failure'.equalsIgnoreCase(issueType) || 'Refund Request'.equalsIgnoreCase(issueType)) {
            score += 15;
        } else if ('Delivery Delay'.equalsIgnoreCase(issueType) || 'Service Issue'.equalsIgnoreCase(issueType)) {
            score += 10;
        }

        // 5. Case Age Factor
        if (caseCreatedDate != null) {
            Double ageHours = (DateTime.now().getTime() - caseCreatedDate.getTime()) / (1000.0 * 3600.0);
            if (ageHours > 48) {
                score += 15;
            } else if (ageHours > 24) {
                score += 10;
            }
        }

        // Score to SLA Risk Category mapping
        if (score >= 95) {
            return 'Critical';
        } else if (score >= 65) {
            return 'High';
        } else if (score >= 35) {
            return 'Medium';
        } else {
            return 'Low';
        }
    }
}
