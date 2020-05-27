//
// Created by luowei on 15/7/5.
// Copyright (c) 2015 wodedata. All rights reserved.
//

#import <UIKit/UIKit.h>

@class WebViewJavascriptBridge;


@interface MyUIWebView : UIWebView<UIWebViewDelegate>
@property(nonatomic, copy) void (^finishNavigationProgressBlock)();
@property(nonatomic, copy) void (^addUIWebViewBlock)(MyUIWebView **, NSURL *);
@property(nonatomic, copy) void (^presentViewControllerBlock)(UIViewController *);
@property(nonatomic, copy) void (^closeActiveWebViewBlock)();
@property(nonatomic, copy) void (^refreshToolbarBlock)();
@property(nonatomic, strong) WebViewJavascriptBridge *bridge;
@property(nonatomic, strong) NSArray *allImgUrl;
@end
