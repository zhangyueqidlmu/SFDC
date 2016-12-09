global with sharing class ErrorHelper {
	private static final String NULL_POINTER_EXCEPTION = '空指针错误';
	private static final String RECORD_ALREADY_INPROCESS = '记录已经被锁定';
	private static final String RECORD_OVER_LIMIT = '查询最多只能50000条，请输入搜索条件重新搜索';
	private static final String RECORD_OFFSET_OVER_LIMIT = '数据最多只能查询当前检索条件前2000条，请更改检索条件重试';
	private static final String RECORD_ALREADY_IN_PROCESS = '当前记录已经在流程中，如有问题，请与管理员联系';
	public static String getUserFriendlyMessage(String msg,String sObjectName) {
		String errorMessage;
		//空指针错误：System.NullPointerException: Attempt to de-reference a null object
		if(msg.contains('NullPointerException')){
	    	errorMessage = NULL_POINTER_EXCEPTION;
	    }
	    //死锁或者超时
	     else if(msg.contains('UNABLE_TO_LOCK')){
	    	errorMessage = RECORD_ALREADY_INPROCESS;
	    }
	    //级联删除，没有当前表或者关联表权限导致的错误
	    else if(msg.contains('DELETE_REQUIRED_ON_CASCADE')) {
	    	
	    }
	    //查询50001
	     else if(msg.contains('Too many query rows')) {
	    	errorMessage = RECORD_OVER_LIMIT;
	    }
	    //offset 超过2000
	    else if(msg.contains('Maximum SOQL offset allowed is 2000')) {
	    	errorMessage = RECORD_OFFSET_OVER_LIMIT;
	    }
	    //当前记录已经在审批流中
	    else if(msg.contains('ALREADY_IN_PROCESS')) {
	    	errorMessage = RECORD_ALREADY_IN_PROCESS;
	    }
	    //Validation Rule失败
	    //eg: Update failed. First exception on row 0 with id a052800000BvtqEAAR; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, 商品价格不能为空且必须大于0.: [GoodsPrice__c] 
	    else if (msg.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')){
	        errorMessage = getUserFriendlyMessage4ValidationException(msg,sObjectName);
	    }
	    //必填字段
	    //eg:Insert failed. First exception on row 0; first error: REQUIRED_FIELD_MISSING, Required fields are missing: [Company_Name__c]: [Company_Name__c]
	     else if(msg.contains('REQUIRED_FIELD_MISSING')){
	    	errorMessage = getUserFriendlyMessage4RequiredField(msg,sObjectName);
	    }
	    //对于unique的字段进行相同值插入会报此种错误:System.DmlException: Insert failed. First exception on row 0; first error: DUPLICATE_VALUE, duplicate value found: Company_Code_Unique__c duplicates value on record with id: a032800000KOlEr: []
	    
	     else if(msg.contains('DUPLICATE_VALUE')) {
	    	errorMessage = getUserFriendlyMessage4DuplicateValue(msg,sObjectName);
	    }
	    return errorMessage;
	}
	
	/**
	*针对unique字段添加重复值的异常获取友好的message
	*@param msg : 异常信息 eg : System.DmlException: Insert failed. First exception on row 0; first error: DUPLICATE_VALUE, duplicate value found: Company_Code_Unique__c duplicates value on record with id: a032800000KOlEr: []
	*@param sObjectName : sObject的API Name
	*@return  
	*/
	private static String getUserFriendlyMessage4DuplicateValue(String msg,String sObjectName) {
		String errorMessage = msg;
		Integer pointer;
		String fieldName;
		if(!msg.contains('DUPLICATE_VALUE')) {
			return errorMessage;
		}
		pointer = errorMessage.indexOf('DUPLICATE_VALUE') + 16;
		if(pointer > -1) {
			errorMessage = errorMessage.mid(pointer, errorMessage.length());
		}
		pointer = errorMessage.indexOf('duplicates');
		if(pointer > -1) {
			errorMessage = errorMessage.mid(0,pointer);
		}
		pointer = errorMessage.indexOf(':') + 1;
		if(pointer > -1) {
			fieldName = errorMessage.mid(pointer,errorMessage.length()).trim();
			Schema.DescribeFieldResult fieldResult = getSObjectFieldDescribeResult(sObjectName,fieldName);
			if(fieldResult != null) {
				fieldName = fieldResult.getLabel();
			}
		}
		errorMessage = errorMessage.mid(0,pointer) + fieldName;
		return errorMessage;
	}
	
	/**
	*针对Validation Rule的异常获取友好的message
	*@param msg : 异常消息 eg: Update failed. First exception on row 0 with id a052800000BvtqEAAR; first error: FIELD_CUSTOM_VALIDATION_EXCEPTION, 商品价格不能为空且必须大于0.: [GoodsPrice__c]
	*@param sObjectName : sObject的API Name
	*@return  返回有问题的field labe + : + error message    (eg : GoodsPrice :  商品价格不能为空且必须大于0.)
	*/
	private static String getUserFriendlyMessage4ValidationException(String msg,String sObjectName){
	    String errorMessage = msg;
	    Integer pointer;
	    String fieldName;
	    if (msg.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')){
	        pointer = errorMessage.indexOf('FIELD_CUSTOM_VALIDATION_EXCEPTION,') + 34;
	        errorMessage = errorMessage.mid(pointer, errorMessage.length());
	    } else {
	    	return msg;
	    }
        pointer = errorMessage.indexOf('\n');
        if(pointer > -1){
        	errorMessage = errorMessage.mid(0, pointer);
        }
        pointer = errorMessage.indexOf(':');
        if(pointer > -1){
        	//去除error message中的 []
        	fieldName = errorMessage.mid(pointer + 1,errorMessage.length()-1).remove('[').remove(']').trim();
        	errorMessage = errorMessage.mid(0, pointer);
        }
        if(fieldName != null) {
        	Schema.DescribeFieldResult fieldDescribeResult = getSObjectFieldDescribeResult(sObjectName,fieldName);
        	if(fieldDescribeResult != null) {
        		errorMessage = fieldDescribeResult.getLabel() + ' : ' + errorMessage;
        	}
        }
        return 	errorMessage;
	}
	
	
	/**
	*  针对必填字段获取友好的message
	*  @param msg : 异常消息  eg: Insert failed. First exception on row 0; first error: REQUIRED_FIELD_MISSING, Required fields are missing: [Company_Name__c]: [Company_Name__c]
	*  @param sObjectName : sObject的API Name
	*  @return : 友好消息 eg : Required fields are missing: Company Name (field label name)
	*/
	private static String getUserFriendlyMessage4RequiredField(String msg,String sObjectName){
		String errorMessage = msg;
		if(!errorMessage.contains('first error:')) {
			return errorMessage;
		}
		Integer pointer;
		String fieldName;
		//获取first error 以后的message信息
		pointer = errorMessage.indexOf('first error:') + 12;
		errorMessage = errorMessage.mid(pointer, errorMessage.length());
		if(pointer > -1){
			pointer = errorMessage.indexOf(',') + 1;
			errorMessage = errorMessage.mid(pointer, errorMessage.length());
		}
		
        pointer = errorMessage.indexOf(']:');
        if(pointer > -1){
        	errorMessage = errorMessage.mid(0, pointer + 1);
        }
        fieldName = errorMessage.mid(errorMessage.indexOf('[') + 1,errorMessage.indexOf(']')-errorMessage.indexOf('[')-1).trim();
        if(fieldName != null) {
        	Schema.DescribeFieldResult fieldResult = getSObjectFieldDescribeResult(sObjectName,fieldName);
        	if(fieldResult != null) {
        		fieldName = fieldResult.getLabel();
        	}
        }
        pointer = errorMessage.indexOf('[');
        if(pointer > -1){
        	errorMessage = errorMessage.mid(0, pointer);
        }
        errorMessage += fieldName;
        return 	errorMessage;		
	}
	
	/*
	*	通过sObject名称以及field名称获取field相关describe  result信息
	*	@param sObjectName  object的api name
	*   @param fieldName    field的api name
	*	@return  此field的describe result
	*/
	private static Schema.DescribeFieldResult getSObjectFieldDescribeResult(String sObjectName,String fieldName) {
		List<Schema.DescribeSObjectResult> sObjectResultList = Schema.describeSObjects(new String[]{sObjectName});
		if(sObjectResultList == null || sObjectResultList.size() == 0) {
			return null;
		} else {
			Schema.DescribeSObjectResult sObjectResult = sObjectResultList.get(0);
			Map<String,SObjectField> maps = sObjectResult.fields.getMap();
			Schema.SObjectField sObjectField = maps.get(fieldName);
			if(sObjectField == null) {
				return null;
			} else {
				Schema.DescribeFieldResult fieldDescribeResult = sObjectField.getDescribe();
				return fieldDescribeResult;
			}
		}
	}
	
}