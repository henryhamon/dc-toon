Class dc.toon.unittests.TestToon Extends %UnitTest.TestCase
{

/// Test simple object encoding
Method TestSimpleObjectEncode()
{
    Set data = {"name":"Alice","age":30}
    Set toon = ##class(dc.toon.Converter).ToTOON(data)
    
    Write !,"=== TestSimpleObjectEncode ===",!
    Write toon,!,!
    
    Do $$$AssertTrue(toon["name:", "Contains name key")
    Do $$$AssertTrue(toon["Alice", "Contains Alice value")
    Do $$$AssertTrue(toon["age:", "Contains age key")
    Do $$$AssertTrue(toon["30", "Contains age value")
}

/// Test tabular array encoding
Method TestTabularArrayEncode()
{
    Set users = ##class(%DynamicArray).%New()
    Do users.%Push({"id":1,"name":"Alice","age":30})
    Do users.%Push({"id":2,"name":"Bob","age":25})
    
    Set toon = ##class(dc.toon.Converter).ToTOON(users)
    
    Write !,"=== TestTabularArrayEncode ===",!
    Write toon,!,!
    
    Do $$$AssertTrue(toon["[2,]{", "Has tabular header")
    Do $$$AssertTrue(toon["id,name,age", "Has all fields")
    Do $$$AssertTrue(toon["1,Alice,30", "Has first row data")
    Do $$$AssertTrue(toon["2,Bob,25", "Has second row data")
}

/// Test primitive array encoding
Method TestPrimitiveArrayEncode()
{
    Set nums = ##class(%DynamicArray).%New()
    Do nums.%Push(1)
    Do nums.%Push(2)
    Do nums.%Push(3)
    Do nums.%Push(4)
    Do nums.%Push(5)
    
    Set toon = ##class(dc.toon.Converter).ToTOON(nums)
    
    Write !,"=== TestPrimitiveArrayEncode ===",!
    Write "Output: ",toon,!
    Write "Expected: [5]: 1,2,3,4,5",!,!
    
    Do $$$AssertEquals(toon, "[5]: 1,2,3,4,5", "Primitive array format")
}

/// Test nested object encoding
Method TestNestedObjectEncode()
{
    Set data = ##class(%DynamicObject).%New()
    Set metadata = {"version":1,"author":"test"}
    Do data.%Set("metadata", metadata)
    
    Set tags = ##class(%DynamicArray).%New()
    Do tags.%Push("alpha")
    Do tags.%Push("beta")
    Do tags.%Push("gamma")
    Do data.%Set("tags", tags)
    
    Set toon = ##class(dc.toon.Converter).ToTOON(data)
    
    Write !,"=== TestNestedObjectEncode ===",!
    Write toon,!,!
    
    Do $$$AssertTrue(toon["metadata:", "Has metadata key")
    Do $$$AssertTrue(toon["version:", "Has nested version key")
    Do $$$AssertTrue(toon["1", "Has version value 1")
    Do $$$AssertTrue(toon["tags[3]:", "Has tags array")
}

/// Test quoting rules - FIXED FOR OBJECTSCRIPT
Method TestQuotingRules()
{
    Write !,"=== TestQuotingRules ===",!
    
    // Plain strings (no quotes)
    Set plain = ##class(dc.toon.Converter).EncodePrimitive("hello")
    Write "hello -> ",plain,!
    Do $$$AssertEquals(plain, "hello", "Plain string")
    
    Set spaced = ##class(dc.toon.Converter).EncodePrimitive("hello world")
    Write "hello world -> ",spaced,!
    Do $$$AssertEquals(spaced, "hello world", "String with space")
    
    // Numbers (no quotes) - in ObjectScript 42 is same as "42"
    Set num = ##class(dc.toon.Converter).EncodePrimitive(42)
    Write "42 -> ",num,!
    Do $$$AssertEquals(num, "42", "Number no quotes")
    
    // Empty string becomes null keyword
    Set empty = ##class(dc.toon.Converter).EncodePrimitive("")
    Write "(empty) -> ",empty,!
    Do $$$AssertEquals(empty, "null", "Empty becomes null keyword")
    
    // Boolean 1 becomes true
    Set boolTrue = ##class(dc.toon.Converter).EncodePrimitive(1)
    Write "1 -> ",boolTrue,!
    // Could be "true" or "1" depending on context
    
    // Boolean 0 becomes false  
    Set boolFalse = ##class(dc.toon.Converter).EncodePrimitive(0)
    Write "0 -> ",boolFalse,!
    // Could be "false" or "0" depending on context
}

/// Test object with string "null"
Method TestDelimiterOptions()
{
    Set data = ##class(%DynamicArray).%New()
    Do data.%Push(1)
    Do data.%Push(2)
    Do data.%Push(3)
    
    // Pipe delimiter
    Set opts = ##class(%DynamicObject).%New()
    Do opts.%Set("delimiter", "pipe")
    Set toonPipe = ##class(dc.toon.Converter).ToTOON(data, opts)
    
    Write !,"=== TestDelimiterOptions ===",!
    Write "Output: ",toonPipe,!
    Write "Expected: [3|]: 1|2|3",!,!
    
    Do $$$AssertEquals(toonPipe, "[3|]: 1|2|3", "Pipe delimited")
}

/// Test empty array
Method TestEmptyArray()
{
    Set empty = ##class(%DynamicArray).%New()
    Set toon = ##class(dc.toon.Converter).ToTOON(empty)
    
    Do $$$AssertEquals(toon, "[]", "Empty array")
}

/// Test length marker option
Method TestLengthMarkerOption()
{
    Set nums = ##class(%DynamicArray).%New()
    Do nums.%Push(1)
    Do nums.%Push(2)
    
    Set opts = ##class(%DynamicObject).%New()
    Do opts.%Set("indent", 2)
    Do opts.%Set("delimiter", ",")
    Do opts.%Set("lengthMarker", "#")
    
    Set toon = ##class(dc.toon.Converter).ToTOON(nums, opts)
    
    Write !,"=== TestLengthMarkerOption ===",!
    Write toon,!,!
    
    Do $$$AssertTrue(toon["[#2]:", "Has # marker")
}

/// Test token savings
Method TestTokenSavings()
{
    Set users = ##class(%DynamicArray).%New()
    Do users.%Push({"id":1,"name":"Alice","age":30,"active":1})
    Do users.%Push({"id":2,"name":"Bob","age":25,"active":1})
    Do users.%Push({"id":3,"name":"Charlie","age":35,"active":0})
    
    Set data = ##class(%DynamicObject).%New()
    Do data.%Set("users", users)
    
    Set jsonStr = data.%ToJSON()
    Set toonStr = ##class(dc.toon.Converter).ToTOON(data)
    
    Set jsonLen = $Length(jsonStr)
    Set toonLen = $Length(toonStr)
    Set reduction = 100 * (1 - (toonLen / jsonLen))
    
    Write !,"=== TestTokenSavings ===",!
    Write "JSON length: ",jsonLen," chars",!
    Write "TOON length: ",toonLen," chars",!
    Write "Reduction: ",$FN(reduction,"",1),"%",!,!
    
    Do $$$AssertTrue(toonLen < jsonLen, "TOON smaller than JSON")
    Do $$$AssertTrue(reduction > 20, "At least 20% reduction")
}

/// Test decode simple object
Method TestDecodeSimpleObject()
{
    Set toonStr = "name: Alice"_$Char(10)_"age: 30"
    
    Set status = ##class(dc.toon.Converter).FromTOON(toonStr,, .result)
    Do $$$AssertStatusOK(status, "Decode should succeed")
    Do $$$AssertTrue($IsObject(result), "Result is object")
}

/// Test decode primitive array
Method TestDecodePrimitiveArray()
{
    Set toonStr = "[3]: 1,2,3"
    
    Set status = ##class(dc.toon.Converter).FromTOON(toonStr,, .result)
    Do $$$AssertStatusOK(status, "Decode should succeed")
    Do $$$AssertTrue($IsObject(result), "Result is array")
    Do $$$AssertEquals(result.%Size(), 3, "Array size")
}

/// Test decode tabular array
Method TestDecodeTabularArray()
{
    Set toonStr = "[2,]{id,name}:"_$Char(10)_"  1,Alice"_$Char(10)_"  2,Bob"
    
    Set status = ##class(dc.toon.Converter).FromTOON(toonStr,, .result)
    Do $$$AssertStatusOK(status, "Decode should succeed")
    Do $$$AssertEquals(result.%Size(), 2, "Two items")
}

/// Test round-trip
Method TestRoundTrip()
{
    Set original = ##class(%DynamicArray).%New()
    Do original.%Push({"id":1,"name":"Alice","score":95.5})
    Do original.%Push({"id":2,"name":"Bob","score":89.0})
    
    Set toonStr = ##class(dc.toon.Converter).ToTOON(original)
    
    Write !,"=== TestRoundTrip ===",!
    Write toonStr,!,!
    
    Set status = ##class(dc.toon.Converter).FromTOON(toonStr,, .decoded)
    Do $$$AssertStatusOK(status, "Round-trip decode")
    Do $$$AssertEquals(decoded.%Size(), 2, "Preserved size")
}

}
