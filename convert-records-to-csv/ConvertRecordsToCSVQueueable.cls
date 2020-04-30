public class ConvertRecordsToCSVQueueable implements Queueable {
    private List<SObject> objectList;
    private List<String> fieldsList;
    private String contentDocumentId;
    private String contentVersionId;
    private List<ContentDocumentLink> contentDocumentLinks;
    private ConvertRecordsToCSVQueueable nextQueueable;

    public ConvertRecordsToCSVQueueable(List<SObject> objectList, List<String> fieldsList, List<ContentDocumentLink> contentDocumentLinks, String contentVersionId, String contentDocumentId, ConvertRecordsToCSVQueueable nextQueueable) {
        this.objectList = objectList;
        this.fieldsList = fieldsList;
        this.contentDocumentId = contentDocumentId;
        this.contentVersionId = contentVersionId;
        this.contentDocumentLinks = contentDocumentLinks;  
        this.nextQueueable = nextQueueable;
    }

    public void execute(QueueableContext context) { 
        String newVersion = ConvertRecordsToCSV.updateDocument(ConvertRecordsToCSV.generateCSVContent(objectList, fieldsList, ConvertRecordsToCSV.CSVParseType.ROWS_ONLY, true), contentDocumentId);
        this.objectList = null;
        if (nextQueueable != null) {
            System.enqueueJob(nextQueueable);
        }
        
        // Generate platform event
        // List<ContentVersion> allDocs = [SELECT VersionData, Title FROM ContentVersion WHERE ContentDocumentId = :documentId];
        // CSV_Document__e documentCompleteEvent = new CSV_Document__e();
        // documentCompleteEvent.ContentDocumentId = returnVal.contentDocumentId;
        // documentCompleteEvent.ContentDocumentLinks = returnVal.contentDocumentLinks;
        // documentCompleteEvent.ContentVersionId = returnVal.contentVersionId;

        // List<Database.SaveResult> results = EventBus.publish(new List<CSV_Document__e>{documentCompleteEvent});
        // for (Database.SaveResult result: results) {
        //     if (!result.isSuccess()) {
        //         // potentially throw and error here?
        //         System.debug('CSV document event publication failed.');
        //     }
        // }
    }
}