//
//  ProxyConfig.m
//  MyBrowser
//
//  Created by zongquan_ai on 2020/5/25.
//  Copyright © 2020 wodedata. All rights reserved.
//

@interface  ProxyConfig : NSObject

@property(nonatomic, copy) NSString* proxyURL;

- (BOOL)isProxyOpen;

@end

