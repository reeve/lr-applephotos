use AppleScript version "2.4"
use scripting additions
use framework "Foundation"

-- pass a string, list, record or number, and either a path to save the result to, or missing value to have it returned as text
on convertASToJSON:someASThing saveTo:posixPath
	--convert to JSON data
	set {theData, theError} to current application's NSJSONSerialization's dataWithJSONObject:someASThing options:0 |error|:(reference)
	if theData is missing value then error (theError's localizedDescription() as text) number -10000
	if posixPath is missing value then -- return string
		-- convert data to a UTF8 string
		set someString to current application's NSString's alloc()'s initWithData:theData encoding:(current application's NSUTF8StringEncoding)
		return someString as text
	else
		-- write data to file
		set theResult to theData's writeToFile:posixPath atomically:true
		return theResult as boolean -- returns false if save failed
	end if
end convertASToJSON:saveTo:

-- pass either a POSIX path to the JSON file, or a JSON string; isPath is a boolean value to tell which
on convertJSONToAS:jsonStringOrPath isPath:isPath
	if isPath then -- read file as data
		set theData to current application's NSData's dataWithContentsOfFile:jsonStringOrPath
	else -- it's a string, convert to data
		set aString to current application's NSString's stringWithString:jsonStringOrPath
		set theData to aString's dataUsingEncoding:(current application's NSUTF8StringEncoding)
	end if
	-- convert to Cocoa object
	set {theThing, theError} to current application's NSJSONSerialization's JSONObjectWithData:theData options:0 |error|:(reference)
	if theThing is missing value then error (theError's localizedDescription() as text) number -10000
	-- we don't know the class of theThing for coercion, so...
	set listOfThing to current application's NSArray's arrayWithObject:theThing
	return item 1 of (theThing as list)
end convertJSONToAS:isPath:

-- pass a string, list, record or number, and either a path to save the result to, or missing value to have it returned as text
on convertASToPlist:someASThing saveTo:posixPath
	if posixPath is missing value then -- return string
		-- convert to property list data
		set {theData, theError} to current application's NSPropertyListSerialization's dataWithPropertyList:someASThing |format|:(current application's NSPropertyListXMLFormat_v1_0) options:0 |error|:(reference) -- don't use binary format
		if theData is missing value then error (theError's localizedDescription() as text) number -10000
		-- convert data to UTF8 string
		set someString to current application's NSString's alloc()'s initWithData:theData encoding:(current application's NSUTF8StringEncoding)
		return someString as text
	else -- saving to file
		-- convert to property list data
		set {theData, theError} to current application's NSPropertyListSerialization's dataWithPropertyList:someASThing |format|:(current application's NSPropertyListBinaryFormat_v1_0) options:0 |error|:(reference) -- might as well use binary format
		if theData is missing value then error (theError's localizedDescription() as text) number -10000
		-- write data to file
		set theResult to theData's writeToFile:posixPath atomically:true
		return theResult as boolean -- returns false if save failed
	end if
end convertASToPlist:saveTo:

-- pass either a POSIX path to the .plist file, or a property list string; isPath is a boolean value to tell which
on convertPlistToAS:plistStringOrPath isPath:isPath
	if isPath then -- read file as data
		set theData to current application's NSData's dataWithContentsOfFile:plistStringOrPath
	else -- it's a string, convert to data
		set aString to current application's NSString's stringWithString:plistStringOrPath
		set theData to aString's dataUsingEncoding:(current application's NSUTF8StringEncoding)
	end if
	-- convert to Cocoa object
	set {theThing, theError} to current application's NSPropertyListSerialization's propertyListWithData:theData options:0 |format|:(missing value) |error|:(reference)
	if theThing is missing value then error (theError's localizedDescription() as text) number -10000
	-- we don't know the class of theThing for coercion, so...
	set listOfThing to current application's NSArray's arrayWithObject:theThing
	return item 1 of (theThing as list)
end convertPlistToAS:isPath:

-- pass either a POSIX path to the JSON file, or a JSON string; isPath is a boolean value to tell which. saveTo is either a path to save the result to, or missing value to have it returned as text
on convertJSONToPlist:jsonStringOrPath isPath:isPath saveTo:posixPath
	if isPath then -- read file as data
		set theData to current application's NSData's dataWithContentsOfFile:jsonStringOrPath
	else -- it's a string, convert to data
		set aString to current application's NSString's stringWithString:jsonStringOrPath
		set theData to aString's dataUsingEncoding:(current application's NSUTF8StringEncoding)
	end if
	-- convert to Cocoa object
	set {theThing, theError} to current application's NSJSONSerialization's JSONObjectWithData:theData options:0 |error|:(reference)
	if theThing is missing value then error (theError's localizedDescription() as text) number -10000
	if posixPath is missing value then -- return string
		-- convert to property list data
		set {theData, theError} to current application's NSPropertyListSerialization's dataWithPropertyList:theThing |format|:(current application's NSPropertyListXMLFormat_v1_0) options:0 |error|:(reference) -- don't use binary format
		if theData is missing value then error (theError's localizedDescription() as text) number -10000
		-- convert data to UTF8 string
		set someString to current application's NSString's alloc()'s initWithData:theData encoding:(current application's NSUTF8StringEncoding)
		return someString as text
	else -- saving to file
		-- convert to property list data
		set {theData, theError} to current application's NSPropertyListSerialization's dataWithPropertyList:theThing |format|:(current application's NSPropertyListBinaryFormat_v1_0) options:0 |error|:(reference)
		if theData is missing value then error (theError's localizedDescription() as text) number -10000
		-- write data to file
		set theResult to theData's writeToFile:posixPath atomically:true
		return theResult as boolean -- returns false if save failed
	end if
end convertJSONToPlist:isPath:saveTo:

-- pass either a POSIX path to the .plist file, or a property list string; isPath is a boolean value to tell which. saveTo is either a path to save the result to, or missing value to have it returned as text
on convertPlistToJSON:plistStringOrPath isPath:isPath saveTo:posixPath
	if isPath then -- read file as data
		set theData to current application's NSData's dataWithContentsOfFile:plistStringOrPath
	else -- it's a string, convert to data
		set aString to current application's NSString's stringWithString:plistStringOrPath
		set theData to aString's dataUsingEncoding:(current application's NSUTF8StringEncoding)
	end if
	-- convert to Cocoa object
	set {theThing, theError} to current application's NSPropertyListSerialization's propertyListWithData:theData options:0 |format|:(missing value) |error|:(reference)
	if theThing is missing value then error (theError's localizedDescription() as text) number -10000
	--convert to JSON data
	set {theData, theError} to current application's NSJSONSerialization's dataWithJSONObject:theThing options:0 |error|:(reference)
	if theData is missing value then error (theError's localizedDescription() as text) number -10000
	if posixPath is missing value then -- return string
		-- convert data to a UTF8 string
		set someString to current application's NSString's alloc()'s initWithData:theData encoding:(current application's NSUTF8StringEncoding)
		return someString as text
	else
		-- write data to file
		set theResult to theData's writeToFile:posixPath atomically:true
		return theResult as boolean -- returns false if save failed	
	end if
end convertPlistToJSON:isPath:saveTo: