/****
    @description       :
    @author            : Amit Agarwal
    @group             :
    @last modified on  : 
    @last modified by  : Amit Agarwal
****/
public with sharing class genericLookupCompWrapper {
    
    private Id id;
    private String sObjectType;
    private String icon;
    private String title;
    private String subtitle;

    public genericLookupCompWrapper(Id id, String sObjectName, String icon, String title, String subtitle) {
        this.Id = id;
        this.sObjectType = sObjectName;
        this.icon = icon;
        this.title = title;
        this.subtitle = subtitle;
    }

    @AuraEnabled
    public Id getId(){
        return id;
    }

    @AuraEnabled
    public String getsObjectType(){
        return sObjectType;
    }
    @AuraEnabled
    public String getIcon(){
        return icon;
    }

    @AuraEnabled
    public String getTitle(){
        return title;
    }

    @AuraEnabled
    public String getSubtitle(){
        return subtitle;
    }
}