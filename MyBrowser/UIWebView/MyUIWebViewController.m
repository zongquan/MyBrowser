//
// Created by luowei on 15/7/5.
// Copyright (c) 2015 wodedata. All rights reserved.
//

#import "MyUIWebViewController.h"
#import "Defines.h"
#import "MyUIWebView.h"
#import "MyHelper.h"
#import "Favorite.h"
#import "ScanQRViewController.h"
#import "MyPopupView.h"
#import "ListUIWebViewController.h"
#import "FavoritesViewController.h"
#import "WebViewJavascriptBridge.h"
#import "UserSetting.h"


@interface MyUIWebViewController ()

@end

@implementation MyUIWebViewController {

}

- (void)loadView {
    [super loadView];

    //向webContainer中添加webview
    [self addWebView:HOME_URL];
    self.activeWindow.scrollView.delegate = self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    //从userDefault中加载收藏,给self.favoriteArray赋初值
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:MY_FAVORITES];
    self.favoriteArray = [NSMutableArray arrayWithArray:[NSKeyedUnarchiver unarchiveObjectWithData:data]];
    
//    __weak MyUIWebView *wb = _activeWindow;
//    _activeWindow.bridge = [WebViewJavascriptBridge bridgeForWebView:_activeWindow webViewDelegate:_activeWindow handler:^(id data, WVJBResponseCallback responseCallback) {
//        NSLog(@"=====received message from JS: %@", data);
//        responseCallback(@"this is message from objc!!");
//    }];
//    [_activeWindow.bridge callHandler:@"testJavascriptHandler" data:nil responseCallback:^(id response) {
//        NSLog(@"=====All Image Urls:%@", response);
//        NSError *error;
//        wb.allImgUrl = [NSJSONSerialization JSONObjectWithData:response options:0 error:&error];
//    }];
    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}


//添加一个WebView
- (MyUIWebView *)addWebView:(NSURL *)url {

    //添加webview
    self.activeWindow = [[MyUIWebView alloc] initWithFrame:self.webContainer.frame];
    _activeWindow.backgroundColor = [UIColor whiteColor];
    _activeWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.webContainer addSubview:_activeWindow];
    [self.webContainer bringSubviewToFront:_activeWindow];

    //加载页面
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [_activeWindow loadRequest:request];

    //更新刷新进度条的block
    __weak __typeof(self) weakSelf = self;
    _activeWindow.finishNavigationProgressBlock = ^() {
        [weakSelf.progressView setProgress:0.0 animated:NO];
        weakSelf.progressView.trackTintColor = [UIColor whiteColor];
    };
    _activeWindow.refreshToolbarBlock = ^() {
        [weakSelf refreshToolbar];
    };

    //添加新webView的block
    _activeWindow.addUIWebViewBlock = ^(MyUIWebView **wb, NSURL *aurl) {
        if (*wb) {
            *wb = [weakSelf addWebView:aurl];
        } else {
            [weakSelf addWebView:aurl];
        }
    };

    //presentViewController block
    _activeWindow.presentViewControllerBlock = ^(UIViewController *viewController) {
        [weakSelf presentViewController:viewController animated:YES completion:nil];
    };

    //关闭激活的webView的block
    _activeWindow.closeActiveWebViewBlock = ^() {
        [weakSelf closeActiveWebView];
    };

    // Add to windows array and make active window
    if (!self.listWebViewController) {
        self.listWebViewController = [[ListUIWebViewController alloc] initWithUIWebView:_activeWindow];

        //设置添加webView的block
        self.listWebViewController.addUIWebViewBlock = ^(MyUIWebView **wb, NSURL *aurl) {
            if (*wb) {
                *wb = [weakSelf addWebView:aurl];
            } else {
                [weakSelf addWebView:aurl];
            }
        };
        //更新活跃webView的block
        self.listWebViewController.updateUIActiveWindowBlock = ^(MyUIWebView *wb) {
            weakSelf.activeWindow = wb;
            [weakSelf.webContainer bringSubviewToFront:weakSelf.activeWindow];
        };

    } else {
        self.listWebViewController.updateUIDatasourceBlock(_activeWindow);
    }

    return _activeWindow;
}

//添加新webView窗口
- (void)presentAddWebViewVC {
    [self.navigationController pushViewController:self.listWebViewController animated:YES];
}

//更新工具栏
- (void)refreshToolbar {
    self.backBtn.enabled = [self.activeWindow canGoBack];
    self.forwardBtn.enabled = [self.activeWindow canGoForward];
}

//主页
- (void)home {
    [self.activeWindow loadRequest:[NSURLRequest requestWithURL:HOME_URL]];
}

//收藏
- (void)favorite {
    NSString *title = [_activeWindow stringByEvaluatingJavaScriptFromString:@"document.title"];
    NSString *currentURL = [_activeWindow stringByEvaluatingJavaScriptFromString:@"window.location.href"];
    Favorite *fav = [[Favorite alloc] initWithDictionary:@{@"title" : title, @"URL" : [[NSURL alloc] initWithString:currentURL]}];

    //判断是否需要添加收藏记录
    BOOL containFav = NO;
    for (Favorite *obj in self.favoriteArray) {
        if ([fav isEqualToFavorite:obj]) {
            containFav = YES;
        }
    }
    if (!containFav) {
        [self.favoriteArray addObject:fav];
    } else {
        [MyHelper showToastAlert:NSLocalizedString(@"Has Been Favorited", nil)];
        return;
    }

    //序列化存储
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.favoriteArray];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:MY_FAVORITES];

    [MyHelper showToastAlert:NSLocalizedString(@"Add Favorite Success", nil)];
}

