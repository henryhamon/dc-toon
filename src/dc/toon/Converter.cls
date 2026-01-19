Class dc.toon.Converter Extends %RegisteredObject
{

/// Encode Python/JSON value to TOON format
ClassMethod ToTOON(input As %DynamicAbstractObject, options As %DynamicObject = "") As %String
{
    If options="" Set options = ..DefaultOptions()
    Quit ..EncodeValue(input, 0, options)
}

/// Default encoding options
ClassMethod DefaultOptions() As %DynamicObject
{
    Set opts = ##class(%DynamicObject).%New()
    Do opts.%Set("indent", 2)
    Do opts.%Set("delimiter", ",")
    Do opts.%Set("lengthMarker", "")
    Quit opts
}

/// Main encoding dispatcher
ClassMethod EncodeValue(value, depth As %Integer, options As %DynamicObject) As %String
{
    If '$IsObject(value) {
        Quit ..EncodePrimitive(value)
    }

    If value.%IsA("%DynamicArray") {
        Quit ..EncodeArray(value, depth, options)
    } ElseIf value.%IsA("%DynamicObject") {
        Quit ..EncodeObject(value, depth, options)
    }

    Quit "null"
}

/// Encode object as key: value pairs with indentation
ClassMethod EncodeObject(obj As %DynamicObject, depth As %Integer, options As %DynamicObject) As %String
{
    Set indent = options.%Get("indent")
    Set indentStr = ..MakeIndent(depth * indent)
    Set result = ""

    Set it = obj.%GetIterator()
    While it.%GetNext(.key, .val, .type) {
        If result'="" Set result = result_$Char(10)

        If $IsObject(val) && val.%IsA("%DynamicObject") {
            // Nested object
            Set result = result_indentStr_key_":"_$Char(10)
            Set nestedObj = ..EncodeObject(val, depth+1, options)
            Set result = result_nestedObj
        } ElseIf $IsObject(val) && val.%IsA("%DynamicArray") {
            // Nested array
            Set arrayStr = ..EncodeArray(val, depth+1, options)
            Set result = result_indentStr_key_arrayStr
        } Else {
            // Primitive
            Set result = result_indentStr_key_": "_..EncodePrimitive(val, type)
        }
    }

    Quit result
}

/// Encode array (tabular, primitive, or mixed)
ClassMethod EncodeArray(arr As %DynamicArray, depth As %Integer, options As %DynamicObject) As %String
{
    Set size = arr.%Size()
    If size = 0 Quit "[]"

    // Check if tabular (uniform objects with primitive fields)
    If ..IsTabularArray(arr, .fields) {
        Quit ..EncodeTabularArray(arr, fields, depth, options)
    }

    // Check if all primitives
    If ..IsAllPrimitives(arr) {
        Quit ..EncodePrimitiveArray(arr, options)
    }

    // Mixed array
    Quit ..EncodeMixedArray(arr, depth, options)
}

/// Encode tabular array: [N,]{field1,field2}:\n  val1,val2
ClassMethod EncodeTabularArray(arr As %DynamicArray, fields As %List, depth As %Integer, options As %DynamicObject) As %String
{
    Set size = arr.%Size()
    Set delimiter = options.%Get("delimiter")
    Set lengthMarker = options.%Get("lengthMarker")
    Set indent = options.%Get("indent")
    Set indentStr = ..MakeIndent((depth+1) * indent)

    // Convert delimiter name to character
    Set delimChar = ..GetDelimiterChar(delimiter)
    Set marker = $Select(lengthMarker="#":"#", 1:"")

    // Header: [N,]{field1,field2}:
    Set fieldList = ""
    For i=1:1:$LL(fields) {
        Set fieldList = fieldList_$Select(i>1:",",1:"")_$LG(fields,i)
    }
    Set result = "["_marker_size_delimChar_"]{"_fieldList_"}:"_$Char(10)

    // Rows
    For i=0:1:size-1 {
        Set obj = arr.%Get(i)
        Set row = ""
        For j=1:1:$LL(fields) {
            Set field = $LG(fields,j)
            Set val = obj.%Get(field)
            Set type = obj.%GetTypeOf(field)
            Set encoded = ..EncodePrimitive(val, type)
            Set row = row_$Select(j>1:delimChar,1:"")_encoded
        }
        Set result = result_indentStr_row
        If i<(size-1) Set result = result_$Char(10)
    }

    Quit result
}

/// Encode primitive array: [N]: val1,val2,val3
ClassMethod EncodePrimitiveArray(arr As %DynamicArray, options As %DynamicObject) As %String
{
    Set size = arr.%Size()
    Set delimiter = options.%Get("delimiter")
    Set lengthMarker = options.%Get("lengthMarker")

    Set delimChar = ..GetDelimiterChar(delimiter)
    Set marker = $Select(lengthMarker="#":"#", 1:"")

    // For comma delimiter, hide it in bracket: [3]:
    // For others, show it: [3|]: or [3	]:
    Set showDelim = (delimiter'=",") && (delimiter'="comma")
    Set delimInBracket = $Select(showDelim:delimChar, 1:"")

    Set result = "["_marker_size_delimInBracket_"]: "
    For i=0:1:size-1 {
        Set val = arr.%Get(i)
        Set type = arr.%GetTypeOf(i)
        Set result = result_$Select(i>0:delimChar,1:"")_..EncodePrimitive(val, type)
    }

    Quit result
}

/// Get delimiter character from option string
ClassMethod GetDelimiterChar(delimiter As %String) As %String
{
    If delimiter="tab" Quit $Char(9)
    If delimiter="pipe" Quit "|"
    If delimiter=$Char(9) Quit $Char(9)
    If delimiter="|" Quit "|"
    Quit ","
}

