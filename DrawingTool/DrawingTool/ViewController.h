//
//  ViewController.h
//  DrawingTool
//
//  Created by mini2014a on 2019/11/20.
//  Copyright © 2019 HK. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIImageView *canvasImgView;
@property (strong, nonatomic) IBOutlet UIImageView *thumbImgView;
@property (strong, nonatomic) IBOutlet UILabel *currentCharLabel;
@property (strong, nonatomic) IBOutlet UITableView *charListTableView;
@property (strong, nonatomic) IBOutlet UIView *btnView;
@property (strong, nonatomic) IBOutlet UIButton *saveBtn;
@property (strong, nonatomic) IBOutlet UIButton *undoBtn;

-(IBAction)onClickedSaveBtn:(id)sender;
-(IBAction)onClickedUndoBtn:(id)sender;
@end

