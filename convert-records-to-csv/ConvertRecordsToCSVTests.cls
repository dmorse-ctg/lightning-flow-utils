@isTest
private class ConvertRecordsToCSVTests {
    @isTest
    private static void testGenerateCSVContent() {
        List <SObject> objects = new List<SObject>{new Account(Name='Test1', AccountNumber='3445556676'), new Account(Name='Test2', BillingCity='Richmond'), new Account(Name='Test3')};
        Test.startTest();
        String fullCSV = ConvertRecordsToCSV.generateCSVContent(objects, null);
        Test.stopTest();
        List<String> rows = fullCSV.split('\n');
        System.assertEquals(4, rows.size());

        System.assertEquals(3, rows[0].split(',').size());
        System.assertEquals('Name,AccountNumber,BillingCity', rows[0]);
        System.assertEquals('Test1,3445556676', rows[1]);
        System.assertEquals('Test2,null,Richmond', rows[2]);
        System.assertEquals('Test3,null,null', rows[3]);
    }

    @isTest
    private static void testGenerateCSVContentRelatedFields() {
        Account account1 = new Account(Name='Test1', AccountNumber='3445556676');
        insert account1;

        Contact contact1 = new Contact(LastName='Test1');
        Contact contact2 = new Contact(LastName='Test2', Email='abc@gmail.com');
        Contact contact3 = new Contact(LastName='Test3', Email='abc@gmail.com', FirstName='Jonny');
        insert new List<Contact>{contact1, contact2, contact3};

        contact2.Related_Contact__c = contact1.Id;
        update contact2;

        List<Contact> contacts = [Select FirstName, LastName, Email, Related_Contact__r.LastName from Contact];

        Test.startTest();
        String fullCSV = ConvertRecordsToCSV.generateCSVContent(contacts, new List<String>{'LastName','Email','Related_Contact__r.LastName'});
        Test.stopTest();
        List<String> rows = fullCSV.split('\n');
        System.assertEquals(4, rows.size());

        System.assertEquals(3, rows[0].split(',').size(), 'Full row text: ' + rows[0]);
        System.assertEquals('LastName,Email,Related_Contact__r.LastName', rows[0]);

        System.assertEquals('Test1,null,null', rows[1]);
        System.assertEquals('Test2,abc@gmail.com,Test1', rows[2]);
        System.assertEquals('Test3,abc@gmail.com,null', rows[3]);
    }

    @isTest
    private static void testGenerateCSVListedFields() {
        // TODO
    }

    @isTest
    private static void testGenerateCSVContentAggregateResult() {
        //TODO
    }

    @isTest
    private static void testGenerateDocument() {
        String csvContent = 'this, this, this, this, this \n';

        Account account = new Account(Name='Test');
        insert account;

        Test.startTest();
        ConvertRecordsToCSV.Outputs result = ConvertRecordsToCSV.generateDocument(new List<String>{account.Id}, 'MyDoc', 'V', 'ALlUsers', csvContent);
        Test.stopTest();

        System.assert(result.contentDocumentId != null);
        System.assert(result.contentVersionId != null);
        System.assert(result.contentDocumentLinks.size() == 1);
        System.assert(result.contentDocumentLinks[0] != null);
    }

    @isTest
    private static void testGenearteDocumentNoLinks() {
        String csvContent = 'this, this, this, this, this \n';
    
        Test.startTest();
        ConvertRecordsToCSV.Outputs result = ConvertRecordsToCSV.generateDocument(null, 'MyDoc', 'V', 'AllUsers', csvContent);
        Test.stopTest();

        System.assert(result.contentDocumentId != null);
        System.assert(result.contentVersionId != null);
        System.assert(result.contentDocumentLinks.size() == 0);
    }
}
