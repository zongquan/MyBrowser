//
//  ProxyConfig.m
//  MyBrowser
//
//  Created by zongquan_ai on 2020/5/25.
//  Copyright © 2020 wodedata. All rights reserved.
//

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
