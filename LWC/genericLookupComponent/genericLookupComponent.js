import { LightningElement, track, api } from 'lwc';
const MINIMAL_SEARCH_TERM_LENGTH = -1;
const SEARCH_DELAY = 300;
export default class GenericLookupComponent extends LightningElement {

    @api lookuplabel;
    @api selectedItem = [];
    @api placeholder = '';
    @api multiSelectLookup = false;
    @api errors = [];
    @api scrollAfterNItems;
    @api customKey;
    @api objectname;
    @api filterCriteria = [];
    @api titleFields = [];
    @api subtitleFields = [];

    @track searchTerm = '';
    @track searchResults = [];
    @track hasFocus = false;
    inputToggle;
    cleanSearchTerm;
    blurTimeout;
    searchThrottingTimeout;

    @api
    setSearchResults(results) {
        this.searchResults = results.map(result => {
            if (typeof result.icon === 'undefined') {
                result.icon = 'standard:default';
            }
            return result;
        });
    }

    @api
    reset(){
        this.searchTerm = '';
        this.searchResults = [];
        this.selectedItem = [];
    }

    @api
    getSelection(){
        return this.selectedItem;
    }

    @api
    getKey(){
        return this.customKey;
    }

    isSelectionAllowed(){
        if(this.multiSelectLookup){
            return true;
        }else{
            return !this.hasSelection();
        }
    }

    hasResults(){
        return this.searchResults.length > 0;
    }

    hasSelection(){
        return this.selectedItem.length > 0;
    }
    
    updateSearchTerm(newSearchTerm){
       this.searchTerm = newSearchTerm;
       const newCleansearchterm = newSearchTerm.trim().replace(/\*/g,'').toLowerCase();
       if(this.cleanSearchTerm === newCleansearchterm){
           return;
       }
       this.cleanSearchTerm = newCleansearchterm;

       if(newCleansearchterm.length < MINIMAL_SEARCH_TERM_LENGTH){
           this.searchResults = [];
           return;
       }

       if(this.searchThrottingTimeout){
           clearTimeout(this.searchThrottingTimeout);
       }

       this.searchThrottingTimeout = setTimeout(() => {
           if(this.cleanSearchTerm.length > MINIMAL_SEARCH_TERM_LENGTH){
               const searchEvent = new CustomEvent('search',{
                   detail:{
                       searchTerm: this.cleanSearchTerm,
                       selectedIds: this.selectedItem.map(element => element.id),
                       sObjectName: this.objectname,
                       filterCriteria: this.filterCriteria,
                       titleFields: this.titleFields,
                       subtitleFields: this.subtitleFields
                   }
               });
               this.dispatchEvent(searchEvent);
           }
           this.searchThrottingTimeout = null;
        },
        SEARCH_DELAY
       );
    }

    handleInput(event){
        if(!this.isSelectionAllowed()){
            return;
        }
        this.updateSearchTerm(event.target.value);
    }

    handleResultClick(event){
        const recordId = event.currentTarget.dataset.recordid;
        let selectedItemVal = this.searchResults.filter(result => result.id === recordId);
        if(selectedItemVal.length === 0){
            return;
        }

        selectedItemVal =selectedItemVal[0];
        const newSelection = [...this.selectedItem];
        newSelection.push(selectedItemVal);
        this.selectedItem = newSelection;  

        console.log('this.selectedItem  '+this.selectedItem );
        this.searchTerm = '';
        this.searchResults = [];

        if(this.hasSelection() && !this.multiSelectLookup){
            this.inputToggle = true;
        }
        const selectedIdsEvent = new CustomEvent('selectionchange',{
            detail:{
                selectedIds: this.selectedItem.map(element => element.id)
            }
        });
        this.dispatchEvent(selectedIdsEvent);
        //this.dispatchEvent(new CustomEvent('selectionchange'));
    }

    handleComboboxClick(){
        //hide combobox immediately
        if(this.blurTimeout){
            window.clearTimeout(this.blurTimeout);
        }
        this.hasFocus = false;
    }


