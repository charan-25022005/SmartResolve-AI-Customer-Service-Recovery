// --- SMARTRESOLVE AI: DEMO DATA INITIALIZATION ---
// Setup customer John and his history:
// Previous Complaints: 2, Previous Escalations: 1, Open Cases: 1

Account acc = new Account(Name = 'John Home Appliances');
insert acc;

Contact con = new Contact(
    FirstName = 'John',
    LastName = 'DemoCustomer',
    AccountId = acc.Id,
    Email = 'john.customer@example.com'
);
insert con;

// Disable triggers temporarily during history seeding
CaseTriggerHandler.isTriggerDisabled = true;

List<Case> history = new List<Case>();
// 1. Prior closed complaint
history.add(new Case(
    AccountId = acc.Id,
    ContactId = con.Id,
    Subject = 'Microwave installation question',
    Description = 'Customer needed guidance on installation bracket.',
    Status = 'Closed',
    Priority = 'Medium',
    IsEscalated = false
));

// 2. Prior closed escalated complaint
history.add(new Case(
    AccountId = acc.Id,
    ContactId = con.Id,
    Subject = 'Dishwasher repair delay',
    Description = 'Service technician was delayed by 2 days.',
    Status = 'Closed',
    Priority = 'High',
    IsEscalated = true
));

// 3. Existing unresolved open case
history.add(new Case(
    AccountId = acc.Id,
    ContactId = con.Id,
    Subject = 'Freezer sensor warning',
    Description = 'Temperature sensor light flashing intermittently.',
    Status = 'Working',
    Priority = 'Medium',
    IsEscalated = false
));

insert history;

// Re-enable triggers for the live demonstration case
CaseTriggerHandler.isTriggerDisabled = false;
CaseTriggerHandler.processedCaseIds.clear();

// Create the live hackathon demonstration complaint case
Case demoCase = new Case(
    AccountId = acc.Id,
    ContactId = con.Id,
    Subject = 'Refrigerator Breakdown Emergency',
    Description = 'My refrigerator stopped working three days ago. I called twice and nobody came. I\'m extremely disappointed and want a refund.',
    Status = 'New',
    Priority = 'Medium'
);

insert demoCase;

System.debug('=== SMARTRESOLVE DEMO CASE CREATED ===');
System.debug('DEMO CASE ID: ' + demoCase.Id);
