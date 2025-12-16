Class dc.toon.Parser Extends %RegisteredObject
{

Property Input As %String;

Property Options As %DynamicObject;

Property Position As %Integer [ InitialExpression = 1 ];

Property Line As %Integer [ InitialExpression = 1 ];

Method %OnNew(input As %String, options As %DynamicObject) As %Status
{
    Set ..Input = input
    Set ..Options = options
    Quit $$$OK
}

Method Parse() As %DynamicAbstractObject
{
    Set trimmed = $ZStrip(..Input,"<>W")

    // Empty input
    If trimmed="" Quit ""

    // Array notation
    If $Extract(trimmed,1)="[" {
        Quit ..ParseArray()
    }

    // Object notation (check for key: value)
    If trimmed[":",$Extract(trimmed,1)'="-" {
        Quit ..ParseObject(0)
    }

    // Single primitive
    Quit ..ParsePrimitive(trimmed)
}

Method ParseArray() As %DynamicArray
{
    Set line = $Piece(..Input,$Char(10),1)

    // Extract [N] or [N,] or [N|] or [N	]
    Set lengthPart = $Piece($Piece(line,"]",1),"[",2)

    // Remove optional # marker
    Set lengthPart = $Replace(lengthPart,"#","")

    // Detect delimiter in bracket
    Set delimiter = ","
    If lengthPart[$Char(9) Set delimiter = $Char(9)
    If lengthPart["|" Set delimiter = "|"

    // Extract numeric size
    Set size = +$ZStrip(lengthPart,"*E'N")

    // Check for tabular: [N,]{fields}:
    If line["{" {
        Quit ..ParseTabularArray(size, delimiter, line)
    }

    // Check for mixed array: [N]:\n- item
    If line["]:",$Piece(line,":",2)="" {
        Quit ..ParseMixedArray(size)
    }

    // Primitive array: [N]: val1,val2
    Quit ..ParsePrimitiveArray(size, delimiter, line)
}

Method ParseTabularArray(size As %Integer, delimiter As %String, firstLine As %String) As %DynamicArray
{
    // Extract fields from {field1,field2}
    Set fieldsPart = $Piece($Piece(firstLine,"}",1),"{",2)
    Set fields = ""
    For i=1:1:$Length(fieldsPart,",") {
        Set fields = fields_$LB($ZStrip($Piece(fieldsPart,",",i),"<>W"))
    }

    Set arr = ##class(%DynamicArray).%New()

    // Parse rows (skip first line, which is header)
    Set lines = $Length(..Input,$Char(10))
    For i=2:1:lines {
        Set line = $Piece(..Input,$Char(10),i)
        Set trimmed = $ZStrip(line,"<W") // Left trim
        If trimmed="" Continue

        Set obj = ##class(%DynamicObject).%New()

        // Split by delimiter
        For j=1:1:$LL(fields) {
            Set field = $LG(fields,j)
            Set val = $Piece(trimmed,delimiter,j)
            Set val = $ZStrip(val,"<>W")
            Do obj.%Set(field, ..ParsePrimitive(val))
        }

        Do arr.%Push(obj)
    }

    // Validate size if strict
    If ..Options.%Get("strict") && (arr.%Size()'=size) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Array size mismatch: expected "_size_", got "_arr.%Size()))
    }

    Quit arr
}

Method ParsePrimitiveArray(size As %Integer, delimiter As %String, firstLine As %String) As %DynamicArray
{
    Set dataPart = $Piece(firstLine,":",2,999)
    Set dataPart = $ZStrip(dataPart,"<>W")

    Set arr = ##class(%DynamicArray).%New()

    For i=1:1:$Length(dataPart,delimiter) {
        Set val = $ZStrip($Piece(dataPart,delimiter,i),"<>W")
        Do arr.%Push(..ParsePrimitive(val))
    }

    If ..Options.%Get("strict") && (arr.%Size()'=size) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Array size mismatch"))
    }

    Quit arr
}

Method ParseMixedArray(size As %Integer) As %DynamicArray
{
    Set arr = ##class(%DynamicArray).%New()
    Set lines = $Length(..Input,$Char(10))

    For i=2:1:lines {
        Set line = $Piece(..Input,$Char(10),i)
        Set trimmed = $ZStrip(line,"<W")

        If $Extract(trimmed,1,2)="- " {
            Set val = $Extract(trimmed,3,*)
            Do arr.%Push(..ParsePrimitive(val))
        }
    }

    If ..Options.%Get("strict") && (arr.%Size()'=size) {
        $$$ThrowStatus($$$ERROR($$$GeneralError,"Array size mismatch"))
    }

    Quit arr
}

Method ParseObject(depth As %Integer) As %DynamicObject
{
    Set obj = ##class(%DynamicObject).%New()
    Set lines = $Length(..Input,$Char(10))
    Set indentSize = ..Options.%Get("indent")
    Set currentIndent = depth * indentSize

    For i=1:1:lines {
        Set line = $Piece(..Input,$Char(10),i)
        If line="" Continue

        // Count leading spaces
        Set lineIndent = $Length(line) - $Length($ZStrip(line,"<W"))
        If lineIndent < currentIndent Continue // Skip deeper nested
        If lineIndent > currentIndent Continue // Skip shallower

        Set trimmed = $ZStrip(line,"<>W")
        If trimmed[":" {
            Set key = $ZStrip($Piece(trimmed,":",1),"<>W")
            Set val = $ZStrip($Piece(trimmed,":",2,999),"<>W")

            If val="" {
                // Nested object, parse next lines
                // Simplified: assume primitive for now
                Do obj.%Set(key, "")
            } Else {
                Set parsedVal = ..ParsePrimitive(val, .type)
                Do obj.%Set(key, parsedVal, type)
            }
        }
    }

    Quit obj
}

Method ParsePrimitive(str As %String, Output type As %String = "") As %String
{
    Set str = $ZStrip(str,"<>W")

    // null
    If str="null" {
        Set type="null"
        Quit ""
    }

    // Boolean
    If str="true" {
        Set type="boolean"
        Quit 1
    }
    If str="false" {
        Set type="boolean"
        Quit 0
    }

    // Number
    If $IsValidNum(str) {
        Set type="number"
        Quit +str
    }

    // Quoted string
    If $Extract(str,1)="""" && ($Extract(str,*)="""") {
        Set unquoted = $Extract(str,2,*-1)
        Quit ..UnescapeString(unquoted)
    }

    // Plain string
    Quit str
}

Method UnescapeString(str As %String) As %String
{
    Set result = str
    Set result = $Replace(result,"\n",$Char(10))
    Set result = $Replace(result,"\r",$Char(13))
    Set result = $Replace(result,"\t",$Char(9))
    Set result = $Replace(result,"\""","""")
    Set result = $Replace(result,"\\","\")
    Quit result
}

}
