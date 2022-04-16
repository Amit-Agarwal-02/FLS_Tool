import { LightningElement, track, wire, api } from 'lwc';
import fetchLookupRecords from '@salesforce/apex/searchLooupResult.searchRecords';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import updateFieldPermisisons from '@salesforce/apex/poc_Read_CSV_File.insertfieldLevelPermisison';
export default class FileUploadTestComponent extends NavigationMixin(LightningElement) {

    
    baseUrl = 'https://' + location.host + '/';
    @track disableFileUpload = true;
    @track PermissionLookupErrors = [];
    @track ProfileLookupErrors = [];
    @track bShowModal = false;
    @track initialSelection = [];
    loaded = true;
    @track profilefields = ["Name"];
    @track profileotherfields = ["Description"];
    @track permSetfilters = ["IsOwnedByProfile = false"];
    @track permSetfields = ["Name"];
    @track permsetotherfields = ["Description"];
    @track uploadedCSVFiles;
    @track profilefilters = [];
    errors;
    SampleCSVDocumentId = '0696F00000jhgY8QAI'; //hardcoded for POC Change it according to requirement
    SamplePNGDocumentId = '0696F00000jhkYvQAI'; ////hardcoded for POC Change it accordingly to requirement
    @track selectedPermissionSet;
    @track contentDocumentIdList;
    @track selectedProfileIds;
    @track lookupProfileIds;


    resetIds(){
        this.selectedPermissionSet = [];
        this.contentDocumentIdList = [];
        this.selectedProfileIds = [];
        this.lookupProfileIds = [];
    }
    previewFile() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: this.SamplePNGDocumentId
            }
        });
    }

    downloadFile() {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: this.baseUrl + 'sfc/servlet.shepherd/document/download/' + this.SampleCSVDocumentId
            }
        }, false
        );
    }

    handleSelectionChange(event) {
        this.PermissionLookupErrors = [];
        this.ProfileLookupErrors = [];
        const detail = {
            selectedIds: (event.detail.selectedIds !== '' || event.detail.selectedIds !== null) ? event.detail.selectedIds : ''
        }
        this.selectedPermissionSet = event.detail.selectedIds;
        if (this.selectedPermissionSet.length !== 0 || this.selectedPermissionSet === undefined) {
            this.disableFileUpload = false;
        } else {
            this.disableFileUpload = true;
        }
        console.log('handleSelectionChange detail => ' + JSON.stringify(detail));
    }

    handleProfileSelectChange(event){
        this.PermissionLookupErrors = [];
        this.ProfileLookupErrors = [];
        const detail = {
            selectedIds: (event.detail.selectedIds !== '' || event.detail.selectedIds !== null) ? event.detail.selectedIds : ''
        }
        this.selectedProfileIds = event.detail.selectedIds;
        if (this.selectedProfileIds.length !== 0 || this.selectedProfileIds === undefined) {
            this.disableFileUpload = false;
        } else {
            this.disableFileUpload = true;
        }
        console.log('handleProfileSelectChange detail => ' + JSON.stringify(detail));
    }

    handlePermissionSearch(event) {
        this.lookupSelectedIds = event.detail.selectedIds;
        console.log('this.lookupSelectedIds without JSON => ' + this.lookupSelectedIds);
        const detail = {
            searchTerm: event.detail.searchTerm,
            selectedIds: event.detail.selectedIds,
            sObjectName: event.detail.sObjectName,
            filterCriteria: event.detail.filterCriteria,
            titleFields: event.detail.titleFields,
            subtitleFields: event.detail.subtitleFields
        }

        console.log('detail => ' + JSON.stringify(detail));
        fetchLookupRecords(detail)
            .then(results => {
                this.template.querySelector('c-generic-lookup-component[data-lookup-id=PermissionLookup]').setSearchResults(results);
            })
            .catch(error => {
                console.log('error => ' + JSON.stringify(error));
            });
    }


    handleProfileSearch(event) {
        this.lookupProfileIds = event.detail.selectedIds;
        console.log('this.lookupProfileIds without JSON => ' + this.lookupProfileIds);
        const detail = {
            searchTerm: event.detail.searchTerm,
            selectedIds: event.detail.selectedIds,
            sObjectName: event.detail.sObjectName,
            filterCriteria: event.detail.filterCriteria,
            titleFields: event.detail.titleFields,
            subtitleFields: event.detail.subtitleFields
        }

        console.log('handleProfileSearch detail => ' + JSON.stringify(detail));
        fetchLookupRecords(detail)
            .then(results => {
                this.template.querySelector('c-generic-lookup-component[data-lookup-id=ProfileLookup]').setSearchResults(results);
            })
            .catch(error => {
                console.log('error => ' + JSON.stringify(error));
            });
    }

    closeModal() {
        this.bShowModal = false;
    }

    get acceptedFormats() {
        return ['.csv'];
    }

    handleUploadFinished(event) {
        // Get the list of uploaded files
        this.uploadedCSVFiles = event.detail.files;
        if (this.uploadedCSVFiles.length > 0 && (this.selectedPermissionSet !== 0 || this.selectedPermissionSet !== undefined|| this.selectedProfileIds !== 0 || this.selectedProfileIds !== undefined)) { //!== null || this.selectedPermissionSet !== '')) {
            this.bShowModal = true;
        } else {
            this.PermissionLookupErrors = [{
                message: 'Select at least 1 record'
            }];
        }
        this.contentDocumentIdList = this.uploadedCSVFiles.map(element => element.documentId);
        console.log('this.contentDocumentIdList => ' + this.contentDocumentIdList);
    }

    handleUpdateFLS() {
        this.bShowModal = false;
        this.loaded = false;
        this.disableFileUpload = true;
        this.template.querySelector('c-generic-lookup-component[data-lookup-id=PermissionLookup]').reset();
        this.template.querySelector('c-generic-lookup-component[data-lookup-id=ProfileLookup]').reset();
        updateFieldPermisisons({
            contentDocumentIdList: this.contentDocumentIdList,
            permissionSetList: this.selectedPermissionSet,
            selectedProfileIds: this.selectedProfileIds
        })
            .then(results => {
                
                console.log('result => ' + results);
                this.resetIds();
                if (results === 'Success') {
                    this.loaded = true;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Field Level Security Updated Succesfully.',
                            variant: 'success'
                        }),
                    );
                } else {
                    this.loaded = true;
                    this.errors = results;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Failed to update FLS. All changes are rolled back.\n' + this.errors,
                            variant: 'error'
                        })
                    );
                }
                //window.location.reload();
            })
            .catch(error => {
                this.loaded = true;
                this.resetIds();
                console.log('error => ' + JSON.stringify(error));
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to update FLS. All changes are rolled back.\n' + this.error,
                        variant: 'error'
                    })
                );
            });
    }
}