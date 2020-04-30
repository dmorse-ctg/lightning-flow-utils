public class ConvertRecordsToCSVQueueable implements Queueable {
    private List<SObject> objectList;
    private List<String> fieldsList;

    //Document Info
    private String contentDocumentId;
    private String contentVersionId;
    private List<ContentDocumentLink> contentDocumentLinks;

    public ConvertRecordsToCSVQueueable(List<SObject> objectList, List<String> fieldsList, List<ContentDocumentLink> contentDocumentLinks, String contentVersionId, String contentDocumentId) {
        this.objectList = objectList;
        this.fieldsList = fieldsList;
        this.contentDocumentId = contentDocumentId;
        this.contentVersionId = contentVersionId;
        this.contentDocumentLinks = contentDocumentLinks;    
    }

    public void execute(QueueableContext context) { 

        String newVersion = ConvertRecordsToCSV.updateDocument(GenerateSObjectCSV.generateCSVContent(objectList, fieldsList, GenerateSObjectCSV.CSVParseType.ROWS_ONLY, true), contentDocumentId);
        this.objectList = null;

        // Generate platform event
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