/// Encode mixed array: [N]:\n- item1\n- item2
ClassMethod EncodeMixedArray(arr As %DynamicArray, depth As %Integer, options As %DynamicObject) As %String
{
    Set size = arr.%Size()
    Set indent = options.%Get("indent")
    Set lengthMarker = options.%Get("lengthMarker")
    Set indentStr = ..MakeIndent((depth+1) * indent)
    Set marker = $Select(lengthMarker="#":"#", 1:"")

    Set result = "["_marker_size_"]:"_$Char(10)

    For i=0:1:size-1 {
        Set val = arr.%Get(i)
        Set result = result_indentStr_"- "

        If $IsObject(val) {
            If val.%IsA("%DynamicObject") {
                Set objStr = ..EncodeObject(val, depth+1, options)
                Set firstLine = $Piece(objStr,$Char(10),1)
                Set rest = $Piece(objStr,$Char(10),2,999)
                Set result = result_$ZStrip(firstLine,"<W")
                If rest'="" Set result = result_$Char(10)_rest
            } Else {
                Set result = result_..EncodeValue(val, depth+1, options)
            }
        } Else {
            Set result = result_..EncodePrimitive(val)
        }

        If i<(size-1) Set result = result_$Char(10)
    }

    Quit result
}

/// Encode primitive value - OBJECTSCRIPT VERSION
ClassMethod EncodePrimitive(value, type As %String = "") As %String
{
    // In ObjectScript, "" is null
    If value="" Quit "null"

    if type="boolean" {
        Quit $Select(value=1:"true",1:"false")
    }

    // Check if numeric (in ObjectScript "42" and 42 are same)
    If $IsValidNum(value) {
        // For boolean-like: 0 or 1 in boolean context become false/true
        // But we can't know context, so just return the number
        // The calling code (EncodeArray/EncodeObject) should handle boolean context
        Quit value
    }

    // Regular string
    Set str = value
    If ..NeedsQuoting(str) {
        Quit """"_..EscapeString(str)_""""
    }

    Quit str
}

/// Simplified NeedsQuoting for ObjectScript
ClassMethod NeedsQuoting(str As %String) As %Boolean
{
    // Empty
    Return:(str="") $$$YES

    // Leading/trailing whitespace
    Return:($ZStrip(str,"<>W")'=str) $$$YES

    // Structural characters
    Return:(str[":"||str["["||str["]"||str["{"||str["}"||str["""") $$$YES
    Return:($Extract(str,1)="-") $$$YES

    // Delimiters
    Return:(str[","||str["|"||str[$Char(9)) $$$YES

    // Control chars
    Return:(str[$Char(10)||str[$Char(13)||str["\") $$$YES

    Return $$$NO
}

/// Escape string for quoted values
ClassMethod EscapeString(str As %String) As %String
{
    Set result = str
    Set result = $Replace(result,"\","\\")
    Set result = $Replace(result,"""","\""")
    Set result = $Replace(result,$Char(10),"\n")
    Set result = $Replace(result,$Char(13),"\r")
    Set result = $Replace(result,$Char(9),"\t")
    Quit result
}

/// Check if array is tabular (uniform objects with primitives only)
ClassMethod IsTabularArray(arr As %DynamicArray, Output fields As %List) As %Boolean
{
    Set size = arr.%Size()
    If size=0 Return $$$NO

    Set first = arr.%Get(0)
    Return:('$IsObject(first)||'first.%IsA("%DynamicObject") ) $$$NO

    // Extract fields from first object
    Kill fields Set fields = ""
    Set it = first.%GetIterator()
    While it.%GetNext(.key,.val) {
        // Check if primitive
        Return:($IsObject(val)) $$$NO
        Set fields = fields_$LB(key)
    }

    Return:($LL(fields)=0 ) $$$NO

    // Verify all objects have same fields (primitives only)
    For i=1:1:size-1 {
        Set obj = arr.%Get(i)
        Return:('$IsObject(obj)||'obj.%IsA("%DynamicObject")) $$$NO

        // Check each field exists and is primitive
        For j=1:1:$LL(fields) {
            Set field = $LG(fields,j)
            Return:('obj.%IsDefined(field)) $$$NO
            Set val = obj.%Get(field)
            Return:($IsObject(val)) $$$NO
        }
    }

    Return $$$YES
}

/// Check if all array elements are primitives
ClassMethod IsAllPrimitives(arr As %DynamicArray) As %Boolean
{
    For i=0:1:arr.%Size()-1 {
        Set val = arr.%Get(i)
        Return:($IsObject(val)) $$$NO
    }
    Return $$$YES
}

/// Generate indentation string
ClassMethod MakeIndent(spaces As %Integer) As %String
{
    Set result = ""
    For i=1:1:spaces Set result = result_" "
    Quit result
}

/// Decode TOON string back to JSON
ClassMethod FromTOON(toonStr As %String, options As %DynamicObject = "", Output result) As %Status
{
    If options="" Set options = ..DefaultDecodeOptions()
    Set status = $$$OK
    Try {
        Set parser = ##class(dc.toon.Parser).%New(toonStr, options)
        Set result = parser.Parse()
    } Catch ex {
        Set status = ex.AsStatus()
    }
    Quit status
}

/// Default decoding options
ClassMethod DefaultDecodeOptions() As %DynamicObject
{
    Set opts = ##class(%DynamicObject).%New()
    Do opts.%Set("indent", 2)
    Do opts.%Set("strict", 1)
    Quit opts
}

}
