#import <Foundation/Foundation.h>
#import "ProxyConfig.h"

@implementation ProxyConfig

- (BOOL)isProxyOpen {
    if (_proxyURL.length == 0) {
        return false;
    }
    return true;
}

- (void)setProxyURL:(NSString *)proxyURL {
    NSURL *url = [NSURL URLWithString:proxyURL];
    if (url == nil) {
        return;
    }
    _proxyURL = [proxyURL copy];
}

@end
