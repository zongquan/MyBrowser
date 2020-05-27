#import <Foundation/Foundation.h>
#import "ProxyURLProtocol.h"
#import "CryptoUtils.h"
#import "CacheStoragePolicy.h"

static NSString * kOurRequestFlagProperty = @"com.ts.xx.CustomHTTPProtocol";
static NSOperationQueue *networkQueue = nil;

static NSString *proxyServer = @"10.10.36.235:8058";

@implementation ProxyURLProtocol {
    NSURLConnection *mConnection;
    NSMutableData *encryptBodys;
    bool isBodyEncrypt;
}

+ (void)initialize {
    [super initialize];
    if (networkQueue == nil) {
        networkQueue = [NSOperationQueue new];
        [networkQueue setMaxConcurrentOperationCount:10];
    }
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    NSString * scheme;
    
    //NSLog(@"request: %@", request.URL.absoluteString);
    
    if ([request.URL.absoluteString rangeOfString:proxyServer].length > 0)
        return NO;
    if (request == nil || request.URL == nil || [self propertyForKey:kOurRequestFlagProperty inRequest:request] != nil)
        return NO;
    scheme = [[request.URL scheme] lowercaseString];
    if ([scheme isEqualToString:@"http"] == false && [scheme isEqualToString:@"https"] == false)
        return NO;
    return YES;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

- (NSMutableURLRequest *)makeProxyRequest:(NSURLRequest*) request {
    if ([request.URL.absoluteString rangeOfString:proxyServer].length > 0) {
        return [request mutableCopy];
    }
    
    NSMutableURLRequest *   recursiveRequest;
    recursiveRequest = [request mutableCopy];
    if (recursiveRequest == nil) {
        return nil;
    }
    NSString *newURL = encodeUrl(recursiveRequest.URL.absoluteString);
    NSString *urlHash = hashUrl(newURL);
    
    newURL = [NSString stringWithFormat:@"https://%@/?org=%@", proxyServer,newURL];
    
    [recursiveRequest setURL:[NSURL URLWithString:newURL]];
    NSString *referer = [recursiveRequest.allHTTPHeaderFields valueForKey:@"Referer"];
    NSMutableDictionary *headers = [recursiveRequest.allHTTPHeaderFields mutableCopy];
    [headers setObject:urlHash forKey:@"Tsitoken"];
    if (referer.length > 0) {
        referer = encodeUrl(referer);
        [headers setValue:referer forKey:@"Referer"];
    }
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage] ;
    NSArray *cookiesArray = [cookieStorage cookiesForURL:request.URL];
    NSDictionary *cookieDict = [NSHTTPCookie requestHeaderFieldsWithCookies:cookiesArray];
    if (cookiesArray.count > 0) {
        [headers setValue:cookieDict[@"Cookie"] forKey:@"xxCookie"];
    }
    [recursiveRequest setAllHTTPHeaderFields:headers];
    return recursiveRequest;
}

- (NSDictionary*)dictionaryFromQuery:(NSString*)query
{
    NSCharacterSet* delimiterSet = [NSCharacterSet characterSetWithCharactersInString:@"&"];
    NSMutableDictionary* pairs = [NSMutableDictionary dictionary];
    NSScanner* scanner = [[NSScanner alloc] initWithString:query];
    while (![scanner isAtEnd]) {
        NSString* pairString = nil;
        [scanner scanUpToCharactersFromSet:delimiterSet intoString:&pairString];
        [scanner scanCharactersFromSet:delimiterSet intoString:NULL];
        NSArray* kvPair = [pairString componentsSeparatedByString:@"="];
        if (kvPair.count == 2) {
            NSString* key = [[kvPair objectAtIndex:0] stringByRemovingPercentEncoding];
            NSString* value = [[kvPair objectAtIndex:1] stringByRemovingPercentEncoding];
            [pairs setObject:value forKey:key];
        }
    }
    
    return [NSDictionary dictionaryWithDictionary:pairs];
}

- (NSHTTPURLResponse *)makeResponse:(NSHTTPURLResponse *)response {
    NSMutableDictionary *headers = [[response allHeaderFields] mutableCopy];
    NSURL *responseURL = response.URL;
    NSString *urlString = [response.URL absoluteString];
    if ([urlString rangeOfString:proxyServer].length > 0) {
        NSDictionary *query = [self dictionaryFromQuery:response.URL.query];
        NSString *url = query[@"org"];
        if (url && url.length > 0) {
            url = decodeUrl(url);
            responseURL = [NSURL URLWithString:url];
        }
    }
    
    NSArray *httpCokies = [NSHTTPCookie cookiesWithResponseHeaderFields:response.allHeaderFields forURL:responseURL];
    NSHTTPCookieStorage* cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSUInteger i = 0; i< httpCokies.count; i++)
        [cookieStorage setCookie:httpCokies[i]];
    
    
    NSHTTPURLResponse* httpResponse = [[NSHTTPURLResponse alloc] initWithURL:responseURL statusCode:response.statusCode HTTPVersion:@"1.1" headerFields:headers];
    return httpResponse;
}

- (void)startLoading {
    //NSLog(@"startLoading: %@", self.request.URL.absoluteString);
    NSMutableURLRequest *   recursiveRequest;
    recursiveRequest = [self makeProxyRequest:self.request];
    isBodyEncrypt = false;
    if (recursiveRequest == nil) {
        return;
    }
    
    [[self class] setProperty:@YES forKey:kOurRequestFlagProperty inRequest:recursiveRequest];
    [recursiveRequest setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
    mConnection = [[NSURLConnection alloc] initWithRequest:recursiveRequest delegate:self startImmediately:NO];
    [mConnection setDelegateQueue:networkQueue];
    [mConnection start];
}

- (void)stopLoading {
    [mConnection cancel];
}

- (nullable NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)newRequest redirectResponse:(nullable NSURLResponse *)response {
    if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        NSInteger status = httpResponse.statusCode;
        if (status >= 300 && status < 400) {
            NSMutableURLRequest* redirectRequest = [newRequest mutableCopy];
            httpResponse = [self makeResponse:httpResponse];
            [[self class] removePropertyForKey:kOurRequestFlagProperty inRequest:redirectRequest];
            [self.client URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:httpResponse];
            [self.client URLProtocolDidFinishLoading:self];
            [self stopLoading];
            return nil;
        }
    }
    return newRequest;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
    response = [self makeResponse:httpResponse];
    if ([httpResponse.allHeaderFields objectForKey:@"Tsconfused"]) {
        encryptBodys = [NSMutableData new];
        isBodyEncrypt = true;
    }
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:CacheStoragePolicyForRequestAndResponse(self.request, httpResponse)];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (isBodyEncrypt) {
        [encryptBodys appendData:data];
    } else
        [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (isBodyEncrypt) {
        NSData *data = [[NSData alloc] initWithBase64EncodedData:encryptBodys options:0];
        [self.client URLProtocol:self didLoadData:data];
    }
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    
    id selfCertificate = nil;
    SecTrustResultType result;
    
    SecTrustRef trust = challenge.protectionSpace.serverTrust;
    OSStatus status = SecTrustEvaluate(trust, &result);
    if (selfCertificate == nil || (status == errSecSuccess && (result == kSecTrustResultProceed || result == kSecTrustResultUnspecified))) { //success
        NSURLCredential *cred = [NSURLCredential credentialForTrust:trust];
        [challenge.sender useCredential:cred forAuthenticationChallenge:challenge];
    } else {
        [challenge.sender cancelAuthenticationChallenge:challenge];
    }
}

@end
