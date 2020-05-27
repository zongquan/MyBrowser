@interface  ProxyConfig : NSObject

@property(nonatomic, copy) NSString* proxyURL;

- (BOOL)isProxyOpen;

@end

