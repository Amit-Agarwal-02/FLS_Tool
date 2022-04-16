/****
    @description       :
    @author            : Amit Agarwal
    @group             :
    @last modified on  : 
    @last modified by  : Amit Agarwal
****/

public with sharing class searchLooupResult {
    public searchLooupResult() {

    }
    private final static Integer MAX_RESULTS = 50;


    @AuraEnabled(cacheable =true)
    public static List<genericLookupCompWrapper> searchRecords(String searchTerm, List<String> selectedIds, String sObjectName, STring[] filterCriteria, String[] titleFields, String[] subtitleFields){
        
        
        System.debug(' searchTerm => ' + searchTerm);
        System.debug('selectedIds => ' + selectedIds);
        System.debug('sObjectName => ' + sObjectName);
        System.debug('filterCriteria => ' + filterCriteria);
        System.debug(' titleFields => ' + titleFields );
        System.debug(' subTitleFieldse => ' + subtitleFields);

        List<sObject> queryRecords = new List<sObject>();

        String strQuery = '';
        String whereClause = '';
        String whereClauseTemp = '';

        String fieldAPI = 'id,' + string.join(titleFields,',') + ',' + string.join(subTitleFields,',') ;
        System.debug(' fieldAPI => ' + fieldAPI);
        if(selectedIds != null && !selectedIds.isEmpty()){
            whereClause = whereClause + 'id NOT IN :selectedIds';
        }
        System.debug(' whereClause => ' + whereClause);

        if(String.isNotBlank(searchTerm)){
            
         

            if(titleFields != null && titleFields.size() > 0){
                for(String titlefield : titleFields){
                    whereClauseTemp += titlefield + ' like \'%' + searchTerm + '%\'' + ' OR ' ;
                }
            }

            if(subTitleFields != null && subTitleFields.size() > 0){
                for(String subtitlefield : subTitleFields){
                    whereClauseTemp += subtitlefield + ' like \'%' + searchTerm + '%\'' + ' OR ' ;
                }
            }
            System.debug(' fieldAPI => ' + fieldAPI);
            whereClauseTemp = (String.isNotBlank(whereClauseTemp) ?  (whereClauseTemp.removeEnd(' OR ')) : ' ');
            if(String.isNotBlank(whereClause)){
                whereClause += ' AND ' +  + ' ('+ whereClauseTemp + ')' ;
            }else{
                whereClause += ' ('+ whereClauseTemp + ')' ;
            }
        }

        if(filterCriteria != null && filterCriteria.size() > 0 ){
            if(String.isNotBlank(whereClause)){
                whereClause = whereClause + ' AND ';
            }
            whereClause += String.join(filterCriteria, ' AND ');
        }
        System.debug(' whereClause => ' + whereClause);
        System.debug(' whereClauseTemp => ' + whereClauseTemp);
        fieldAPI = fieldAPI.removeEnd(',');
        System.debug(' fieldAPI => ' + fieldAPI);
        System.debug(' Final whereClause => ' + whereClause);
        strQuery = 'SELECT ' + fieldAPI + ' FROM ' + sObjectName + (String.isNotBlank(whereClause) ? ' WHERE ' + whereClause : ' ') + ' LIMIT ' + MAX_RESULTS;
        System.debug(' Final Query => ' + strQuery);
        queryRecords = Database.query(strQuery);


        // Now make it a Wrapper Class to send teh result in specific format
        List<genericLookupCompWrapper> searchResult = new List<genericLookupCompWrapper>();

        for(sObject record : queryRecords ){
            String title = '';
            String subtitle = '';

            if(titleFields != null && titleFields.size() > 0){
                for(String titlefield : titleFields){
                    String titleVal = (String)record.get(titlefield) ;
                    if(titleVal != null){
                        title = title + titleVal + ',' ;
                    }
                }
            }
            title = title.removeEnd(',');

            if(subTitleFields != null && subTitleFields.size() > 0){
                for(String subtitlefield : subTitleFields){
                    String subtitleVal =  (String)record.get(subtitlefield) ;
                    if(subtitleVal != null){
                        subtitle = subtitle + subtitleVal + ',' ;
                    }
                }
            }
            subtitle = subtitle.removeEnd(',') ;
            searchResult.add(new genericLookupCompWrapper(
                (String)record.get('id'),
                sObjectName,
                getIcon(sObjectName),
                title,
                subtitle
            ));
        }
        return searchResult;
    }

    private static String getIcon(String sObjectName){
        switch on sObjectName{
            when 'Contact' {
                return 'standard:contact';
            }
            when 'User'{
                return 'action:user'; 
            }
            when null{
                return 'custom:custom101';
            }
            when else {
                return 'custom:custom101';
            }
        }
    }
}