    handleFocus(){
        if(!this.isSelectionAllowed()){
            return;
        }
        this.hasFocus = true;

        const searchEvent = new CustomEvent('search',{
            detail:{
                searchTerm: '',
                selectedIds: this.selectedItem.map(element => element.id),
                sObjectName: this.objectname,
                filterCriteria: this.filterCriteria,
                titleFields: this.titleFields,
                subtitleFields: this.subtitleFields
            }
        });
        this.dispatchEvent(searchEvent);
    }

    handleBlur(){
        if(!this.isSelectionAllowed()){
            return;
        }
        this.blurTimeout = window.setTimeout(() => {
            this.hasFocus = false;
            this.blurTimeout = null;
        },
        SEARCH_DELAY
        );
    }

    handleRemoveSelectedItem(event){
        const recordId = event.currentTarget.name;
        this.selectedItem = this.selectedItem.filter(item => item.id !== recordId);

        const selectedIdsEvent = new CustomEvent('selectionchange',{
            detail:{
                selectedIds: this.selectedItem.map(element => element.id)
            }
        });
        this.dispatchEvent(selectedIdsEvent);
        //this.dispatchEvent(new CustomEvent('selectionchange'));        
    }

    handleRemoveSelection(){
        this.selectedItem = [];
        const selectedIdsEvent = new CustomEvent('selectionchange',{
            detail:{
                selectedIds: this.selectedItem.map(element => element.id)
            }
        });
        this.dispatchEvent(selectedIdsEvent);
        //this.dispatchEvent(new CustomEvent('selectionchange'));
    }

    get getComboContainerClass(){
        let css = 'slds-combobox_container slds-has-inline-listbox '
        if( this.hasFocus && this.hasResults()){
            css +='slds-has-input-focus ';
        }
        if(this.errors.length > 0){
            css += 'has-custom-error';           
        }
        return css;
    }


    get getDropDownClass(){
        let css = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ';
        if( this.hasFocus && this.hasResults()){
            css +='slds-is-open';
        }
        else{
            css += 'slds-combobox-lookup';           
        }
        return css;
    }

    get getInputClass(){
        let css ='slds-input slds-combobox__input has-custom-height ' + (this.errors.length === 0 ? '' : 'has-custom-error ');
        if(this.multiSelectLookup == false){
            css += 'slds-combobox__input-value ' + (this.hasSelection() ? 'has-custom-border' : '');
        }
        return css;
    }
    
    get getComboboxClass(){
        let css ='slds-combobox__form-element slds-input-has-icon ';
        if(this.multiSelectLookup){
            css += 'slds-input-has-icon_right';

        }else{
            css += (this.hasSelection()? 'slds-input-has-icon_left-right' : 'slds-input-has-icon_right');
        }
        return css;
    }

    get getSearchIconClass()
    {
        let css = 'slds-input__icon slds-input__icon_right ';
        if(this.multiSelectLookup == false){
            css = 'slds-input__icon slds-input__icon_right ' +  (!this.hasSelection() ? '' : 'slds-hide');
        }
        return css;
   }

   get getClearSelectionButtonClass(){
       return 'slds-button slds-button_icon slds-input__icon slds-input__icon_right ' + (this.hasSelection() ? '' : 'slds-hide');  
   }

   get getSelectIconName(){
       return this.hasSelection() ? this.selectedItem[0].icon : 'standard:default';
   }

    get isVaueSelected(){
        if(this.multiSelectLookup == false && this.hasSelection() ){
            return true;
        }
    }

   get getSelectIconClass(){
       return 'slds-combobox__input-entity-icon ' + (this.hasSelection() ? '' : 'slds-hide');
   }


    get getInputValue(){
       if(this.multiSelectLookup){
           return this.searchTerm;
       }
       return this.hasSelection() ? this.selectedItem[0].title : this.searchTerm ;
    }

    get getListboxClass(){
        return 'slds-listbox slds-listbox_vertical slds-dropdown slds-dropdown_fluid slds-dropdown_length-width-icon-10' + 'slds-dropdown_length-width-icon-' + '10' ;
    }

    get isExpanded(){
        return this.hasResults();
    }

    get isMultiSelectAllowed(){
       return (this.multiSelectLookup) ;
    }

}