//刷新
- (void)reload:(UIBarButtonItem *)item {
    NSString *currentURL = [_activeWindow stringByEvaluatingJavaScriptFromString:@"window.location.href"];
    [self.activeWindow loadRequest:[NSURLRequest requestWithURL:[[NSURL alloc] initWithString:currentURL]]];
}

//返回
- (void)back:(UIBarButtonItem *)item {
    [self.activeWindow goBack];
}

//前进
- (void)forward:(UIBarButtonItem *)item {
    [self.activeWindow goForward];
}


#pragma mark UISearchBarDelegate Implementation

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    NSString *currentURL = [_activeWindow stringByEvaluatingJavaScriptFromString:@"window.location.href"];
    searchBar.text = currentURL;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self.searchBar resignFirstResponder];
    NSString *text = self.searchBar.text;
    NSString *urlStr = [NSString stringWithFormat:@"http://www.baidu.com/s?wd=%@", text];

    if ([text isHttpURL]) {
        urlStr = [NSString stringWithFormat:@"%@", text];
    } else if ([text isDomain]) {
        urlStr = [NSString stringWithFormat:@"http://%@", text];
    }

    NSURL *url = [NSURL URLWithString:[urlStr stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [_activeWindow loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)searchBarBookmarkButtonClicked:(UISearchBar *)searchBar {
    ScanQRViewController *viewController = [ScanQRViewController new];
    viewController.title = NSLocalizedString(@"Scan RQ Code", nil);
    viewController.view.backgroundColor = [UIColor whiteColor];
    viewController.openURLBlock = ^(NSURL *url) {
        [_activeWindow loadRequest:[NSURLRequest requestWithURL:url]];
        self.searchBar.text = url.absoluteString;
    };

    [viewController setHidesBottomBarWhenPushed:YES];
    [self.navigationController pushViewController:viewController animated:YES];
}


#pragma mark MyPopupViewDelegate Implementation

//当设置菜单项被选中
- (void)popupViewItemTaped:(MyCollectionViewCell *)cell {

    //收藏历史管理
    if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Bookmarks", nil)]) {
        FavoritesViewController *favoritesViewController = [[FavoritesViewController alloc] init];
        favoritesViewController.getCurrentUIWebViewBlock = ^(MyUIWebView **wb) {
            *wb = _activeWindow;
        };
        favoritesViewController.loadRequestBlock = ^(NSURL *url) {
            [_activeWindow loadRequest:[NSURLRequest requestWithURL:url]];
            self.searchBar.text = [_activeWindow stringByEvaluatingJavaScriptFromString:@"window.location.href"];
        };
        [self.navigationController pushViewController:favoritesViewController animated:YES];

        //夜间模式
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Nighttime", nil)]) {
        self.maskView = [[UIView alloc] initWithFrame:self.view.bounds];
        self.maskView.backgroundColor = [UIColor blackColor];
        self.maskView.alpha = 0.2;
        [self.view addSubview:self.maskView];

        self.maskView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[maskView]|" options:0 metrics:nil views:@{@"maskView" : self.maskView}]];
        [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|[maskView]|" options:0 metrics:nil views:@{@"maskView" : self.maskView}]];

        //日间模式
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Daytime", nil)]) {
        [self.maskView removeFromSuperview];
        self.maskView = nil;

        //无图模式
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"No Image", nil)]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UIWEBVIEW_MODE];

        //todo:切换核心

        //清除痕迹
    } else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Clear All History", nil)]) {
        [self.webContainer.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isMemberOfClass:[MyUIWebView class]]) {
                //todo:
            }
        }];
        [MyHelper showToastAlert:NSLocalizedString(@"Successfully cleared Footprint", nil)];
    } else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"No Image",nil)]){
        
        //开启有图模式
        [UserSetting setImageBlockerStatus:@(NO)];
        
        
        //当前是有图模式
    } else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Image Mode",nil)]){
        
        //开启无图模式
        [UserSetting setImageBlockerStatus:@(YES)];
        
        
        //当前是拦截广告
    } else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"Ad Block",nil)]){
        
        //开启不拦截
        [UserSetting setAdblockerStatus:@(NO)];
        
        
        
        //当前是不拦截广告
    }else if([cell.titleLabel.text isEqualToString:NSLocalizedString(@"No AdBlock",nil)]){
        
        //开启拦截
        [UserSetting setAdblockerStatus:@(YES)];
        
    }
    
    else if ([cell.titleLabel.text isEqualToString:NSLocalizedString(@"About Me", nil)]) {
        //        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:UIWEBVIEW_MODE];
        //        [NSURLProtocol registerClass:[MyURLProtocol class]];
        //
        //        //todo:切换核心
        //
        //        [MyHelper showToastAlert:NSLocalizedString(@"Successfully Set NoImage Mode", nil)];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"About Me", nil)
                                                                                 message:NSLocalizedString(@"My Browser", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:okAction];
        
        [self presentViewController:alertController animated:YES completion:nil];
        
    }

    [self hiddenMenu];
}


//关闭当前webView
- (void)closeActiveWebView {
    // Grab and remove the top web view, remove its reference from the windows array,
    // and nil itself and its delegate. Then we re-set the activeWindow to the
    // now-top web view and refresh the toolbar.
    if (_activeWindow == self.listWebViewController.windows.lastObject) {
        [_activeWindow loadRequest:[NSURLRequest requestWithURL:HOME_URL]];
        return;
    }

    [_activeWindow removeFromSuperview];
    [self.listWebViewController.windows removeObject:_activeWindow];
    _activeWindow = self.listWebViewController.windows.lastObject;
    [self.webContainer bringSubviewToFront:_activeWindow];
}


@end
