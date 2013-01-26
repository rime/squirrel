//
// OVInputSourceHelper.m
//
// Copyright (c) 2010-2011 Lukhnos D. Liu (lukhnos at openvanilla dot org)
// 
// Permission is hereby granted, free of charge, to any person
// obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without
// restriction, including without limitation the rights to use,
// copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//

#import "OVInputSourceHelper.h"

@implementation OVInputSourceHelper
+ (NSArray *)allInstalledInputSources
{
	CFArrayRef list = TISCreateInputSourceList(NULL, true);
	return [NSMakeCollectable(list) autorelease];
}

+ (TISInputSourceRef)inputSourceForProperty:(CFStringRef)inPropertyKey stringValue:(NSString *)inValue
{
	
	CFTypeID stringID = CFStringGetTypeID();

	for (id source in [self allInstalledInputSources]) {
		CFTypeRef property = TISGetInputSourceProperty((TISInputSourceRef)source, inPropertyKey);		
		if (!property || CFGetTypeID(property) != stringID) {
			continue;
		}

		if (inValue && [inValue compare:(NSString *)property] == NSOrderedSame) {
			return (TISInputSourceRef)source;
		}
	}
	
	return NULL;
}

+ (TISInputSourceRef)inputSourceForInputSourceID:(NSString *)inID
{
	return [self inputSourceForProperty:kTISPropertyInputSourceID stringValue:inID];
}

+ (BOOL)inputSourceEnabled:(TISInputSourceRef)inInputSource
{
	CFBooleanRef value = TISGetInputSourceProperty(inInputSource, kTISPropertyInputSourceIsEnabled);
	return value ? (BOOL)CFBooleanGetValue(value) : NO; 
}

+ (BOOL)enableInputSource:(TISInputSourceRef)inInputSource
{
	OSStatus status = TISEnableInputSource(inInputSource);
	return status == noErr;	
}

+ (BOOL)disableInputSource:(TISInputSourceRef)inInputSource
{
	OSStatus status = TISDisableInputSource(inInputSource);
	return status == noErr;	
}

+ (BOOL)registerInputSource:(NSURL *)inBundleURL
{
	OSStatus status = TISRegisterInputSource((CFURLRef)inBundleURL);
	return status == noErr;
}
@end
