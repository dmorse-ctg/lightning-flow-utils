public with sharing class FilesController {
    // class FilesException /
    public class FileUploadInfo {
        @AuraEnabled public String ContentDocumentId;
        @AuraEnabled public String ContentVersionId;
        @AuraEnabled public List<ContentDocumentLink> ContentDocumentLinks;
    }

    @AuraEnabled public static FileUploadInfo uploadFile(String fileName, String fileExtension, String versionData, String documentShareType, String documentVisibility, List<String> linkedRecordIds) {
        ContentVersion cv = new ContentVersion();
        cv.VersionData = Blob.valueOf(versionData);
        cv.Title = fileName;
        cv.PathOnClient = fileName + fileExtension;
        cv.IsMajorVersion = true;
        insert cv;

        List<ContentDocument> doc = [Select Id from ContentDocument WHERE LatestPublishedVersionId =: cv.Id LIMIT 1];        
        List<ContentDocumentLink> linkRecords = new List<ContentDocumentLink>{};
        if (linkedRecordIds != null) {
            for (String recordId: linkedRecordIds) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = doc[0].Id;
                cdl.LinkedEntityId = recordId;
                if (documentShareType != null) {
                    cdl.ShareType = documentShareType;
                } else {
                    cdl.ShareType = 'V';
                }
                if (documentVisibility != null) {
                    cdl.Visibility = documentVisibility;
                } else {
                    cdl.Visibility = 'AllUsers';
                }
                linkRecords.add(cdl);
            }
            insert linkRecords;
        }

        FileUploadInfo returnVal = new FileUploadInfo();
        returnVal.ContentDocumentId=doc[0].Id;
        returnVal.ContentVersionId=cv.Id;
        returnVal.ContentDocumentLinks=linkRecords;
        return returnVal;
    }
}
