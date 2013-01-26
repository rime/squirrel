//
// OVInputSourceHelper.h
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

#import <InputMethodKit/InputMethodKit.h>

@interface OVInputSourceHelper : NSObject
// list all installed input sources
+ (NSArray *)allInstalledInputSources;

// search for a certain input source
+ (TISInputSourceRef)inputSourceForProperty:(CFStringRef)inPropertyKey stringValue:(NSString *)inValue;

// shorthand for -inputSourceForProerty:kTISPropertyInputSourceID stringValue:<value>
+ (TISInputSourceRef)inputSourceForInputSourceID:(NSString *)inID;

// enable/disable an input source (along with all its input modes)
+ (BOOL)inputSourceEnabled:(TISInputSourceRef)inInputSource;
+ (BOOL)enableInputSource:(TISInputSourceRef)inInputSource;
+ (BOOL)disableInputSource:(TISInputSourceRef)inInputSource;

// register (i.e. make available to Input Source tab in Language & Text Preferences)
// an input source installed in (~)/Library/Input Methods or (~)/Library/Keyboard Layouts/
+ (BOOL)registerInputSource:(NSURL *)inBundleURL;
@end
