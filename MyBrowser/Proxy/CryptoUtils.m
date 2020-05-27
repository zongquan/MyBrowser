#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#include "CryptoUtils.h"

NSString *base64Encode(NSString *inString) {
    NSData* data = [inString dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}

NSString *base64Decode(NSString *inString) {
    NSData* data = [[NSData alloc] initWithBase64EncodedString:inString options:0];
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}
    
NSString* encodeUrl(NSString *urlString) {
    NSString *outString = base64Encode(urlString);
    outString = [outString stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    outString = [outString stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
    outString = [outString stringByReplacingOccurrencesOfString:@"=" withString:@"."];
    return outString;
}
    
NSString* decodeUrl(NSString *urlString) {
    NSString *outString = [urlString stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    outString = [outString stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    outString = [outString stringByReplacingOccurrencesOfString:@"." withString:@"="];
    return base64Decode(outString);
}
    
NSString *hashUrl(NSString *urlString) {
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1([urlString UTF8String], (CC_LONG)[urlString length], digest);
    for (int i=0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        digest[i] = digest[i] ^ 11;
    }
    NSData *data = [NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH];
    return [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
}
        




