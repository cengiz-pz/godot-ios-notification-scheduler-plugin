//
// © 2024-present https://github.com/cengiz-pz
//

#import "nsp_converter.h"

@implementation NSPConverter


// FROM GODOT

+ (NSString*) toNsString:(String) godotString {
	return [NSString stringWithUTF8String:godotString.utf8().get_data()];
}


// TO GODOT

+ (Dictionary) nsDictionaryToGodotDictionary:(NSDictionary*) nsDictionary {
	Dictionary dictionary;

	for (NSString *key in [nsDictionary allKeys]) {
		NSString *value = [nsDictionary objectForKey:key];
		dictionary[key.UTF8String] = (value) ? [value UTF8String] : "";
	}

	return dictionary;
}

+ (Dictionary) nsUrlToGodotDictionary:(NSURL*) url {
	Dictionary dictionary;

	dictionary["scheme"] = [url.scheme UTF8String];
	dictionary["user"] = [url.user UTF8String];
	dictionary["password"] = [url.password UTF8String];
	dictionary["host"] = [url.host UTF8String];
	dictionary["port"] = [url.port intValue];
	dictionary["path"] = [url.path UTF8String];
	dictionary["pathExtension"] = [url.pathExtension UTF8String];
	dictionary["pathComponents"] = url.pathComponents;
	dictionary["parameterString"] = [url.parameterString UTF8String];
	dictionary["query"] = [url.query UTF8String];
	dictionary["fragment"] = [url.fragment UTF8String];

	return dictionary;
}

@end
