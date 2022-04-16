/****
    @description       :
    @author            : Amit Agarwal
    @group             :
    @last modified on  : 
    @last modified by  : Amit Agarwal
****/


public with sharing class poc_Read_CSV_File {

    public static List<FieldPermissions> fieldPermissionexisting = new  List<FieldPermissions>();
    
    @AuraEnabled
    public static String  insertfieldLevelPermisison(List<String> contentDocumentIdList, List<String> permissionSetList,List<String> selectedProfileIds) {
        List<SObject> convertedCSVRows;
        String result ;
        try{
            for (String curContentDocumentId : contentDocumentIdList){
                SObjectType sObjType = ((SObject)Type.forName('FieldPermissions').newInstance()).getSObjectType();         
                map<String,SObjectField> fieldMap = sObjType.getDescribe().fields.getMap();
                
                Blob csvBlobContent = getCsvContent(curContentDocumentId);
                String csvStringContent = blobToString(csvBlobContent, 'ISO-8859-1');
                csvStringContent = csvStringContent.replaceAll('(\r\n|\r)','\n');
                            
                String[] csvRows = csvStringContent.split('\n');
                String[] fields = csvRows[0].split(','); //Gives all the API names of the fields from the 1st CSV row
                csvRows.remove(0);
                map<String,Schema.DisplayType> fieldToFieldTypeMap = new map<String,Schema.DisplayType>();
                for (String field : fields) {
                    fieldToFieldTypeMap.put(field, getFieldType(fieldMap, field));
                }
            
                convertedCSVRows = new SObject[]{};
                for(String row : csvRows) {
                    SObject obj = sObjType.newSObject();
                    String[] fieldInputValues = row.split(',');
                    
                    for (Integer i = 0; i < fields.size(); i++) {
                        String fieldValue = fieldInputValues[i];
                        Schema.DisplayType fieldType = fieldToFieldTypeMap.get(fields[i]);
                        obj.put( fields[i], getConvertedFieldValue(fieldType, fieldValue));
                    }
                    convertedCSVRows.add(obj);
                }
            }
            System.debug('convertedCSVRows is: ' + convertedCSVRows);

            List<PermissionSet> profilePermSetList = new List<PermissionSet>();

            System.debug('before profile permissionSetList is: ' +permissionSetList);
            profilePermSetList = [Select Id,ProfileId from PermissionSet Where IsOwnedByProfile = true AND ProfileId IN:selectedProfileIds];
            for(PermissionSet profPermSet : profilePermSetList ){
                System.debug('profPermSet.Id is: ' + profPermSet.Id);
                permissionSetList.add(profPermSet.Id);
            }
            System.debug('After profile permissionSetList is: ' +permissionSetList);

            fieldPermissionexisting = [Select Id,ParentId,SobjectType,Field from FieldPermissions Where ParentId IN:permissionSetList];
            System.debug('fieldPermissionexisting => '+fieldPermissionexisting);

            List<FieldPermissions>  fieldPermUpsertlst = new List<FieldPermissions>();
            List<FieldPermissions> convertedCSVRows2 =  (List<FieldPermissions>)convertedCSVRows;
            System.debug('convertedCSVRows2222222 is: ' + convertedCSVRows2);
            for(String permSet : permissionSetList ){
                System.debug('permSet is: ' + permSet);
                String newPErmSetId = permSet;
                for(FieldPermissions newFPerm : convertedCSVRows2){
                    String returnVal = checkifAlreadyContains(newFPerm.Field,permSet);
                    System.debug('newPErmSetId  inside for => '+newPErmSetId);
                    System.debug('returnVal => '+returnVal);
                    FieldPermissions insertFP = new FieldPermissions(
                        ParentId = newPErmSetId,
                        PermissionsEdit = newFPerm.PermissionsEdit,
                        PermissionsRead = newFPerm.PermissionsRead,
                        SobjectType = newFPerm.SobjectType,
                        Field = newFPerm.Field
                    );
                    if(insertFP.PermissionsEdit == true){
                        insertFP.PermissionsRead = true;
                    }
                    if(returnVal != '' && returnVal != null){
                        insertFP.Id = returnVal;
                    }else if(insertFP.PermissionsEdit == false && insertFP.PermissionsRead == false){
                        continue;
                    }
                   
                   /* if(returnVal != '' && returnVal != null){
                        newFPerm.Id = returnVal;
                    }else{
                        System.debug('newPErmSetId insdie else => '+newPErmSetId);
                        newFPerm.ParentId = newPErmSetId;
                        //newFPerm.SobjectType = 'Account';
                    }*/
                    /*if(newFPerm.PermissionsEdit == true){
                        newFPerm.PermissionsRead = true;
                    }*/
                    fieldPermUpsertlst.add(insertFP);
                }
            }
            System.debug('fieldPermUpsertlst => '+fieldPermUpsertlst);
            for(FieldPermissions fp : fieldPermUpsertlst){
                System.debug('fieldPermUpsertlst fp => '+fp);
            }
            upsert fieldPermUpsertlst;
            result = 'Success';
        }catch(Exception e){
            System.debug('Exception Stack Trace => '+ e.getStackTraceString());
            System.debug('Exception Line Number=> '+ e.getLineNumber());
            System.debug('Exception Line Number=> '+e.getmessage());
            result = e.getmessage();
        }
        return result;
    }

    public static String checkifAlreadyContains(String fieldValue , String perSetId){
        String returnVal;
        for(FieldPermissions fieldperm : fieldPermissionexisting){
            if(fieldperm.Field == fieldValue && fieldperm.ParentId == perSetId){
                returnVal = fieldperm.Id;
                break;
            }
        }
        return returnVal;
    }


    public static Blob getCsvContent( String contentDocumentId) {      
        ContentVersion csvFile = [SELECT 
                                   VersionData 
                                   FROM ContentVersion 
                                   WHERE ContentDocumentId = :contentDocumentId 
                                         AND IsLatest = true
                                 ];
        System.debug('contentDocumentId is: ' + contentDocumentId);
        System.debug('csvFile is: ' + csvFile);
        return csvFile.VersionData;
    }

    /* Converting the CSV file input(BLOB format) to a string */
    public static String blobToString(Blob input, String inCharset){
        String hex = EncodingUtil.convertToHex(input);
        System.assertEquals(0, hex.length() & 1);
        final Integer bytesCount = hex.length() >> 1;
        String[] bytes = new String[bytesCount];
        for(Integer i = 0; i < bytesCount; ++i)
            bytes[i] =  hex.mid(i << 1, 2);
        return EncodingUtil.urlDecode('%' + String.join(bytes, '%'), inCharset);
    } 

    public static Object getConvertedFieldValue(Schema.DisplayType fieldType, String fieldValue){
        Object convertedFieldValue;
        switch on fieldType {//Setting Field value based on the field data type
            when BOOLEAN {
                convertedfieldValue = String.isEmpty(fieldValue) ? false : Boolean.valueOf(fieldValue);
            }
            when else { 
                convertedfieldValue = fieldValue;
            }
        }
        return convertedFieldValue;
    }

    @TestVisible
    static Schema.DisplayType getFieldType(map<String, SObjectField> fieldMap, String fieldApiName) {
        if(fieldMap.get(fieldApiName) == null) {
            throw new FlowCustomException('Invalid Field Error: '+fieldApiName + '. Please double check the API name of the field.');
        }
        return fieldMap.get(fieldApiName).getDescribe().getType();
    }
    public class FlowCustomException extends Exception{}
}