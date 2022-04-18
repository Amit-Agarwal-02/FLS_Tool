/****
    @description       :
    @author            : Amit Agarwal
    @group             :
    @last modified on  : 
    @last modified by  : Amit Agarwal
****/


public with sharing class poc_Read_CSV_File {
    
    @AuraEnabled
    public static String  insertfieldLevelPermisison(List<String> contentDocumentIdList, List<String> permissionSetList,List<String> selectedProfileIds) {
        List<SObject> convertedCSVRows;
        Set<String> objFieldValue = new Set<String>();
        List<FieldPermissions> fieldPermissionexisting = new  List<FieldPermissions>();
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
                        Object convertedFieldValue;
                        convertedFieldValue =  getConvertedFieldValue(fieldType, fieldValue);
                        if(fields[i] == 'Field'){
                            objFieldValue.add((String)convertedFieldValue);
                        }
                        obj.put( fields[i],convertedFieldValue);
                    }
                    convertedCSVRows.add(obj);
                }
            }
            for(PermissionSet profPermSet : [Select Id,ProfileId from PermissionSet Where IsOwnedByProfile = true AND ProfileId IN:selectedProfileIds]){
                permissionSetList.add(profPermSet.Id);
            }
            fieldPermissionexisting = [Select Id,ParentId,SobjectType,Field from FieldPermissions Where ParentId IN:permissionSetList AND Field IN:objFieldValue];
            result = insertFLSofCSVRecords(permissionSetList,convertedCSVRows,fieldPermissionexisting);
        }
        catch(Exception e){
            System.debug('Exception Stack Trace => '+ e.getStackTraceString());
            System.debug('Exception Line Number=> '+ e.getLineNumber());
            System.debug('Exception Line Number=> '+e.getmessage());
            result = e.getmessage();
        }
        return result;
    }

    public static String insertFLSofCSVRecords(List<String> permissionSetList, List<SObject> convertedCSVRows, List<FieldPermissions> fieldPermissionexisting){
        String result ;
        try{
            Map<String,String> fieldPermValIdMap = new  Map<String,String>();
            List<FieldPermissions>  fieldPermUpsertlst = new List<FieldPermissions>();
            List<FieldPermissions> convertedCSVRows2 =  (List<FieldPermissions>)convertedCSVRows;

            for(FieldPermissions fieldperm : fieldPermissionexisting){
                String fieldpermVal = fieldperm.Field + '_' + fieldperm.ParentId ;
                fieldPermValIdMap.put(fieldpermVal,fieldperm.Id);
            }           
            for(String permSetId : permissionSetList ){
                for(FieldPermissions newFPerm : convertedCSVRows2){
                    String fieldpermIdKey = newFPerm.Field + '_' + permSetId; 
                    String returnVal = fieldPermValIdMap.containsKey(fieldpermIdKey) ? fieldPermValIdMap.get(fieldpermIdKey) : '' ;
                    FieldPermissions insertFP = new FieldPermissions(ParentId = permSetId,PermissionsEdit = newFPerm.PermissionsEdit,PermissionsRead = newFPerm.PermissionsRead,SobjectType = newFPerm.SobjectType,Field = newFPerm.Field);
                    if(insertFP.PermissionsEdit == true){
                        insertFP.PermissionsRead = true;
                    }
                    if(String.isNotBlank(returnVal)){
                        insertFP.Id = returnVal;
                    }else if(insertFP.PermissionsEdit == false && insertFP.PermissionsRead == false){
                        continue;
                    }
                    fieldPermUpsertlst.add(insertFP);
                }
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
           System.debug('Erorr => Invalid Field Error: '+fieldApiName + '. Please double check the API name of the field.');
        }
        return fieldMap.get(fieldApiName).getDescribe().getType();
    }
}
