
Doxygen style comments are followed. This has the following general format:

/**
 * @desc Object description
 * @tag Other data
 */

Parameters/Fields are described in the following manner:
	parameter_name [type] [optional_indicator] [description] [default default_value]

	type should be one of integer, numeric, text

	optional_indicator defaults to required

	For example, describing the one parameter in the URL /sales_order/:sales_order_id/reset
	@param sales_order_id INTEGER Sales Order ID 

	In places where an object is described, the following syntax is allowed:
		{
			field [type] [optional_indicator] [description] [default default_value]
		}

	Arrays are described as follows:
		{
			fieldname [{ fieldname type }] 
		}
	

Types of documented stuff:

1. HTTP methods (aka API calls)
This is routes. 
	Required tags:
	i. "desc" - API call description
	ii. "url" - URL
	iii. "method" - Should be GET or POST

	Optional tags:
	i. "body"
		Body consists of fields sent in the body of a POST request. { field_name [type] [optional_indicator] [default default_value] [description] }
	ii. "bodysample"
	iii. "return" Description of the return fields 
	iv. "returnsample" An example of the output of the call. Must be valid JSON 
	v. "param" URL parameter descriptions. Use multiple tags for more than one parameter
		@param parameter_name [type] [optional_indicator] [description] [default default_value]


	vi. "sqlfunc" to what API call is this linked?
	vii. "field"

2. SQL functions
	Required tags:
	

3. API entry points in SQL
This is functions that accepts a JSON object and returns a JSON object

4. Javascript functions


